//+------------------------------------------------------------------+
//|                                             PatternFormatter.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "..\Core\Interfaces.mqh"

//+------------------------------------------------------------------+
//| Поля шаблона                                                     |
//|   %timestamp%   время сервера (последний тик; в тестере — модели)|
//|   %localtime%   часы компьютера                                  |
//|   %elapsed%     секунды от запуска программы, 6 знаков           |
//|   %seq%         номер записи в программе                         |
//|   %level%  %logger%  %message%                                   |
//|   %file%  %line%  %function%                                     |
//|   %error%       код ошибки, пусто при 0                          |
//|   %error_code%  код ошибки всегда                                |
//|   %source_info% [файл:строка:функция], пусто без файла           |
//|   %error_info%  [Error: N], пусто при 0                          |
//|   %thread%      всегда 0                                         |
//| Неизвестное %имя% остаётся в строке как есть.                    |
//+------------------------------------------------------------------+
enum ENUM_LOG_FIELD
{
   LOG_FIELD_TEXT = 0,
   LOG_FIELD_TIMESTAMP,
   LOG_FIELD_LOCALTIME,
   LOG_FIELD_ELAPSED,
   LOG_FIELD_SEQUENCE,
   LOG_FIELD_LEVEL,
   LOG_FIELD_LOGGER,
   LOG_FIELD_MESSAGE,
   LOG_FIELD_FILE,
   LOG_FIELD_LINE,
   LOG_FIELD_FUNCTION,
   LOG_FIELD_ERROR,
   LOG_FIELD_ERROR_CODE,
   LOG_FIELD_SOURCE_INFO,
   LOG_FIELD_ERROR_INFO,
   LOG_FIELD_THREAD
};

//+------------------------------------------------------------------+
//| Formatter by pattern                                             |
//|                                                                  |
//| Шаблон разбирается один раз (SetPattern) на куски «текст» и     |
//| «поле»; строка собирается за один проход. Значения полей — в том|
//| числе текст сообщения — вставляются как есть и повторно не       |
//| просматриваются. Если поле пусто, один пробел рядом с ним        |
//| убирается, чтобы в строке не оставалось двойных пробелов шаблона.|
//+------------------------------------------------------------------+
class CPatternFormatter : public ILogFormatter
{
protected:
   string            m_pattern;           // Format pattern
   int               m_kinds[];           // ENUM_LOG_FIELD of every piece
   string            m_texts[];           // Text of LOG_FIELD_TEXT pieces
   int               m_pieces;            // Number of pieces

   void              Compile();
   void              AddPiece(int kind, string text);
   int               FieldByName(string name);
   virtual string    FieldValue(int field, const SLogRecord &record);

public:
                     CPatternFormatter(string pattern = "");
                    ~CPatternFormatter() {}

   // ILogFormatter implementation
   virtual string    Format(const SLogRecord &record) override;
   virtual void      SetPattern(string pattern) override;

   string            GetPattern() const { return m_pattern; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPatternFormatter::CPatternFormatter(string pattern = "") :
   m_pattern(pattern),
   m_pieces(0)
{
   if(StringLen(m_pattern) == 0)
      m_pattern = "%timestamp% [%level%] %message%";
   Compile();
}

//+------------------------------------------------------------------+
//| Set format pattern (an empty one is ignored)                    |
//+------------------------------------------------------------------+
void CPatternFormatter::SetPattern(string pattern)
{
   if(StringLen(pattern) > 0)
   {
      m_pattern = pattern;
      Compile();
   }
}

//+------------------------------------------------------------------+
//| Field by its name in the pattern, LOG_FIELD_TEXT if unknown     |
//+------------------------------------------------------------------+
int CPatternFormatter::FieldByName(string name)
{
   if(name == "timestamp")   return LOG_FIELD_TIMESTAMP;
   if(name == "localtime")   return LOG_FIELD_LOCALTIME;
   if(name == "elapsed")     return LOG_FIELD_ELAPSED;
   if(name == "seq")         return LOG_FIELD_SEQUENCE;
   if(name == "level")       return LOG_FIELD_LEVEL;
   if(name == "logger")      return LOG_FIELD_LOGGER;
   if(name == "message")     return LOG_FIELD_MESSAGE;
   if(name == "file")        return LOG_FIELD_FILE;
   if(name == "line")        return LOG_FIELD_LINE;
   if(name == "function")    return LOG_FIELD_FUNCTION;
   if(name == "error")       return LOG_FIELD_ERROR;
   if(name == "error_code")  return LOG_FIELD_ERROR_CODE;
   if(name == "source_info") return LOG_FIELD_SOURCE_INFO;
   if(name == "error_info")  return LOG_FIELD_ERROR_INFO;
   if(name == "thread")      return LOG_FIELD_THREAD;
   return LOG_FIELD_TEXT;
}

//+------------------------------------------------------------------+
//| Append a piece; neighbouring text pieces are merged             |
//+------------------------------------------------------------------+
void CPatternFormatter::AddPiece(int kind, string text)
{
   if(kind == LOG_FIELD_TEXT)
   {
      if(StringLen(text) == 0)
         return;
      if(m_pieces > 0 && m_kinds[m_pieces - 1] == LOG_FIELD_TEXT)
      {
         m_texts[m_pieces - 1] += text;
         return;
      }
   }
   ArrayResize(m_kinds, m_pieces + 1, 16);
   ArrayResize(m_texts, m_pieces + 1, 16);
   m_kinds[m_pieces] = kind;
   m_texts[m_pieces] = text;
   m_pieces++;
}

//+------------------------------------------------------------------+
//| Split the pattern into pieces                                   |
//+------------------------------------------------------------------+
void CPatternFormatter::Compile()
{
   m_pieces = 0;
   ArrayResize(m_kinds, 0);
   ArrayResize(m_texts, 0);

   int length = StringLen(m_pattern);
   int pos = 0;
   while(pos < length)
   {
      int open = StringFind(m_pattern, "%", pos);
      if(open < 0)
      {
         AddPiece(LOG_FIELD_TEXT, StringSubstr(m_pattern, pos));
         break;
      }
      int close = StringFind(m_pattern, "%", open + 1);
      int field = LOG_FIELD_TEXT;
      if(close > open + 1)
         field = FieldByName(StringSubstr(m_pattern, open + 1, close - open - 1));

      if(field == LOG_FIELD_TEXT)
      {
         // Not a field: the percent sign is plain text
         AddPiece(LOG_FIELD_TEXT, StringSubstr(m_pattern, pos, open - pos + 1));
         pos = open + 1;
      }
      else
      {
         AddPiece(LOG_FIELD_TEXT, StringSubstr(m_pattern, pos, open - pos));
         AddPiece(field, "");
         pos = close + 1;
      }
   }
}

//+------------------------------------------------------------------+
//| Value of a field                                                |
//+------------------------------------------------------------------+
string CPatternFormatter::FieldValue(int field, const SLogRecord &record)
{
   switch(field)
   {
      case LOG_FIELD_TIMESTAMP:   return TimeToString(record.timestamp, TIME_DATE | TIME_SECONDS);
      case LOG_FIELD_LOCALTIME:   return TimeToString(record.time_local, TIME_DATE | TIME_SECONDS);
      case LOG_FIELD_ELAPSED:     return StringFormat("%.6f", record.elapsed_us / 1000000.0);
      case LOG_FIELD_SEQUENCE:    return IntegerToString((long)record.sequence);
      case LOG_FIELD_LEVEL:       return LogLevelToString(record.level);
      case LOG_FIELD_LOGGER:      return record.logger_name;
      case LOG_FIELD_MESSAGE:     return record.message;
      case LOG_FIELD_FILE:        return record.source_file;
      case LOG_FIELD_LINE:        return IntegerToString(record.source_line);
      case LOG_FIELD_FUNCTION:    return record.function_name;
      case LOG_FIELD_ERROR:       return record.error_code != 0 ? IntegerToString(record.error_code) : "";
      case LOG_FIELD_ERROR_CODE:  return IntegerToString(record.error_code);
      case LOG_FIELD_SOURCE_INFO:
         if(StringLen(record.source_file) == 0)
            return "";
         return StringFormat("[%s:%d:%s]", record.source_file, record.source_line, record.function_name);
      case LOG_FIELD_ERROR_INFO:
         return record.error_code != 0 ? StringFormat("[Error: %d]", record.error_code) : "";
      case LOG_FIELD_THREAD:      return IntegerToString(record.thread_id);
   }
   return "";
}

//+------------------------------------------------------------------+
//| Format log record                                               |
//+------------------------------------------------------------------+
string CPatternFormatter::Format(const SLogRecord &record)
{
   string result = "";
   int kept = 0;                 // length of the line right after the last non-empty field
   bool skip_space = false;      // previous field was empty: drop one separating space
   bool ends_empty = false;      // the line ends with an empty field

   for(int i = 0; i < m_pieces; i++)
   {
      if(m_kinds[i] == LOG_FIELD_TEXT)
      {
         if(skip_space && StringGetCharacter(m_texts[i], 0) == ' ')
            result += StringSubstr(m_texts[i], 1);
         else
            result += m_texts[i];
         skip_space = false;
         ends_empty = false;
         continue;
      }

      string value = FieldValue(m_kinds[i], record);
      if(StringLen(value) == 0)
      {
         int length = StringLen(result);
         skip_space = (length == 0 || StringGetCharacter(result, length - 1) == ' ');
         ends_empty = true;
         continue;
      }
      result += value;
      kept = StringLen(result);
      skip_space = false;
      ends_empty = false;
   }

   // Pattern spaces left before a trailing empty field (never the spaces of a field value)
   if(ends_empty)
   {
      int length = StringLen(result);
      int end = length;
      while(end > kept && StringGetCharacter(result, end - 1) == ' ')
         end--;
      if(end < length)
         result = StringSubstr(result, 0, end);
   }

   return result;
}
