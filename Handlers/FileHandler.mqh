//+------------------------------------------------------------------+
//|                                                 FileHandler.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

#include "..\Core\Interfaces.mqh"

//+------------------------------------------------------------------+
//| File handler - writes logs to files                            |
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
   bool              m_auto_flush;        // Auto flush after each write
   int               m_max_file_size;     // Max file size in bytes (0 = unlimited)
   int               m_buffer_size;       // Buffer size for writes
   string            m_buffer;            // Write buffer
   datetime          m_last_flush;        // Last flush time
   int               m_flush_interval;    // Flush interval in seconds
   
   bool              OpenFile();
   void              CloseFile();
   bool              WriteToFile(string message);
   void              FlushBuffer();
   bool              CheckFileSize();
   string            GenerateRotatedFilename();

public:
                     CFileHandler(string filename, bool append = true, bool auto_flush = false);
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
   void              SetFlushInterval(int seconds) { m_flush_interval = seconds; }
   int               GetFlushInterval() const { return m_flush_interval; }
   string            GetFilename() const { return m_filename; }
   void              Enable(bool enabled) { m_enabled = enabled; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFileHandler::CFileHandler(string filename, bool append = true, bool auto_flush = false) :
   m_formatter(NULL),
   m_filter(NULL),
   m_level(LOG_TRACE),
   m_enabled(true),
   m_filename(filename),
   m_file_handle(INVALID_HANDLE),
   m_append_mode(append),
   m_auto_flush(auto_flush),
   m_max_file_size(0),
   m_buffer_size(8192),
   m_buffer(""),
   m_last_flush(TimeCurrent()),
   m_flush_interval(60)
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
//| Open log file                                                   |
//+------------------------------------------------------------------+
bool CFileHandler::OpenFile()
{
   if(m_file_handle != INVALID_HANDLE)
      CloseFile();
   
   int flags = FILE_WRITE | FILE_TXT;
   if(!m_append_mode)
      flags |= FILE_REWRITE;
   
   m_file_handle = FileOpen(m_filename, flags);
   
   if(m_file_handle == INVALID_HANDLE)
   {
      PrintFormat("Failed to open log file: %s, Error: %d", m_filename, GetLastError());
      return false;
   }
   
   // Move to end of file if appending
   if(m_append_mode)
   {
      FileSeek(m_file_handle, 0, SEEK_END);
   }
   
   return true;
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
   if(m_file_handle == INVALID_HANDLE)
   {
      if(!OpenFile())
         return false;
   }
   
   // Check file size limits
   if(m_max_file_size > 0 && !CheckFileSize())
      return false;
   
   if(m_auto_flush)
   {
      // Direct write
      if(FileWrite(m_file_handle, message) < 0)
      {
         PrintFormat("Failed to write to log file: %s, Error: %d", m_filename, GetLastError());
         return false;
      }
      FileFlush(m_file_handle);
   }
   else
   {
      // Buffered write
      m_buffer += message + "\n";
      
      // Flush buffer if it's getting large or if interval has passed
      if(StringLen(m_buffer) >= m_buffer_size || 
         (m_flush_interval > 0 && TimeCurrent() - m_last_flush >= m_flush_interval))
      {
         FlushBuffer();
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Flush write buffer                                              |
//+------------------------------------------------------------------+
void CFileHandler::FlushBuffer()
{
   if(m_file_handle != INVALID_HANDLE && StringLen(m_buffer) > 0)
   {
      if(FileWriteString(m_file_handle, m_buffer) < 0)
      {
         PrintFormat("Failed to flush buffer to log file: %s, Error: %d", m_filename, GetLastError());
      }
      else
      {
         FileFlush(m_file_handle);
         m_buffer = "";
         m_last_flush = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| Check file size and rotate if necessary                        |
//+------------------------------------------------------------------+
bool CFileHandler::CheckFileSize()
{
   if(m_max_file_size <= 0)
      return true;
   
   long file_size = FileSize(m_file_handle);
   if(file_size >= m_max_file_size)
   {
      // File is too large, need to rotate
      CloseFile();
      
      // Generate rotated filename
      string rotated_name = GenerateRotatedFilename();
      
      // Move current file to rotated name
      if(!FileMove(m_filename, rotated_name, FILE_REWRITE))
      {
         PrintFormat("Failed to rotate log file from %s to %s, Error: %d", 
                    m_filename, rotated_name, GetLastError());
         return false;
      }
      
      // Open new file
      return OpenFile();
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Generate rotated filename                                       |
//+------------------------------------------------------------------+
string CFileHandler::GenerateRotatedFilename()
{
   string base_name = m_filename;
   int dot_pos = StringFind(base_name, ".", 0);
   
   if(dot_pos >= 0)
   {
      string name_part = StringSubstr(base_name, 0, dot_pos);
      string ext_part = StringSubstr(base_name, dot_pos);
      return StringFormat("%s_%s%s", name_part, TimeToString(TimeCurrent(), TIME_DATE), ext_part);
   }
   else
   {
      return StringFormat("%s_%s", base_name, TimeToString(TimeCurrent(), TIME_DATE));
   }
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
      // Default formatting for files
      formatted_message = StringFormat("%s [%s] %s: %s",
                                      TimeToString(record.timestamp, TIME_DATE|TIME_SECONDS),
                                      LogLevelToString(record.level),
                                      record.logger_name,
                                      record.message);
      
      // Add source information if available
      if(StringLen(record.source_file) > 0)
      {
         formatted_message += StringFormat(" [%s:%d:%s]", 
                                         record.source_file, 
                                         record.source_line, 
                                         record.function_name);
      }
      
      // Add error code if present
      if(record.error_code != 0)
      {
         formatted_message += StringFormat(" [Error: %d]", record.error_code);
      }
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
