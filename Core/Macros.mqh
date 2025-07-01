//+------------------------------------------------------------------+
//|                                                       Macros.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Convenience macros for logging with source information          |
//+------------------------------------------------------------------+

// Get default logger
// #define GET_LOGGER() CLoggerFactory::GetLogger("default")

// Basic logging macros with source tracing - используем числовые значения
#define LOGTRACE(message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)0, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGDEBUG(message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)1, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGINFO(message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)2, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGWARN(message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)3, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGERROR(message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)4, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGERROR_CODE(message, error_code) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)4, message, error_code, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGFATAL(message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)5, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGFATAL_CODE(message, error_code) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger("default"); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)5, message, error_code, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

// Named logger macros
#define LOGTRACE_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)0, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGDEBUG_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)1, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGINFO_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)2, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGWARN_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)3, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGERROR_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)4, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOGFATAL_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log((ENUM_LOG_LEVEL)5, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

// Conditional logging macros (only log if condition is true)
#define LOGIF(condition, level, message) \
   do { \
      if(condition) { \
         ILogger* logger = GET_LOGGER(); \
         if(logger != NULL) \
            logger.Log(level, message, 0, __FILE__, __LINE__, __FUNCTION__); \
      } \
   } while(0)

// Performance timing macro
#define LOGEXECUTION_TIME(message, code_block) \
   do { \
      uint start_time = GetTickCount(); \
      code_block; \
      uint duration = GetTickCount() - start_time; \
      string timing_msg = StringFormat("%s [Duration: %d ms]", message, duration); \
      LOGDEBUG(timing_msg); \
   } while(0)

// Entry/Exit logging macros
#define LOGFUNCTION_ENTRY() LOGTRACE("Function entry: " + __FUNCTION__)
#define LOGFUNCTION_EXIT()  LOGTRACE("Function exit: " + __FUNCTION__)

// Trade-specific logging macros
#define LOGTRADE_OPEN(symbol, type, volume, price) \
   do { \
      string trade_msg = StringFormat("Trade opened: %s %s %.2f lots at %.5f", \
                                     symbol, EnumToString(type), volume, price); \
      LOGINFO(trade_msg); \
   } while(0)

#define LOGTRADE_CLOSE(symbol, volume, price, profit) \
   do { \
      string trade_msg = StringFormat("Trade closed: %s %.2f lots at %.5f, profit: %.2f", \
                                     symbol, volume, price, profit); \
      LOGINFO(trade_msg); \
   } while(0)

// Backward compatibility aliases
#define LOG_TRACE(message) LOGTRACE(message)
#define LOG_DEBUG(message) LOGDEBUG(message)
#define LOG_INFO(message) LOGINFO(message)
#define LOG_WARN(message) LOGWARN(message)
#define LOG_ERROR(message) LOGERROR(message)
#define LOG_FATAL(message) LOGFATAL(message)
#define LOG_ERROR_CODE(message, error_code) LOGERROR_CODE(message, error_code)
#define LOG_FATAL_CODE(message, error_code) LOGFATAL_CODE(message, error_code)
#define LOG_TRACE_N(logger_name, message) LOGTRACE_N(logger_name, message)
#define LOG_DEBUG_N(logger_name, message) LOGDEBUG_N(logger_name, message)
#define LOG_INFO_N(logger_name, message) LOGINFO_N(logger_name, message)
#define LOG_WARN_N(logger_name, message) LOGWARN_N(logger_name, message)
#define LOG_ERROR_N(logger_name, message) LOGERROR_N(logger_name, message)
#define LOG_FATAL_N(logger_name, message) LOGFATAL_N(logger_name, message)
#define LOG_IF(condition, level, message) LOGIF(condition, level, message)
#define LOG_EXECUTION_TIME(message, code_block) LOGEXECUTION_TIME(message, code_block)
#define LOG_FUNCTION_ENTRY() LOGFUNCTION_ENTRY()
#define LOG_FUNCTION_EXIT() LOGFUNCTION_EXIT()
#define LOG_TRADE_OPEN(symbol, type, volume, price) LOGTRADE_OPEN(symbol, type, volume, price)
#define LOG_TRADE_CLOSE(symbol, volume, price, profit) LOGTRADE_CLOSE(symbol, volume, price, profit)