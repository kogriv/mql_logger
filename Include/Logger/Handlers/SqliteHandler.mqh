//+------------------------------------------------------------------+
//|                                                SqliteHandler.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

#include "../Core/Interfaces.mqh"

//+------------------------------------------------------------------+
//| SQLite handler - stores logs in SQLite database                |
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
   bool              m_create_indexes;    // Create performance indexes
   
   bool              OpenDatabase();
   void              CloseDatabase();
   bool              CreateTable();
   bool              CreateIndexes();
   bool              InsertRecord(const SLogRecord &record);
   void              CommitBatch();
   string            EscapeSqlString(string input);

public:
                     CSqliteHandler(string database_path, string table_name = "logs", 
                                   bool auto_commit = false, int batch_size = 100);
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
   void              SetAutoCommit(bool auto_commit) { m_auto_commit = auto_commit; }
   bool              GetAutoCommit() const { return m_auto_commit; }
   void              SetBatchSize(int batch_size) { m_batch_size = batch_size; }
   int               GetBatchSize() const { return m_batch_size; }
   void              SetCreateIndexes(bool create_indexes) { m_create_indexes = create_indexes; }
   bool              GetCreateIndexes() const { return m_create_indexes; }
   string            GetDatabasePath() const { return m_database_path; }
   string            GetTableName() const { return m_table_name; }
   void              Enable(bool enabled) { m_enabled = enabled; }
   
   // Utility methods
   bool              ExecuteQuery(string query);
   int               GetRecordCount();
   bool              ClearOldRecords(int days_to_keep);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSqliteHandler::CSqliteHandler(string database_path, string table_name = "logs", 
                              bool auto_commit = false, int batch_size = 100) :
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
   m_create_indexes(true)
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
   
   // Create table and indexes
   if(!CreateTable())
   {
      CloseDatabase();
      return false;
   }
   
   if(m_create_indexes && !CreateIndexes())
   {
      PrintFormat("Warning: Failed to create indexes for table %s", m_table_name);
   }
   
   // Begin transaction if not auto-committing
   if(!m_auto_commit)
   {
      ExecuteQuery("BEGIN TRANSACTION");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Close SQLite database                                           |
//+------------------------------------------------------------------+
void CSqliteHandler::CloseDatabase()
{
   if(m_database_handle != INVALID_HANDLE)
   {
      // Commit any pending records
      if(m_pending_records > 0)
      {
         CommitBatch();
      }
      
      DatabaseClose(m_database_handle);
      m_database_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Create log table                                                |
//+------------------------------------------------------------------+
bool CSqliteHandler::CreateTable()
{
   string create_sql = StringFormat(
      "CREATE TABLE IF NOT EXISTS %s ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "timestamp INTEGER NOT NULL, "
      "level INTEGER NOT NULL, "
      "logger_name TEXT NOT NULL, "
      "message TEXT NOT NULL, "
      "source_file TEXT, "
      "source_line INTEGER, "
      "function_name TEXT, "
      "thread_id INTEGER, "
      "error_code INTEGER, "
      "created_at DATETIME DEFAULT CURRENT_TIMESTAMP"
      ")", m_table_name);
   
   return ExecuteQuery(create_sql);
}

//+------------------------------------------------------------------+
//| Create performance indexes                                       |
//+------------------------------------------------------------------+
bool CSqliteHandler::CreateIndexes()
{
   string index_queries[] = {
      StringFormat("CREATE INDEX IF NOT EXISTS idx_%s_timestamp ON %s(timestamp)", m_table_name, m_table_name),
      StringFormat("CREATE INDEX IF NOT EXISTS idx_%s_level ON %s(level)", m_table_name, m_table_name),
      StringFormat("CREATE INDEX IF NOT EXISTS idx_%s_logger ON %s(logger_name)", m_table_name, m_table_name),
      StringFormat("CREATE INDEX IF NOT EXISTS idx_%s_created ON %s(created_at)", m_table_name, m_table_name)
   };
   
   for(int i = 0; i < ArraySize(index_queries); i++)
   {
      if(!ExecuteQuery(index_queries[i]))
      {
         PrintFormat("Failed to create index: %s", index_queries[i]);
         return false;
      }
   }
   
   return true;
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
   string insert_sql = StringFormat(
      "INSERT INTO %s (timestamp, level, logger_name, message, source_file, source_line, function_name, thread_id, error_code) "
      "VALUES (%d, %d, '%s', '%s', '%s', %d, '%s', %d, %d)",
      m_table_name,
      (int)record.timestamp,
      (int)record.level,
      EscapeSqlString(record.logger_name),
      EscapeSqlString(record.message),
      EscapeSqlString(record.source_file),
      record.source_line,
      EscapeSqlString(record.function_name),
      record.thread_id,
      record.error_code
   );
   
   if(!ExecuteQuery(insert_sql))
      return false;
   
   m_pending_records++;
   
   // Auto-commit or batch commit
   if(m_auto_commit)
   {
      CommitBatch();
   }
   else if(m_pending_records >= m_batch_size)
   {
      CommitBatch();
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Commit pending records                                          |
//+------------------------------------------------------------------+
void CSqliteHandler::CommitBatch()
{
   if(m_pending_records > 0)
   {
      if(!m_auto_commit)
      {
         ExecuteQuery("COMMIT");
         ExecuteQuery("BEGIN TRANSACTION");
      }
      m_pending_records = 0;
   }
}

//+------------------------------------------------------------------+
//| Escape SQL string to prevent injection                         |
//+------------------------------------------------------------------+
string CSqliteHandler::EscapeSqlString(string input)
{
   string output = input;
   StringReplace(output, "'", "''");  // Escape single quotes
   return output;
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
void CSqliteHandler::Flush()
{
   CommitBatch();
}

//+------------------------------------------------------------------+
//| Close handler                                                    |
//+------------------------------------------------------------------+
void CSqliteHandler::Close()
{
   CloseDatabase();
   m_enabled = false;
   m_formatter = NULL;
   m_filter = NULL;
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
      count = DatabaseColumnInteger(request, 0);
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
   
   string delete_sql = StringFormat("DELETE FROM %s WHERE timestamp < %d", 
                                   m_table_name, (int)cutoff_time);
   
   return ExecuteQuery(delete_sql);
}
