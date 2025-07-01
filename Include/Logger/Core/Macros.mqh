//+------------------------------------------------------------------+
//|                                                       Macros.mqh |
//|                                  Professional MQL5 Logger System |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Professional MQL5 Logger System"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Convenience macros for logging with source information          |
//+------------------------------------------------------------------+

// Get default logger
#define GET_LOGGER() CLoggerFactory::GetLogger("default")

// Basic logging macros with source tracing
#define LOG_TRACE(message) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_TRACE, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_DEBUG(message) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_DEBUG, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_INFO(message) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_INFO, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_WARN(message) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_WARN, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_ERROR(message) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_ERROR, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_ERROR_CODE(message, error_code) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_ERROR, message, error_code, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_FATAL(message) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_FATAL, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_FATAL_CODE(message, error_code) \
   do { \
      ILogger* logger = GET_LOGGER(); \
      if(logger != NULL) \
         logger.Log(LOG_FATAL, message, error_code, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

// Named logger macros
#define LOG_TRACE_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log(LOG_TRACE, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_DEBUG_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log(LOG_DEBUG, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_INFO_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log(LOG_INFO, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_WARN_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log(LOG_WARN, message, 0, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_ERROR_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log(LOG_ERROR, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

#define LOG_FATAL_N(logger_name, message) \
   do { \
      ILogger* logger = CLoggerFactory::GetLogger(logger_name); \
      if(logger != NULL) \
         logger.Log(LOG_FATAL, message, GetLastError(), __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

// Conditional logging macros (only log if condition is true)
#define LOG_IF(condition, level, message) \
   do { \
      if(condition) { \
         ILogger* logger = GET_LOGGER(); \
         if(logger != NULL) \
            logger.Log(level, message, 0, __FILE__, __LINE__, __FUNCTION__); \
      } \
   } while(0)

// Performance timing macro
#define LOG_EXECUTION_TIME(message, code_block) \
   do { \
      uint start_time = GetTickCount(); \
      code_block; \
      uint duration = GetTickCount() - start_time; \
      string timing_msg = StringFormat("%s [Duration: %d ms]", message, duration); \
      LOG_DEBUG(timing_msg); \
   } while(0)

// Entry/Exit logging macros
#define LOG_FUNCTION_ENTRY() LOG_TRACE("Function entry: " + __FUNCTION__)
#define LOG_FUNCTION_EXIT()  LOG_TRACE("Function exit: " + __FUNCTION__)

// Trade-specific logging macros
#define LOG_TRADE_OPEN(symbol, type, volume, price) \
   do { \
      string trade_msg = StringFormat("Trade opened: %s %s %.2f lots at %.5f", \
                                     symbol, EnumToString(type), volume, price); \
      LOG_INFO(trade_msg); \
   } while(0)

#define LOG_TRADE_CLOSE(symbol, volume, price, profit) \
   do { \
      string trade_msg = StringFormat("Trade closed: %s %.2f lots at %.5f, profit: %.2f", \
                                     symbol, volume, price, profit); \
      LOG_INFO(trade_msg); \
   } while(0)
