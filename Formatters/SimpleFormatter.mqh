//+------------------------------------------------------------------+
//|                                              SimpleFormatter.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "PatternFormatter.mqh"

//+------------------------------------------------------------------+
//| Simple formatter - basic message formatting                    |
//| Шаблон по умолчанию: %timestamp% [%level%] %message%             |
//| Поля — см. PatternFormatter.mqh.                                 |
//+------------------------------------------------------------------+
class CSimpleFormatter : public CPatternFormatter
{
private:
   bool              m_show_timestamp;    // Fill %timestamp%
   bool              m_show_level;        // Fill %level%
   bool              m_show_logger_name;  // Fill %logger%

protected:
   virtual string    FieldValue(int field, const SLogRecord &record) override;

public:
                     CSimpleFormatter(string pattern = "");
                    ~CSimpleFormatter() {}

   // Simple formatter specific methods: a hidden field is rendered empty
   void              SetShowTimestamp(bool show) { m_show_timestamp = show; }
   bool              GetShowTimestamp() const { return m_show_timestamp; }
   void              SetShowLevel(bool show) { m_show_level = show; }
   bool              GetShowLevel() const { return m_show_level; }
   void              SetShowLoggerName(bool show) { m_show_logger_name = show; }
   bool              GetShowLoggerName() const { return m_show_logger_name; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSimpleFormatter::CSimpleFormatter(string pattern = "") :
   CPatternFormatter(pattern),
   m_show_timestamp(true),
   m_show_level(true),
   m_show_logger_name(true)
{
}

//+------------------------------------------------------------------+
//| Value of a field                                                |
//+------------------------------------------------------------------+
string CSimpleFormatter::FieldValue(int field, const SLogRecord &record)
{
   if(field == LOG_FIELD_TIMESTAMP && !m_show_timestamp)
      return "";
   if(field == LOG_FIELD_LEVEL && !m_show_level)
      return "";
   if(field == LOG_FIELD_LOGGER && !m_show_logger_name)
      return "";
   return CPatternFormatter::FieldValue(field, record);
}
