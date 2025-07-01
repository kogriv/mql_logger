//+------------------------------------------------------------------+
//|                                             SimpleFormatter.mqh |
//|                                  Professional MQL5 Logger System |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Professional MQL5 Logger System"
#property link      ""
#property version   "1.00"
#property strict

#include "../Core/Interfaces.mqh"

//+------------------------------------------------------------------+
//| Simple formatter - basic message formatting                    |
//+------------------------------------------------------------------+
class CSimpleFormatter : public ILogFormatter
{
private:
   string            m_pattern;           // Format pattern
   bool              m_show_timestamp;    // Show timestamp
   bool              m_show_level;        // Show log level
   bool              m_show_logger_name;  // Show logger name
   bool              m_show_message;      // Show message (always true)
   
   string            FormatTimestamp(datetime timestamp);
   string            FormatLevel(ENUM_LOG_LEVEL level);

public:
                     CSimpleFormatter(string pattern = "");
                    ~CSimpleFormatter();
   
   // ILogFormatter implementation
   virtual string    Format(const SLogRecord &record) override;
   virtual void      SetPattern(string pattern) override;
   
   // Simple formatter specific methods
   void              SetShowTimestamp(bool show) { m_show_timestamp = show; }
   bool              GetShowTimestamp() const { return m_show_timestamp; }
   void              SetShowLevel(bool show) { m_show_level = show; }
   bool              GetShowLevel() const { return m_show_level; }
   void              SetShowLoggerName(bool show) { m_show_logger_name = show; }
   bool              GetShowLoggerName() const { return m_show_logger_name; }
   string            GetPattern() const { return m_pattern; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSimpleFormatter::CSimpleFormatter(string pattern = "") :
   m_pattern(pattern),
   m_show_timestamp(true),
   m_show_level(true),
   m_show_logger_name(false),
   m_show_message(true)
{
   if(StringLen(m_pattern) == 0)
   {
      m_pattern = "%timestamp% [%level%] %message%";
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSimpleFormatter::~CSimpleFormatter()
{
}

//+------------------------------------------------------------------+
//| Format log record                                               |
//+------------------------------------------------------------------+
string CSimpleFormatter::Format(const SLogRecord &record)
{
   string result = m_pattern;
   
   // Replace pattern placeholders
   if(m_show_timestamp)
   {
      StringReplace(result, "%timestamp%", FormatTimestamp(record.timestamp));
   }
   else
   {
      StringReplace(result, "%timestamp%", "");
   }
   
   if(m_show_level)
   {
      StringReplace(result, "%level%", FormatLevel(record.level));
   }
   else
   {
      StringReplace(result, "%level%", "");
   }
   
   if(m_show_logger_name)
   {
      StringReplace(result, "%logger%", record.logger_name);
   }
   else
   {
      StringReplace(result, "%logger%", "");
   }
   
   StringReplace(result, "%message%", record.message);
   
   // Optional replacements
   StringReplace(result, "%file%", record.source_file);
   StringReplace(result, "%line%", IntegerToString(record.source_line));
   StringReplace(result, "%function%", record.function_name);
   StringReplace(result, "%thread%", IntegerToString(record.thread_id));
   
   if(record.error_code != 0)
   {
      StringReplace(result, "%error%", IntegerToString(record.error_code));
   }
   else
   {
      StringReplace(result, "%error%", "");
   }
   
   // Clean up multiple spaces
   while(StringFind(result, "  ") >= 0)
   {
      StringReplace(result, "  ", " ");
   }
   
   // Trim leading/trailing spaces
   StringTrimLeft(result);
   StringTrimRight(result);
   
   return result;
}

//+------------------------------------------------------------------+
//| Set format pattern                                              |
//+------------------------------------------------------------------+
void CSimpleFormatter::SetPattern(string pattern)
{
   if(StringLen(pattern) > 0)
   {
      m_pattern = pattern;
   }
}

//+------------------------------------------------------------------+
//| Format timestamp                                                |
//+------------------------------------------------------------------+
string CSimpleFormatter::FormatTimestamp(datetime timestamp)
{
   return TimeToString(timestamp, TIME_DATE | TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Format log level                                                |
//+------------------------------------------------------------------+
string CSimpleFormatter::FormatLevel(ENUM_LOG_LEVEL level)
{
   return LogLevelToString(level);
}
