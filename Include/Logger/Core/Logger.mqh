//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Professional MQL5 Logger System |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Professional MQL5 Logger System"
#property link      ""
#property version   "1.00"
#property strict

#include "Interfaces.mqh"
#include <Arrays/ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Main logger implementation                                       |
//+------------------------------------------------------------------+
class CLogger : public ILogger
{
private:
   string            m_name;              // Logger name
   ENUM_LOG_LEVEL    m_level;             // Minimum level
   CArrayObj         m_handlers;          // List of handlers
   bool              m_enabled;           // Is logger enabled
   static bool       m_global_lock;       // Global lock for thread safety
   
   datetime          m_last_flush_time;   // Last flush time
   int               m_auto_flush_interval; // Auto flush interval (seconds)
   
   void              CreateLogRecord(ENUM_LOG_LEVEL level, string message, 
                                   int error_code, string file, int line, string func,
                                   SLogRecord &record);
   bool              AcquireLock();
   void              ReleaseLock();
   void              CheckAutoFlush();

public:
                     CLogger(string name);
                    ~CLogger();
   
   // ILogger implementation
   virtual void      Trace(string message) override;
   virtual void      Debug(string message) override;
   virtual void      Info(string message) override;
   virtual void      Warn(string message) override;
   virtual void      Error(string message, int error_code = 0) override;
   virtual void      Fatal(string message, int error_code = 0) override;
   virtual void      Log(ENUM_LOG_LEVEL level, string message, int error_code = 0,
                        string file = "", int line = 0, string func = "") override;
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) override;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override;
   virtual void      AddHandler(ILogHandler* handler) override;
   virtual void      RemoveHandler(ILogHandler* handler) override;
   virtual void      Flush() override;
   virtual string    Name() override { return m_name; }
   
   // Additional methods
   void              Enable(bool enabled) { m_enabled = enabled; }
   bool              IsLoggerEnabled() const { return m_enabled; }
   void              SetAutoFlushInterval(int seconds) { m_auto_flush_interval = seconds; }
   int               GetHandlerCount() const { return m_handlers.Total(); }
};

// Static member initialization
bool CLogger::m_global_lock = false;

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger(string name) : m_name(name), 
                               m_level(LOG_INFO), 
                               m_enabled(true),
                               m_last_flush_time(TimeCurrent()),
                               m_auto_flush_interval(60) // 60 seconds default
{
   m_handlers.FreeMode(false); // Don't delete objects automatically
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger()
{
   Flush();
   
   // Close all handlers
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      ILogHandler* handler = m_handlers.At(i);
      if(handler != NULL)
      {
         handler.Close();
      }
   }
   
   m_handlers.Clear();
}

//+------------------------------------------------------------------+
//| Create log record with full information                         |
//+------------------------------------------------------------------+
void CLogger::CreateLogRecord(ENUM_LOG_LEVEL level, string message, 
                             int error_code, string file, int line, string func,
                             SLogRecord &record)
{
   record.level = level;
   record.timestamp = TimeCurrent();
   record.logger_name = m_name;
   record.message = message;
   record.source_file = file;
   record.source_line = line;
   record.function_name = func;
   record.thread_id = 0; // MQL5 doesn't have real threads
   record.error_code = error_code;
}

//+------------------------------------------------------------------+
//| Acquire global lock (simple implementation for MQL5)           |
//+------------------------------------------------------------------+
bool CLogger::AcquireLock()
{
   if(m_global_lock) return false;
   m_global_lock = true;
   return true;
}

//+------------------------------------------------------------------+
//| Release global lock                                             |
//+------------------------------------------------------------------+
void CLogger::ReleaseLock()
{
   m_global_lock = false;
}

//+------------------------------------------------------------------+
//| Check if auto-flush is needed                                   |
//+------------------------------------------------------------------+
void CLogger::CheckAutoFlush()
{
   if(m_auto_flush_interval > 0 && 
      TimeCurrent() - m_last_flush_time >= m_auto_flush_interval)
   {
      Flush();
      m_last_flush_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Log trace message                                               |
//+------------------------------------------------------------------+
void CLogger::Trace(string message)
{
   Log(LOG_TRACE, message);
}

//+------------------------------------------------------------------+
//| Log debug message                                               |
//+------------------------------------------------------------------+
void CLogger::Debug(string message)
{
   Log(LOG_DEBUG, message);
}

//+------------------------------------------------------------------+
//| Log info message                                                |
//+------------------------------------------------------------------+
void CLogger::Info(string message)
{
   Log(LOG_INFO, message);
}

//+------------------------------------------------------------------+
//| Log warning message                                             |
//+------------------------------------------------------------------+
void CLogger::Warn(string message)
{
   Log(LOG_WARN, message);
}

//+------------------------------------------------------------------+
//| Log error message                                               |
//+------------------------------------------------------------------+
void CLogger::Error(string message, int error_code = 0)
{
   Log(LOG_ERROR, message, error_code);
}

//+------------------------------------------------------------------+
//| Log fatal message                                               |
//+------------------------------------------------------------------+
void CLogger::Fatal(string message, int error_code = 0)
{
   Log(LOG_FATAL, message, error_code);
}

//+------------------------------------------------------------------+
//| Main logging method                                             |
//+------------------------------------------------------------------+
void CLogger::Log(ENUM_LOG_LEVEL level, string message, int error_code = 0,
                 string file = "", int line = 0, string func = "")
{
   // Check if logging is enabled and level is sufficient
   if(!m_enabled || !IsEnabled(level))
      return;
   
   // Acquire lock to prevent recursion
   if(!AcquireLock())
      return;
   
   // Create log record
   SLogRecord record;
   CreateLogRecord(level, message, error_code, file, line, func, record);
   
   // Send to all handlers
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      ILogHandler* handler = m_handlers.At(i);
      if(handler != NULL)
      {
         handler.Handle(record);
      }
   }
   
   // Check for auto-flush
   CheckAutoFlush();
   
   // Release lock
   ReleaseLock();
}

//+------------------------------------------------------------------+
//| Check if level is enabled                                       |
//+------------------------------------------------------------------+
bool CLogger::IsEnabled(ENUM_LOG_LEVEL level)
{
   return m_enabled && level >= m_level;
}

//+------------------------------------------------------------------+
//| Set minimum logging level                                       |
//+------------------------------------------------------------------+
void CLogger::SetLevel(ENUM_LOG_LEVEL level)
{
   m_level = level;
}

//+------------------------------------------------------------------+
//| Add handler                                                     |
//+------------------------------------------------------------------+
void CLogger::AddHandler(ILogHandler* handler)
{
   if(handler != NULL)
   {
      m_handlers.Add(handler);
   }
}

//+------------------------------------------------------------------+
//| Remove handler                                                  |
//+------------------------------------------------------------------+
void CLogger::RemoveHandler(ILogHandler* handler)
{
   if(handler != NULL)
   {
      for(int i = 0; i < m_handlers.Total(); i++)
      {
         if(m_handlers.At(i) == handler)
         {
            m_handlers.Delete(i);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Flush all handlers                                              |
//+------------------------------------------------------------------+
void CLogger::Flush()
{
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      ILogHandler* handler = m_handlers.At(i);
      if(handler != NULL)
      {
         handler.Flush();
      }
   }
}
