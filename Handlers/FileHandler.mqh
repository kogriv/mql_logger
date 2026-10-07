//+------------------------------------------------------------------+
//|                                                 FileHandler.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "..\Core\Interfaces.mqh"

//+------------------------------------------------------------------+
//| File handler - writes logs to a text file in MQL5\Files         |
//|                                                                  |
//| Кодировка — UTF-8 без BOM (unicode = true — UTF-16 с BOM).       |
//| Файл открыт с общим доступом на чтение: журнал можно читать,    |
//| пока программа работает.                                         |
//| Ротация: при достижении предела размера файл переименовывается  |
//| в <имя>.<N><расширение>, N растёт (больше — новее).             |
//+------------------------------------------------------------------+
class CFileHandler : public ILogHandler
{
private:
   ILogFormatter*    m_formatter;         // Message formatter
   ILogFilter*       m_filter;            // Message filter
   ENUM_LOG_LEVEL    m_level;             // Minimum level
   bool              m_enabled;           // Is handler enabled

   string            m_filename;          // Log file name
   int               m_file_handle;       // File handle
   bool              m_append_mode;       // Append to existing file
   bool              m_auto_flush;        // Write and flush every record
   bool              m_common;            // Common folder of all terminals
   bool              m_unicode;           // UTF-16 instead of UTF-8
   bool              m_opened_once;       // File has been opened by this handler

   int               m_max_file_size;     // Max file size in bytes (0 = unlimited)
   int               m_max_archives;      // Rotated files to keep (0 = all)
   int               m_archive_index;     // Number of the last rotated file

   int               m_buffer_size;       // Buffer size that triggers a write (chars)
   int               m_buffer_limit;      // Buffer size at which unwritten records are dropped
   string            m_buffer;            // Write buffer
   int               m_buffer_records;    // Records in the buffer
   ulong             m_last_flush_ms;     // Last flush, GetTickCount64
   int               m_flush_interval;    // Flush interval in seconds

   ulong             m_retry_after_ms;    // No reopen attempts before this moment
   int               m_retry_interval_ms; // Pause between reopen attempts
   bool              m_error_reported;    // Failure already printed to the journal
   int               m_dropped;           // Records that were not saved

   bool              OpenFile();
   bool              EnsureOpen();
   void              CloseFile();
   bool              WriteToFile(string message);
   bool              FlushBuffer();
   bool              RotateIfNeeded();
   string            ArchiveName(int index);
   void              ReportError(string action);
   int               CommonFlag() const { return m_common ? FILE_COMMON : 0; }

public:
                     CFileHandler(string filename, bool append = true, bool auto_flush = false,
                                  bool common = false, bool unicode = false);
                    ~CFileHandler();

   // ILogHandler implementation
   virtual bool      Handle(const SLogRecord &record) override;
   virtual void      SetFormatter(ILogFormatter* formatter) override;
   virtual void      SetFilter(ILogFilter* filter) override;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override;
   virtual void      Flush() override;
   virtual void      Close() override;
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) override;

   // File-specific methods
   void              SetAppendMode(bool append) { m_append_mode = append; }
   bool              GetAppendMode() const { return m_append_mode; }
   void              SetAutoFlush(bool auto_flush) { m_auto_flush = auto_flush; }
   bool              GetAutoFlush() const { return m_auto_flush; }
   void              SetMaxFileSize(int max_size) { m_max_file_size = max_size; }
   int               GetMaxFileSize() const { return m_max_file_size; }
   void              SetMaxArchives(int count) { m_max_archives = count; }
   int               GetMaxArchives() const { return m_max_archives; }
   void              SetFlushInterval(int seconds) { m_flush_interval = seconds; }
   int               GetFlushInterval() const { return m_flush_interval; }
   string            GetFilename() const { return m_filename; }
   bool              IsCommon() const { return m_common; }
   bool              IsUnicode() const { return m_unicode; }
   bool              IsOpen() const { return m_file_handle != INVALID_HANDLE; }
   int               DroppedCount() const { return m_dropped; }
   void              Enable(bool enabled) { m_enabled = enabled; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFileHandler::CFileHandler(string filename, bool append = true, bool auto_flush = false,
                           bool common = false, bool unicode = false) :
   m_formatter(NULL),
   m_filter(NULL),
   m_level(LOG_TRACE),
   m_enabled(true),
   m_filename(filename),
   m_file_handle(INVALID_HANDLE),
   m_append_mode(append),
   m_auto_flush(auto_flush),
   m_common(common),
   m_unicode(unicode),
   m_opened_once(false),
   m_max_file_size(0),
   m_max_archives(0),
   m_archive_index(0),
   m_buffer_size(8192),
   m_buffer_limit(1048576),
   m_buffer(""),
   m_buffer_records(0),
   m_last_flush_ms(GetTickCount64()),
   m_flush_interval(60),
   m_retry_after_ms(0),
   m_retry_interval_ms(5000),
   m_error_reported(false),
   m_dropped(0)
{
   OpenFile();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFileHandler::~CFileHandler()
{
   Close();
}

//+------------------------------------------------------------------+
//| One line in the terminal journal per failure streak             |
//+------------------------------------------------------------------+
void CFileHandler::ReportError(string action)
{
   int error = GetLastError();
   if(m_error_reported)
      return;
   m_error_reported = true;
   PrintFormat("Logger: cannot %s log file %s, error %d; records are dropped until it works again",
               action, m_filename, error);
}

//+------------------------------------------------------------------+
//| Open log file                                                   |
//+------------------------------------------------------------------+
bool CFileHandler::OpenFile()
{
   if(m_file_handle != INVALID_HANDLE)
      CloseFile();

   // FILE_WRITE без FILE_READ обнуляет существующий файл: так начинается режим перезаписи.
   // Дозапись и повторное открытие своего файла — с FILE_READ, содержимое сохраняется.
   bool keep_content = m_append_mode || m_opened_once;
   int flags = FILE_WRITE | FILE_SHARE_READ | FILE_TXT | CommonFlag();
   if(keep_content)
      flags |= FILE_READ;

   if(m_unicode)
      m_file_handle = FileOpen(m_filename, flags | FILE_UNICODE);
   else
      m_file_handle = FileOpen(m_filename, flags | FILE_ANSI, '\t', CP_UTF8);

   if(m_file_handle == INVALID_HANDLE)
   {
      ReportError("open");
      m_retry_after_ms = GetTickCount64() + (ulong)m_retry_interval_ms;
      return false;
   }

   m_opened_once = true;
   m_error_reported = false;
   if(keep_content)
      FileSeek(m_file_handle, 0, SEEK_END);

   return true;
}

//+------------------------------------------------------------------+
//| Open the file if it is closed; retries are rate limited         |
//+------------------------------------------------------------------+
bool CFileHandler::EnsureOpen()
{
   if(m_file_handle != INVALID_HANDLE)
      return true;
   if(GetTickCount64() < m_retry_after_ms)
      return false;
   return OpenFile();
}

//+------------------------------------------------------------------+
//| Close log file                                                  |
//+------------------------------------------------------------------+
void CFileHandler::CloseFile()
{
   if(m_file_handle != INVALID_HANDLE)
   {
      FlushBuffer();
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Write message to file                                           |
//+------------------------------------------------------------------+
bool CFileHandler::WriteToFile(string message)
{
   if(!EnsureOpen())
   {
      m_dropped++;
      return false;
   }

   if(m_max_file_size > 0 && !RotateIfNeeded())
   {
      m_dropped++;
      return false;
   }

   if(m_auto_flush)
   {
      // Direct write
      if(FileWrite(m_file_handle, message) == 0)
      {
         ReportError("write to");
         m_dropped++;
         return false;
      }
      FileFlush(m_file_handle);
      m_error_reported = false;
      return true;
   }

   // Buffered write
   m_buffer += message + "\n";
   m_buffer_records++;

   if(StringLen(m_buffer) >= m_buffer_size ||
      (m_flush_interval > 0 && GetTickCount64() - m_last_flush_ms >= (ulong)m_flush_interval * 1000))
   {
      FlushBuffer();
   }

   // The file refuses writes: do not let the buffer grow without limit
   if(StringLen(m_buffer) > m_buffer_limit)
   {
      m_dropped += m_buffer_records;
      m_buffer = "";
      m_buffer_records = 0;
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Flush write buffer                                              |
//+------------------------------------------------------------------+
bool CFileHandler::FlushBuffer()
{
   if(StringLen(m_buffer) == 0)
      return true;
   if(m_file_handle == INVALID_HANDLE)
      return false;

   if(FileWriteString(m_file_handle, m_buffer) == 0)
   {
      ReportError("write to");
      return false;
   }

   FileFlush(m_file_handle);
   m_buffer = "";
   m_buffer_records = 0;
   m_last_flush_ms = GetTickCount64();
   m_error_reported = false;
   return true;
}

//+------------------------------------------------------------------+
//| Name of the rotated file number index                           |
//|   logs\ea.log -> logs\ea.3.log ; logs.v2\ea -> logs.v2\ea.3     |
//+------------------------------------------------------------------+
string CFileHandler::ArchiveName(int index)
{
   int name_start = 0;
   for(int i = StringLen(m_filename) - 1; i >= 0; i--)
   {
      ushort ch = StringGetCharacter(m_filename, i);
      if(ch == '\\' || ch == '/')
      {
         name_start = i + 1;
         break;
      }
   }

   int dot_pos = -1;
   for(int i = StringLen(m_filename) - 1; i > name_start; i--)
   {
      if(StringGetCharacter(m_filename, i) == '.')
      {
         dot_pos = i;
         break;
      }
   }

   if(dot_pos < 0)
      return StringFormat("%s.%d", m_filename, index);

   return StringFormat("%s.%d%s", StringSubstr(m_filename, 0, dot_pos), index, StringSubstr(m_filename, dot_pos));
}

//+------------------------------------------------------------------+
//| Rotate the file when it reaches the size limit                  |
//| Returns false only if there is no open file to write to         |
//+------------------------------------------------------------------+
bool CFileHandler::RotateIfNeeded()
{
   if(m_max_file_size <= 0)
      return true;

   // Buffered text is counted too (in characters - close enough for a size limit)
   ulong size = FileSize(m_file_handle) + (ulong)StringLen(m_buffer);
   if(size < (ulong)m_max_file_size)
      return true;

   FlushBuffer();
   FileClose(m_file_handle);
   m_file_handle = INVALID_HANDLE;

   // Next free number: archives of earlier runs are never overwritten
   int index = m_archive_index + 1;
   while(FileIsExist(ArchiveName(index), CommonFlag()))
      index++;

   if(FileMove(m_filename, CommonFlag(), ArchiveName(index), CommonFlag()))
   {
      m_archive_index = index;
      if(m_max_archives > 0 && index - m_max_archives >= 1)
         FileDelete(ArchiveName(index - m_max_archives), CommonFlag());
   }
   else
   {
      // Keep writing to the oversized file rather than lose records
      ReportError("rotate");
   }

   return OpenFile();
}

//+------------------------------------------------------------------+
//| Handle log record                                               |
//+------------------------------------------------------------------+
bool CFileHandler::Handle(const SLogRecord &record)
{
   if(!m_enabled || !IsEnabled(record.level))
      return false;
   
   // Apply filter if present
   if(m_filter != NULL && !m_filter.ShouldLog(record))
      return false;
   
   // Format message
   string formatted_message;
   if(m_formatter != NULL)
   {
      formatted_message = m_formatter.Format(record);
   }
   else
   {
      formatted_message = LogFormatDefault(record);
   }
   
   return WriteToFile(formatted_message);
}

//+------------------------------------------------------------------+
//| Set formatter                                                    |
//+------------------------------------------------------------------+
void CFileHandler::SetFormatter(ILogFormatter* formatter)
{
   m_formatter = formatter;
}

//+------------------------------------------------------------------+
//| Set filter                                                       |
//+------------------------------------------------------------------+
void CFileHandler::SetFilter(ILogFilter* filter)
{
   m_filter = filter;
}

//+------------------------------------------------------------------+
//| Set minimum logging level                                       |
//+------------------------------------------------------------------+
void CFileHandler::SetLevel(ENUM_LOG_LEVEL level)
{
   m_level = level;
}

//+------------------------------------------------------------------+
//| Check if level is enabled                                       |
//+------------------------------------------------------------------+
bool CFileHandler::IsEnabled(ENUM_LOG_LEVEL level)
{
   return m_enabled && level >= m_level;
}

//+------------------------------------------------------------------+
//| Flush handler                                                    |
//+------------------------------------------------------------------+
void CFileHandler::Flush()
{
   if(EnsureOpen())
      FlushBuffer();
}

//+------------------------------------------------------------------+
//| Close handler                                                    |
//+------------------------------------------------------------------+
void CFileHandler::Close()
{
   CloseFile();
   m_enabled = false;
   m_formatter = NULL;
   m_filter = NULL;
}
