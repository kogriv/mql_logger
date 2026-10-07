//+------------------------------------------------------------------+
//|                                                SqliteHandler.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "..\Core\Interfaces.mqh"

//+------------------------------------------------------------------+
//| SQLite handler - stores logs in SQLite database                |
//|                                                                  |
//| Два режима записи:                                               |
//|  - по записи (auto_commit = true, по умолчанию): каждая запись  |
//|    сразу в файле базы. Переживает критическую ошибку программы   |
//|    (array out of range и т. п.) и снятие терминала;             |
//|  - пакетами (auto_commit = false): коммит раз в batch_size       |
//|    записей, в Flush() и при закрытии. Быстрее, но при            |
//|    критической ошибке программы незакоммиченный хвост пропадает: |
//|    деструкторы в этом случае не вызываются.                      |
//| Сброс на диск: по умолчанию synchronous = NORMAL (запись может  |
//| пропасть только при отключении питания); SetDurable(true) —      |
//| FULL, каждая запись ждёт диск (в десятки раз медленнее).         |
//+------------------------------------------------------------------+
class CSqliteHandler : public ILogHandler
{
private:
   ILogFormatter*    m_formatter;         // Message formatter (optional for DB)
   ILogFilter*       m_filter;            // Message filter
   ENUM_LOG_LEVEL    m_level;             // Minimum level
   bool              m_enabled;           // Is handler enabled
   
   string            m_database_path;     // Database file path
   int               m_database_handle;   // Database handle
   string            m_table_name;        // Log table name
   bool              m_auto_commit;       // Auto commit transactions
   int               m_batch_size;        // Batch size for commits
   int               m_pending_records;   // Records pending commit
   bool              m_in_transaction;    // Explicit transaction is open
   bool              m_create_indexes;    // Create performance indexes
   bool              m_durable;           // synchronous = FULL instead of NORMAL
   int               m_failed;            // Records that were not stored
   
   bool              OpenDatabase();
   void              CloseDatabase();
   bool              CreateTable();
   bool              InsertRecord(const SLogRecord &record);
   void              CommitBatch();
   bool              BeginTransaction();
   bool              CommitTransaction();
   bool              AddMissingColumns();
   string            EscapeSqlString(string text);
   void              ApplySynchronous();

public:
                     CSqliteHandler(string database_path, string table_name = "logs", 
                                   bool auto_commit = true, int batch_size = 100);
                    ~CSqliteHandler();
   
   // ILogHandler implementation
   virtual bool      Handle(const SLogRecord &record) override;
   virtual void      SetFormatter(ILogFormatter* formatter) override;
   virtual void      SetFilter(ILogFilter* filter) override;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override;
   virtual void      Flush() override;
   virtual void      Close() override;
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) override;
   
   // SQLite-specific methods
   void              SetAutoCommit(bool auto_commit);
   bool              GetAutoCommit() const { return m_auto_commit; }
   void              SetBatchSize(int batch_size) { m_batch_size = batch_size; }
   int               GetBatchSize() const { return m_batch_size; }
   void              SetCreateIndexes(bool create_indexes);
   bool              GetCreateIndexes() const { return m_create_indexes; }
   string            GetDatabasePath() const { return m_database_path; }
   string            GetTableName() const { return m_table_name; }
   void              Enable(bool enabled) { m_enabled = enabled; }
   void              SetDurable(bool durable);
   bool              GetDurable() const { return m_durable; }
   bool              IsOpen() const { return m_database_handle != INVALID_HANDLE; }
   int               FailedCount() const { return m_failed; }
   
   // Utility methods
   bool              CreateIndexes();
   bool              ExecuteQuery(string query);
   int               GetRecordCount();
   bool              ClearOldRecords(int days_to_keep);
   bool              Clear();                             // delete every record of the table
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSqliteHandler::CSqliteHandler(string database_path, string table_name = "logs", 
                              bool auto_commit = true, int batch_size = 100) :
   m_formatter(NULL),
   m_filter(NULL),
   m_level(LOG_TRACE),
   m_enabled(true),
   m_database_path(database_path),
   m_database_handle(INVALID_HANDLE),
   m_table_name(table_name),
   m_auto_commit(auto_commit),
   m_batch_size(batch_size),
   m_pending_records(0),
   m_in_transaction(false),
   m_create_indexes(false),
   m_durable(false),
   m_failed(0)
{
   OpenDatabase();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSqliteHandler::~CSqliteHandler()
{
   Close();
}

//+------------------------------------------------------------------+
//| Open SQLite database                                            |
//+------------------------------------------------------------------+
bool CSqliteHandler::OpenDatabase()
{
   if(m_database_handle != INVALID_HANDLE)
      CloseDatabase();
   
   m_database_handle = DatabaseOpen(m_database_path, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
   
   if(m_database_handle == INVALID_HANDLE)
   {
      PrintFormat("Failed to open SQLite database: %s, Error: %d", m_database_path, GetLastError());
      return false;
   }
   
   // Must be set before the first transaction
   ApplySynchronous();
   
   // Create table and indexes
   if(!CreateTable() || !AddMissingColumns())
   {
      CloseDatabase();
      return false;
   }
   
   // Begin transaction if not auto-committing
   if(!m_auto_commit)
      BeginTransaction();
   
   return true;
}

//+------------------------------------------------------------------+
//| Close SQLite database                                           |
//+------------------------------------------------------------------+
void CSqliteHandler::CloseDatabase()
{
   if(m_database_handle != INVALID_HANDLE)
   {
      CommitTransaction();
      m_pending_records = 0;
      
      DatabaseClose(m_database_handle);
      m_database_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Open an explicit transaction (batch mode)                       |
//+------------------------------------------------------------------+
bool CSqliteHandler::BeginTransaction()
{
   if(m_database_handle == INVALID_HANDLE || m_in_transaction)
      return m_in_transaction;
   
   m_in_transaction = ExecuteQuery("BEGIN TRANSACTION");
   return m_in_transaction;
}

//+------------------------------------------------------------------+
//| Commit the open transaction, if any                             |
//+------------------------------------------------------------------+
bool CSqliteHandler::CommitTransaction()
{
   if(m_database_handle == INVALID_HANDLE || !m_in_transaction)
      return true;
   
   m_in_transaction = false;
   if(!ExecuteQuery("COMMIT"))
   {
      PrintFormat("Failed to commit %d log records to %s", m_pending_records, m_database_path);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Switch between commit-per-record and batch mode                 |
//+------------------------------------------------------------------+
void CSqliteHandler::SetAutoCommit(bool auto_commit)
{
   if(m_auto_commit == auto_commit)
      return;
   
   m_auto_commit = auto_commit;
   if(m_database_handle == INVALID_HANDLE)
      return;
   
   if(m_auto_commit)
   {
      CommitTransaction();
      m_pending_records = 0;
   }
   else
      BeginTransaction();
}

//+------------------------------------------------------------------+
//| Create log table                                                |
//+------------------------------------------------------------------+
bool CSqliteHandler::CreateTable()
{
   string create_sql = StringFormat(
      "CREATE TABLE IF NOT EXISTS %s ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "ticktime DATETIME NOT NULL, "
      "level INTEGER NOT NULL, "
      "logger_name TEXT NOT NULL, "
      "message TEXT NOT NULL, "
      "source_file TEXT, "
      "source_line INTEGER, "
      "function_name TEXT, "
      "thread_id INTEGER, "
      "error_code INTEGER, "
      "timestamp INTEGER NOT NULL, "
      "created_at DATETIME DEFAULT CURRENT_TIMESTAMP, "
      "time_local INTEGER, "
      "elapsed_us INTEGER, "
      "seq INTEGER"
      ")", m_table_name);
   
   return ExecuteQuery(create_sql);
}

//+------------------------------------------------------------------+
//| Table of an older version: add the columns it lacks             |
//|   time_local - computer time, seconds                           |
//|   elapsed_us - microseconds since the program started           |
//|   seq        - record number within the program                 |
//+------------------------------------------------------------------+
bool CSqliteHandler::AddMissingColumns()
{
   string wanted[] = {"time_local", "elapsed_us", "seq"};
   bool present[3] = {false, false, false};
   
   int request = DatabasePrepare(m_database_handle, StringFormat("PRAGMA table_info(%s)", m_table_name));
   if(request == INVALID_HANDLE)
      return false;
   while(DatabaseRead(request))
   {
      string column;
      if(!DatabaseColumnText(request, 1, column))
         continue;
      for(int i = 0; i < 3; i++)
         if(column == wanted[i])
            present[i] = true;
   }
   DatabaseFinalize(request);
   
   for(int i = 0; i < 3; i++)
   {
      if(!present[i] &&
         !ExecuteQuery(StringFormat("ALTER TABLE %s ADD COLUMN %s INTEGER", m_table_name, wanted[i])))
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Disk sync mode; cannot be changed inside a transaction          |
//+------------------------------------------------------------------+
void CSqliteHandler::ApplySynchronous()
{
   if(m_database_handle == INVALID_HANDLE)
      return;
   
   bool reopen = m_in_transaction;
   if(reopen)
      CommitTransaction();
   ExecuteQuery(m_durable ? "PRAGMA synchronous = FULL" : "PRAGMA synchronous = NORMAL");
   if(reopen)
      BeginTransaction();
}

//+------------------------------------------------------------------+
//| true - every commit waits for the disk                          |
//+------------------------------------------------------------------+
void CSqliteHandler::SetDurable(bool durable)
{
   if(m_durable == durable)
      return;
   m_durable = durable;
   ApplySynchronous();
}

//+------------------------------------------------------------------+
//| Индексы ускоряют выборки и вдвое замедляют запись, поэтому по   |
//| умолчанию не создаются: вызовите SetCreateIndexes(true) или      |
//| CreateIndexes() перед разбором журнала. Созданные остаются.      |
//+------------------------------------------------------------------+
void CSqliteHandler::SetCreateIndexes(bool create_indexes)
{
   m_create_indexes = create_indexes;
   if(m_create_indexes && m_database_handle != INVALID_HANDLE)
      CreateIndexes();
}

//+------------------------------------------------------------------+
//| Create performance indexes                                       |
//+------------------------------------------------------------------+
bool CSqliteHandler::CreateIndexes()
{
   if(m_database_handle == INVALID_HANDLE)
      return false;
   
   // Not inside the logging transaction
   bool reopen = m_in_transaction;
   if(reopen)
      CommitTransaction();
   
   string columns[4] = {"timestamp", "level", "logger_name", "created_at"};
   string names[4] = {"timestamp", "level", "logger", "created"};
   bool ok = true;
   for(int i = 0; i < 4 && ok; i++)
      ok = ExecuteQuery(StringFormat("CREATE INDEX IF NOT EXISTS idx_%s_%s ON %s(%s)",
                                     m_table_name, names[i], m_table_name, columns[i]));
   
   if(reopen)
      BeginTransaction();
   return ok;
}

//+------------------------------------------------------------------+
//| Execute SQL query                                               |
//+------------------------------------------------------------------+
bool CSqliteHandler::ExecuteQuery(string query)
{
   if(m_database_handle == INVALID_HANDLE)
      return false;
   
   if(!DatabaseExecute(m_database_handle, query))
   {
      PrintFormat("SQL query failed: %s, Error: %d", query, GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Insert log record into database                                 |
//+------------------------------------------------------------------+
bool CSqliteHandler::InsertRecord(const SLogRecord &record)
{
   // Текстом, а не подготовленным запросом: DatabaseRead() после INSERT оставляет в _LastError код 5126
   // («данных больше нет») и стирал бы код ошибки вызывающего. Выигрыш подготовленного запроса — 20 мкс.
   string insert_sql = StringFormat(
      "INSERT INTO %s (ticktime, level, logger_name, message, source_file, source_line, function_name, "
      "thread_id, error_code, timestamp, time_local, elapsed_us, seq) "
      "VALUES ('%s', %d, '%s', '%s', '%s', %d, '%s', %d, %d, %I64d, %I64d, %I64u, %I64u)",
      m_table_name,
      TimeToString(record.timestamp, TIME_DATE|TIME_SECONDS),
      (int)record.level,
      EscapeSqlString(record.logger_name),
      EscapeSqlString(record.message),
      EscapeSqlString(record.source_file),
      record.source_line,
      EscapeSqlString(record.function_name),
      record.thread_id,
      record.error_code,
      (long)record.timestamp,
      (long)record.time_local,
      record.elapsed_us,
      record.sequence
   );
   
   if(m_database_handle == INVALID_HANDLE || !DatabaseExecute(m_database_handle, insert_sql))
   {
      m_failed++;
      if(m_failed == 1)
         PrintFormat("Logger: cannot write to %s, error %d; further failures are only counted (FailedCount)",
                     m_database_path, GetLastError());
      return false;
   }
   
   m_pending_records++;
   
   // Batch mode: commit every m_batch_size records
   if(m_auto_commit)
      m_pending_records = 0;
   else if(m_pending_records >= m_batch_size)
      CommitBatch();
   
   return true;
}

//+------------------------------------------------------------------+
//| Escape a string for an SQL literal                              |
//+------------------------------------------------------------------+
string CSqliteHandler::EscapeSqlString(string text)
{
   StringReplace(text, "'", "''");
   return text;
}

//+------------------------------------------------------------------+
//| Commit pending records                                         |
//+------------------------------------------------------------------+
void CSqliteHandler::CommitBatch()
{
   if(m_database_handle == INVALID_HANDLE)
      return;
   
   if(!m_auto_commit)
   {
      CommitTransaction();
      BeginTransaction();
   }
   m_pending_records = 0;
}

//+------------------------------------------------------------------+
//| Handle log record                                               |
//+------------------------------------------------------------------+
bool CSqliteHandler::Handle(const SLogRecord &record)
{
   if(!m_enabled || !IsEnabled(record.level))
      return false;
   
   // Apply filter if present
   if(m_filter != NULL && !m_filter.ShouldLog(record))
      return false;
   
   return InsertRecord(record);
}

//+------------------------------------------------------------------+
//| Set formatter (optional for database storage)                  |
//+------------------------------------------------------------------+
void CSqliteHandler::SetFormatter(ILogFormatter* formatter)
{
   m_formatter = formatter;
}

//+------------------------------------------------------------------+
//| Set filter                                                       |
//+------------------------------------------------------------------+
void CSqliteHandler::SetFilter(ILogFilter* filter)
{
   m_filter = filter;
}

//+------------------------------------------------------------------+
//| Set minimum logging level                                       |
//+------------------------------------------------------------------+
void CSqliteHandler::SetLevel(ENUM_LOG_LEVEL level)
{
   m_level = level;
}

//+------------------------------------------------------------------+
//| Check if level is enabled                                       |
//+------------------------------------------------------------------+
bool CSqliteHandler::IsEnabled(ENUM_LOG_LEVEL level)
{
   return m_enabled && level >= m_level;
}

//+------------------------------------------------------------------+
//| Flush handler                                                    |
//+------------------------------------------------------------------+
void CSqliteHandler::Close()
{
   CloseDatabase();
   m_enabled = false;
   m_formatter = NULL;
   m_filter = NULL;
}

//+------------------------------------------------------------------+
//| Flush handler                                                    |
//+------------------------------------------------------------------+
void CSqliteHandler::Flush()
{
   CommitBatch();
}

//+------------------------------------------------------------------+
//| Get total record count                                          |
//+------------------------------------------------------------------+
int CSqliteHandler::GetRecordCount()
{
   if(m_database_handle == INVALID_HANDLE)
      return -1;
   
   string query = StringFormat("SELECT COUNT(*) FROM %s", m_table_name);
   int request = DatabasePrepare(m_database_handle, query);
   
   if(request == INVALID_HANDLE)
      return -1;
   
   int count = -1;
   if(DatabaseRead(request))
   {
      if(!DatabaseColumnInteger(request, 0, count))
         count = -1;
   }
   
   DatabaseFinalize(request);
   return count;
}

//+------------------------------------------------------------------+
//| Clear old records older than specified days                    |
//+------------------------------------------------------------------+
bool CSqliteHandler::ClearOldRecords(int days_to_keep)
{
   if(m_database_handle == INVALID_HANDLE || days_to_keep <= 0)
      return false;
   
   datetime cutoff_time = TimeCurrent() - (days_to_keep * 24 * 3600);
   
   string delete_sql = StringFormat("DELETE FROM %s WHERE timestamp < %I64d", 
                                   m_table_name, (long)cutoff_time);
   
   return ExecuteQuery(delete_sql);
}

//+------------------------------------------------------------------+
//| Delete every record (the file keeps its size and is reused)     |
//+------------------------------------------------------------------+
bool CSqliteHandler::Clear()
{
   if(m_database_handle == INVALID_HANDLE)
      return false;
   
   bool reopen = m_in_transaction;
   if(reopen)
      CommitTransaction();
   m_pending_records = 0;
   bool ok = ExecuteQuery(StringFormat("DELETE FROM %s", m_table_name));
   if(reopen)
      BeginTransaction();
   return ok;
}
