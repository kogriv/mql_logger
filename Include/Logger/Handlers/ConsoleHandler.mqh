//+------------------------------------------------------------------+
//|                                              ConsoleHandler.mqh |
//|                                  Professional MQL5 Logger System |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Professional MQL5 Logger System"
#property link      ""
#property version   "1.00"
#property strict

#include "../Core/Interfaces.mqh"

//+------------------------------------------------------------------+
//| Console handler - outputs to MetaTrader terminal               |
//+------------------------------------------------------------------+
class CConsoleHandler : public ILogHandler
{
private:
   ILogFormatter*    m_formatter;         // Message formatter
   ILogFilter*       m_filter;            // Message filter
   ENUM_LOG_LEVEL    m_level;             // Minimum level
   bool              m_enabled;           // Is handler enabled
   bool              m_use_print;         // Use Print() vs PrintFormat()
   bool              m_show_alerts;       // Show alerts for ERROR/FATAL

public:
                     CConsoleHandler(bool use_print = true, bool show_alerts = false);
                    ~CConsoleHandler();
   
   // ILogHandler implementation
   virtual bool      Handle(const SLogRecord &record) override;
   virtual void      SetFormatter(ILogFormatter* formatter) override;
   virtual void      SetFilter(ILogFilter* filter) override;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override;
   virtual void      Flush() override;
   virtual void      Close() override;
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) override;
   
   // Console-specific methods
   void              SetUsePrint(bool use_print) { m_use_print = use_print; }
   bool              GetUsePrint() const { return m_use_print; }
   void              SetShowAlerts(bool show_alerts) { m_show_alerts = show_alerts; }
   bool              GetShowAlerts() const { return m_show_alerts; }
   void              Enable(bool enabled) { m_enabled = enabled; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CConsoleHandler::CConsoleHandler(bool use_print = true, bool show_alerts = false) :
   m_formatter(NULL),
   m_filter(NULL),
   m_level(LOG_TRACE),
   m_enabled(true),
   m_use_print(use_print),
   m_show_alerts(show_alerts)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CConsoleHandler::~CConsoleHandler()
{
   Close();
}

//+------------------------------------------------------------------+
//| Handle log record                                               |
//+------------------------------------------------------------------+
bool CConsoleHandler::Handle(const SLogRecord &record)
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
      // Default formatting
      formatted_message = StringFormat("[%s] %s: %s",
                                      TimeToString(record.timestamp, TIME_DATE|TIME_SECONDS),
                                      LogLevelToString(record.level),
                                      record.message);
   }
   
   // Output to console
   if(m_use_print)
   {
      Print(formatted_message);
   }
   else
   {
      PrintFormat("%s", formatted_message);
   }
   
   // Show alert for critical messages
   if(m_show_alerts && (record.level == LOG_ERROR || record.level == LOG_FATAL))
   {
      Alert(StringFormat("[%s] %s", LogLevelToString(record.level), record.message));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Set formatter                                                    |
//+------------------------------------------------------------------+
void CConsoleHandler::SetFormatter(ILogFormatter* formatter)
{
   m_formatter = formatter;
}

//+------------------------------------------------------------------+
//| Set filter                                                       |
//+------------------------------------------------------------------+
void CConsoleHandler::SetFilter(ILogFilter* filter)
{
   m_filter = filter;
}

//+------------------------------------------------------------------+
//| Set minimum logging level                                       |
//+------------------------------------------------------------------+
void CConsoleHandler::SetLevel(ENUM_LOG_LEVEL level)
{
   m_level = level;
}

//+------------------------------------------------------------------+
//| Check if level is enabled                                       |
//+------------------------------------------------------------------+
bool CConsoleHandler::IsEnabled(ENUM_LOG_LEVEL level)
{
   return m_enabled && level >= m_level;
}

//+------------------------------------------------------------------+
//| Flush (no-op for console)                                       |
//+------------------------------------------------------------------+
void CConsoleHandler::Flush()
{
   // Console output is immediate, no buffering
}

//+------------------------------------------------------------------+
//| Close handler                                                    |
//+------------------------------------------------------------------+
void CConsoleHandler::Close()
{
   m_enabled = false;
   m_formatter = NULL;
   m_filter = NULL;
}
