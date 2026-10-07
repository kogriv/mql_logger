//+------------------------------------------------------------------+
//|                                            DetailedFormatter.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "PatternFormatter.mqh"

//+------------------------------------------------------------------+
//| Detailed formatter - comprehensive message formatting          |
//| Шаблон по умолчанию:                                             |
//|   %timestamp% [%level%] %logger%: %message% %source_info% %error_info% |
//| Уровень дополняется пробелами до 5 знаков. Многострочный вид —  |
//| второй параметр конструктора. Поля — см. PatternFormatter.mqh.   |
//+------------------------------------------------------------------+
class CDetailedFormatter : public CPatternFormatter
{
private:
   bool              m_show_source_info;  // Fill %source_info%
   bool              m_show_thread_info;  // Fill %thread%
   bool              m_show_error_info;   // Fill %error_info%
   bool              m_multiline_format;  // Multiline layout of source and error parts

protected:
   virtual string    FieldValue(int field, const SLogRecord &record) override;

public:
                     CDetailedFormatter(string pattern = "", bool multiline = false);
                    ~CDetailedFormatter() {}

   // Detailed formatter specific methods
   void              SetShowSourceInfo(bool show) { m_show_source_info = show; }
   bool              GetShowSourceInfo() const { return m_show_source_info; }
   void              SetShowThreadInfo(bool show) { m_show_thread_info = show; }
   bool              GetShowThreadInfo() const { return m_show_thread_info; }
   void              SetShowErrorInfo(bool show) { m_show_error_info = show; }
   bool              GetShowErrorInfo() const { return m_show_error_info; }
   void              SetMultilineFormat(bool multiline) { m_multiline_format = multiline; }
   bool              GetMultilineFormat() const { return m_multiline_format; }

   // Устарело: журнал MetaTrader 5 не понимает цветовые коды; методы оставлены, чтобы собирался старый код
   void              SetUseColors(bool use_colors) {}
   bool              GetUseColors() const { return false; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDetailedFormatter::CDetailedFormatter(string pattern = "", bool multiline = false) :
   CPatternFormatter(pattern),
   m_show_source_info(true),
   m_show_thread_info(false),
   m_show_error_info(true),
   m_multiline_format(multiline)
{
   if(StringLen(pattern) == 0)
   {
      if(m_multiline_format)
         SetPattern("=== %level% ===\n"
                    "Time: %timestamp%\n"
                    "Logger: %logger%\n"
                    "Message: %message%\n"
                    "%source_info%"
                    "%error_info%"
                    "================");
      else
         SetPattern("%timestamp% [%level%] %logger%: %message% %source_info% %error_info%");
   }
}

//+------------------------------------------------------------------+
//| Value of a field                                                |
//+------------------------------------------------------------------+
string CDetailedFormatter::FieldValue(int field, const SLogRecord &record)
{
   switch(field)
   {
      case LOG_FIELD_LEVEL:
      {
         // Pad level string for alignment
         string level = LogLevelToString(record.level);
         while(StringLen(level) < 5)
            level += " ";
         return level;
      }
      case LOG_FIELD_SOURCE_INFO:
         if(!m_show_source_info || StringLen(record.source_file) == 0)
            return "";
         if(m_multiline_format)
            return StringFormat("Source: %s:%d in %s()\n", record.source_file, record.source_line, record.function_name);
         break;
      case LOG_FIELD_ERROR_INFO:
         if(!m_show_error_info || record.error_code == 0)
            return "";
         if(m_multiline_format)
            return StringFormat("Error: %d\n", record.error_code);
         break;
      case LOG_FIELD_THREAD:
         if(!m_show_thread_info)
            return "";
         break;
   }
   return CPatternFormatter::FieldValue(field, record);
}
