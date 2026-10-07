//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "Interfaces.mqh"
#include <Arrays\ArrayObj.mqh>

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
   int               m_depth;             // Log() calls in progress (a handler may log too)
   int               m_dropped;           // Records dropped by the recursion guard
   static bool       s_recursion_reported; // Recursion already printed to the journal
   
   ulong             m_last_flush_ms;     // Last flush, GetTickCount64 (does not depend on ticks)
   int               m_auto_flush_interval; // Auto flush interval (seconds)
   
   void              CreateLogRecord(ENUM_LOG_LEVEL level, string message, 
                                   int error_code, string file, int line, string func,
                                   SLogRecord &record);
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
   ILogHandler*      GetHandler(int index);
   bool              HasHandler(ILogHandler* handler);
   int               DroppedCount() const { return m_dropped; }
};

// Static member initialization
bool CLogger::s_recursion_reported = false;

// A handler, formatter or filter may write to a logger itself. Such nested records are
// delivered; a chain deeper than this is cut (the record is counted in DroppedCount()).
#define LOGGER_MAX_DEPTH 4

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger(string name)
{
   m_name = name;
   m_level = LOG_INFO;
   m_enabled = true;
   m_depth = 0;
   m_dropped = 0;
   m_last_flush_ms = GetTickCount64();
   m_auto_flush_interval = 60; // 60 seconds default
   
   m_handlers.FreeMode(false); // Don't delete objects automatically
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger()
{
   // Обработчики логгеру не принадлежат: закрывает их владелец (фабрика или тот, кто создал)
   Flush();
   m_handlers.Clear();
}

//+------------------------------------------------------------------+
//| Handler by index, NULL if out of range                          |
//+------------------------------------------------------------------+
ILogHandler* CLogger::GetHandler(int index)
{
   if(index < 0 || index >= m_handlers.Total())
      return NULL;
   return dynamic_cast<ILogHandler*>(m_handlers.At(index));
}

//+------------------------------------------------------------------+
//| Is the handler attached to this logger                          |
//+------------------------------------------------------------------+
bool CLogger::HasHandler(ILogHandler* handler)
{
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      if(m_handlers.At(i) == handler)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Create log record with full information                         |
//+------------------------------------------------------------------+
void CLogger::CreateLogRecord(ENUM_LOG_LEVEL level, string message, 
                             int error_code, string file, int line, string func,
                             SLogRecord &record)
{
   record.level = level;
   record.logger_name = m_name;
   record.message = message;
   record.source_file = file;
   record.source_line = line;
   record.function_name = func;
   record.error_code = error_code;
   LogStampRecord(record);
}

//+------------------------------------------------------------------+
//| Check if auto-flush is needed                                   |
//+------------------------------------------------------------------+
void CLogger::CheckAutoFlush()
{
   if(m_auto_flush_interval > 0 &&
      GetTickCount64() - m_last_flush_ms >= (ulong)m_auto_flush_interval * 1000)
   {
      Flush();
      m_last_flush_ms = GetTickCount64();
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
   if(!IsEnabled(level))
      return;
   
   // Recursion guard: MQL5 programs are single-threaded, the only way to get here twice
   // is a handler that logs while handling a record
   if(m_depth >= LOGGER_MAX_DEPTH)
   {
      m_dropped++;
      if(!s_recursion_reported)
      {
         s_recursion_reported = true;
         PrintFormat("Logger '%s': a handler writes to the logger it serves, nested records deeper than %d are dropped",
                     m_name, LOGGER_MAX_DEPTH);
      }
      return;
   }
   m_depth++;
   
   // Create log record
   SLogRecord record;
   CreateLogRecord(level, message, error_code, file, line, func, record);
   
   // Send to all handlers
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      CObject* obj = m_handlers.At(i);
      ILogHandler* handler = dynamic_cast<ILogHandler*>(obj);
      if(handler != NULL)
      {
         handler.Handle(record);
      }
   }
   
   // Check for auto-flush
   CheckAutoFlush();
   
   m_depth--;
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
      m_handlers.Add((CObject*)handler);
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
      CObject* obj = m_handlers.At(i);
      ILogHandler* handler = dynamic_cast<ILogHandler*>(obj);
      if(handler != NULL)
      {
         handler.Flush();
      }
   }
}