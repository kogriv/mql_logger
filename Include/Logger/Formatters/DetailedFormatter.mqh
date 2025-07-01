//+------------------------------------------------------------------+
//|                                            DetailedFormatter.mqh |
//|                                  Professional MQL5 Logger System |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Professional MQL5 Logger System"
#property link      ""
#property version   "1.00"
#property strict

#include "../Core/Interfaces.mqh"

//+------------------------------------------------------------------+
//| Detailed formatter - comprehensive message formatting          |
//+------------------------------------------------------------------+
class CDetailedFormatter : public ILogFormatter
{
private:
   string            m_pattern;           // Format pattern
   bool              m_show_source_info;  // Show source file/line/function
   bool              m_show_thread_info;  // Show thread information
   bool              m_show_error_info;   // Show error codes
   bool              m_use_colors;        // Use color codes (for supported outputs)
   bool              m_multiline_format;  // Use multiline format for complex info
   
   string            FormatTimestamp(datetime timestamp);
   string            FormatLevel(ENUM_LOG_LEVEL level, bool use_colors);
   string            FormatSourceInfo(const SLogRecord &record);
   string            FormatErrorInfo(int error_code);
   string            GetLevelColor(ENUM_LOG_LEVEL level);
   string            WrapWithColor(string text, string color);

public:
                     CDetailedFormatter(string pattern = "", bool multiline = false);
                    ~CDetailedFormatter();
   
   // ILogFormatter implementation
   virtual string    Format(const SLogRecord &record) override;
   virtual void      SetPattern(string pattern) override;
   
   // Detailed formatter specific methods
   void              SetShowSourceInfo(bool show) { m_show_source_info = show; }
   bool              GetShowSourceInfo() const { return m_show_source_info; }
   void              SetShowThreadInfo(bool show) { m_show_thread_info = show; }
   bool              GetShowThreadInfo() const { return m_show_thread_info; }
   void              SetShowErrorInfo(bool show) { m_show_error_info = show; }
   bool              GetShowErrorInfo() const { return m_show_error_info; }
   void              SetUseColors(bool use_colors) { m_use_colors = use_colors; }
   bool              GetUseColors() const { return m_use_colors; }
   void              SetMultilineFormat(bool multiline) { m_multiline_format = multiline; }
   bool              GetMultilineFormat() const { return m_multiline_format; }
   string            GetPattern() const { return m_pattern; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDetailedFormatter::CDetailedFormatter(string pattern = "", bool multiline = false) :
   m_pattern(pattern),
   m_show_source_info(true),
   m_show_thread_info(false),
   m_show_error_info(true),
   m_use_colors(false),
   m_multiline_format(multiline)
{
   if(StringLen(m_pattern) == 0)
   {
      if(m_multiline_format)
      {
         m_pattern = "=== %level% ===\n"
                    "Time: %timestamp%\n"
                    "Logger: %logger%\n"
                    "Message: %message%\n"
                    "%source_info%"
                    "%error_info%"
                    "================";
      }
      else
      {
         m_pattern = "%timestamp% [%level%] %logger%: %message% %source_info% %error_info%";
      }
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDetailedFormatter::~CDetailedFormatter()
{
}

//+------------------------------------------------------------------+
//| Format log record                                               |
//+------------------------------------------------------------------+
string CDetailedFormatter::Format(const SLogRecord &record)
{
   string result = m_pattern;
   
   // Replace pattern placeholders
   StringReplace(result, "%timestamp%", FormatTimestamp(record.timestamp));
   StringReplace(result, "%level%", FormatLevel(record.level, m_use_colors));
   StringReplace(result, "%logger%", record.logger_name);
   StringReplace(result, "%message%", record.message);
   
   // Source information
   if(m_show_source_info)
   {
      StringReplace(result, "%source_info%", FormatSourceInfo(record));
   }
   else
   {
      StringReplace(result, "%source_info%", "");
   }
   
   // Error information
   if(m_show_error_info && record.error_code != 0)
   {
      StringReplace(result, "%error_info%", FormatErrorInfo(record.error_code));
   }
   else
   {
      StringReplace(result, "%error_info%", "");
   }
   
   // Thread information
   if(m_show_thread_info)
   {
      StringReplace(result, "%thread%", IntegerToString(record.thread_id));
   }
   else
   {
      StringReplace(result, "%thread%", "");
   }
   
   // Individual field replacements
   StringReplace(result, "%file%", record.source_file);
   StringReplace(result, "%line%", IntegerToString(record.source_line));
   StringReplace(result, "%function%", record.function_name);
   StringReplace(result, "%error_code%", IntegerToString(record.error_code));
   
   // Clean up formatting
   if(!m_multiline_format)
   {
      // Remove multiple spaces for single-line format
      while(StringFind(result, "  ") >= 0)
      {
         StringReplace(result, "  ", " ");
      }
      
      // Trim spaces
      StringTrimLeft(result);
      StringTrimRight(result);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Set format pattern                                              |
//+------------------------------------------------------------------+
void CDetailedFormatter::SetPattern(string pattern)
{
   if(StringLen(pattern) > 0)
   {
      m_pattern = pattern;
   }
}

//+------------------------------------------------------------------+
//| Format timestamp with high precision                           |
//+------------------------------------------------------------------+
string CDetailedFormatter::FormatTimestamp(datetime timestamp)
{
   // Enhanced timestamp with milliseconds if available
   string base_time = TimeToString(timestamp, TIME_DATE | TIME_SECONDS);
   
   // Add milliseconds (approximation using GetTickCount)
   uint ms = GetTickCount() % 1000;
   return StringFormat("%s.%03d", base_time, ms);
}

//+------------------------------------------------------------------+
//| Format log level with optional colors                          |
//+------------------------------------------------------------------+
string CDetailedFormatter::FormatLevel(ENUM_LOG_LEVEL level, bool use_colors)
{
   string level_str = LogLevelToString(level);
   
   if(use_colors)
   {
      return WrapWithColor(level_str, GetLevelColor(level));
   }
   
   // Pad level string for alignment
   while(StringLen(level_str) < 5)
   {
      level_str += " ";
   }
   
   return level_str;
}

//+------------------------------------------------------------------+
//| Format source information                                       |
//+------------------------------------------------------------------+
string CDetailedFormatter::FormatSourceInfo(const SLogRecord &record)
{
   if(StringLen(record.source_file) == 0)
      return "";
   
   if(m_multiline_format)
   {
      return StringFormat("Source: %s:%d in %s()\n", 
                         record.source_file, 
                         record.source_line, 
                         record.function_name);
   }
   else
   {
      return StringFormat("[%s:%d:%s]", 
                         record.source_file, 
                         record.source_line, 
                         record.function_name);
   }
}

//+------------------------------------------------------------------+
//| Format error information                                        |
//+------------------------------------------------------------------+
string CDetailedFormatter::FormatErrorInfo(int error_code)
{
   if(error_code == 0)
      return "";
   
   if(m_multiline_format)
   {
      return StringFormat("Error: %d\n", error_code);
   }
   else
   {
      return StringFormat("[Error: %d]", error_code);
   }
}

//+------------------------------------------------------------------+
//| Get color code for log level                                   |
//+------------------------------------------------------------------+
string CDetailedFormatter::GetLevelColor(ENUM_LOG_LEVEL level)
{
   switch(level)
   {
      case LOG_TRACE: return "37";   // White
      case LOG_DEBUG: return "36";   // Cyan
      case LOG_INFO:  return "32";   // Green
      case LOG_WARN:  return "33";   // Yellow
      case LOG_ERROR: return "31";   // Red
      case LOG_FATAL: return "35";   // Magenta
      default:        return "37";   // White
   }
}

//+------------------------------------------------------------------+
//| Wrap text with ANSI color codes                                |
//+------------------------------------------------------------------+
string CDetailedFormatter::WrapWithColor(string text, string color)
{
   return StringFormat("\033[%sm%s\033[0m", color, text);
}
