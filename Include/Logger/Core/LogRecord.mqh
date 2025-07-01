//+------------------------------------------------------------------+
//|                                                    LogRecord.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

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
   string upper_str = StringUpper(level_str);
   
   if(upper_str == "TRACE") return LOG_TRACE;
   if(upper_str == "DEBUG") return LOG_DEBUG;
   if(upper_str == "INFO")  return LOG_INFO;
   if(upper_str == "WARN")  return LOG_WARN;
   if(upper_str == "ERROR") return LOG_ERROR;
   if(upper_str == "FATAL") return LOG_FATAL;
   
   return LOG_INFO; // Default level
}

//+------------------------------------------------------------------+
//| Log record structure                                             |
//+------------------------------------------------------------------+
struct SLogRecord
{
   ENUM_LOG_LEVEL    level;           // Message level
   datetime          timestamp;       // Creation time
   string            logger_name;     // Logger name
   string            message;         // Message text
   string            source_file;     // Source file
   int               source_line;     // Source line
   string            function_name;   // Function name
   int               thread_id;       // Thread ID (0 for MQL5)
   int               error_code;      // Error code (if any)
   
   // Constructor
   SLogRecord() : level(LOG_INFO), 
                  timestamp(TimeCurrent()), 
                  logger_name(""),
                  message(""),
                  source_file(""),
                  source_line(0),
                  function_name(""),
                  thread_id(0),
                  error_code(0) {}
                  
   // Constructor with parameters
   SLogRecord(ENUM_LOG_LEVEL lvl, string msg, string logger = "", 
              string file = "", int line = 0, string func = "", int err = 0) :
              level(lvl),
              timestamp(TimeCurrent()),
              logger_name(logger),
              message(msg),
              source_file(file),
              source_line(line),
              function_name(func),
              thread_id(0),
              error_code(err) {}
};

//+------------------------------------------------------------------+
//| Helper function to create log records                           |
//+------------------------------------------------------------------+
SLogRecord CreateLogRecord(ENUM_LOG_LEVEL level, string message, string logger_name,
                          string file = "", int line = 0, string func = "", int error_code = 0)
{
   SLogRecord record;
   record.level = level;
   record.timestamp = TimeCurrent();
   record.logger_name = logger_name;
   record.message = message;
   record.source_file = file;
   record.source_line = line;
   record.function_name = func;
   record.thread_id = 0; // MQL5 doesn't have real threads
   record.error_code = error_code;
   
   return record;
}
