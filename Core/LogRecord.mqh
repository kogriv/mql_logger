//+------------------------------------------------------------------+
//|                                                    LogRecord.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Log levels enumeration                                           |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_TRACE = 0,    // Detailed debugging information
   LOG_DEBUG = 1,    // Debug information
   LOG_INFO = 2,     // Informational messages
   LOG_WARN = 3,     // Warning messages
   LOG_ERROR = 4,    // Error messages
   LOG_FATAL = 5     // Critical errors
};

//+------------------------------------------------------------------+
//| Convert log level to string                                      |
//+------------------------------------------------------------------+
string LogLevelToString(ENUM_LOG_LEVEL level)
{
   switch(level)
   {
      case LOG_TRACE: return "TRACE";
      case LOG_DEBUG: return "DEBUG";
      case LOG_INFO:  return "INFO";
      case LOG_WARN:  return "WARN";
      case LOG_ERROR: return "ERROR";
      case LOG_FATAL: return "FATAL";
      default:        return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Convert string to log level                                      |
//+------------------------------------------------------------------+
ENUM_LOG_LEVEL StringToLogLevel(string level_str)
{
   string upper_str = level_str;
   StringToUpper(upper_str);  // Исправлено: StringUpper -> StringToUpper
   
   if(upper_str == "TRACE") return LOG_TRACE;
   if(upper_str == "DEBUG") return LOG_DEBUG;
   if(upper_str == "INFO")  return LOG_INFO;
   if(upper_str == "WARN")  return LOG_WARN;
   if(upper_str == "ERROR") return LOG_ERROR;
   if(upper_str == "FATAL") return LOG_FATAL;
   
   return LOG_INFO; // Default level
}

//+------------------------------------------------------------------+
//| Record number within the program                                 |
//+------------------------------------------------------------------+
ulong g_log_record_sequence = 0;

//+------------------------------------------------------------------+
//| Log record structure                                             |
//|                                                                  |
//| Время записи:                                                    |
//|   timestamp  — время торгового сервера (TimeCurrent): время      |
//|                последнего тика, в тестере — время модели;        |
//|   time_local — часы компьютера (в тестере равны timestamp);      |
//|   elapsed_us — микросекунды от запуска программы: промежутки     |
//|                между записями меряются по нему;                  |
//|   sequence   — номер записи в программе, с 1.                    |
//+------------------------------------------------------------------+
struct SLogRecord
{
   ENUM_LOG_LEVEL    level;           // Message level
   datetime          timestamp;       // Trade server time of the last tick (model time in the tester)
   string            logger_name;     // Logger name
   string            message;         // Message text
   string            source_file;     // Source file
   int               source_line;     // Source line
   string            function_name;   // Function name
   int               thread_id;       // Not used, always 0
   int               error_code;      // Error code (if any)
   datetime          time_local;      // Computer time
   ulong             elapsed_us;      // Microseconds since the program started
   ulong             sequence;        // Record number within the program

   // Empty record: not stamped, use CreateLogRecord() or the constructor below
   SLogRecord()
   {
      level = LOG_INFO;
      timestamp = 0;
      logger_name = "";
      message = "";
      source_file = "";
      source_line = 0;
      function_name = "";
      thread_id = 0;
      error_code = 0;
      time_local = 0;
      elapsed_us = 0;
      sequence = 0;
   }

   // Constructor with parameters: the record is stamped with the current time
   SLogRecord(ENUM_LOG_LEVEL lvl, string msg, string logger = "",
              string file = "", int line = 0, string func = "", int err = 0)
   {
      level = lvl;
      logger_name = logger;
      message = msg;
      source_file = file;
      source_line = line;
      function_name = func;
      thread_id = 0;
      error_code = err;
      timestamp = TimeCurrent();
      time_local = TimeLocal();
      elapsed_us = GetMicrosecondCount();
      sequence = ++g_log_record_sequence;
   }
};

//+------------------------------------------------------------------+
//| Stamp a record with the current time and the next number        |
//+------------------------------------------------------------------+
void LogStampRecord(SLogRecord &record)
{
   record.timestamp = TimeCurrent();
   record.time_local = TimeLocal();
   record.elapsed_us = GetMicrosecondCount();
   record.sequence = ++g_log_record_sequence;
}

//+------------------------------------------------------------------+
//| Helper function to create log records                           |
//+------------------------------------------------------------------+
SLogRecord CreateLogRecord(ENUM_LOG_LEVEL level, string message, string logger_name,
                          string file = "", int line = 0, string func = "", int error_code = 0)
{
   SLogRecord record;
   record.level = level;
   record.logger_name = logger_name;
   record.message = message;
   record.source_file = file;
   record.source_line = line;
   record.function_name = func;
   record.error_code = error_code;
   LogStampRecord(record);

   return record;
}

//+------------------------------------------------------------------+
//| Line used by handlers that have no formatter:                   |
//|   2026.10.07 07:28:27 [WARN] name: text [File.mq5:7:Fn] [Error: 5]|
//| Source and error parts appear only when they are set.           |
//+------------------------------------------------------------------+
string LogFormatDefault(const SLogRecord &record)
{
   string line = TimeToString(record.timestamp, TIME_DATE | TIME_SECONDS) +
                 " [" + LogLevelToString(record.level) + "] ";
   if(StringLen(record.logger_name) > 0)
      line += record.logger_name + ": ";
   line += record.message;
   if(StringLen(record.source_file) > 0)
      line += StringFormat(" [%s:%d:%s]", record.source_file, record.source_line, record.function_name);
   if(record.error_code != 0)
      line += StringFormat(" [Error: %d]", record.error_code);
   return line;
}
