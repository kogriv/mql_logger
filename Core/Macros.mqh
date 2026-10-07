//+------------------------------------------------------------------+
//|                                                       Macros.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Convenience macros for logging with source information          |
//|                                                                  |
//| Все макросы сначала проверяют уровень и только потом вычисляют  |
//| сообщение: выключенный вызов стоит одной проверки, строка       |
//| (StringFormat и т. п.) не строится.                             |
//|                                                                  |
//|   LOGINFO(msg)            логгер "default"                      |
//|   LOGINFO_N("name", msg)  логгер по имени (поиск на каждый вызов)|
//|   LOGINFO_TO(ptr, msg)    указатель на логгер; NULL — ничего    |
//+------------------------------------------------------------------+

// Общая часть. Имена внутренних переменных не должны встречаться у вызывающего.
#define LOGGER_WRITE(logger_ptr, level, message, error_code) \
   do { \
      ILogger* _lg_logger_ = (logger_ptr); \
      if(_lg_logger_ != NULL && _lg_logger_.IsEnabled(level)) \
         _lg_logger_.Log(level, message, error_code, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

// То же с кодом последней ошибки: он читается первым, до любых действий логгера
#define LOGGER_WRITE_LAST_ERROR(logger_ptr, level, message) \
   do { \
      int _lg_error_ = GetLastError(); \
      ILogger* _lg_logger_ = (logger_ptr); \
      if(_lg_logger_ != NULL && _lg_logger_.IsEnabled(level)) \
         _lg_logger_.Log(level, message, _lg_error_, __FILE__, __LINE__, __FUNCTION__); \
   } while(0)

// Logger given by pointer (ILogger* or CLogger*); a NULL pointer is allowed
#define LOGTRACE_TO(logger_ptr, message)  LOGGER_WRITE(logger_ptr, LOG_TRACE, message, 0)
#define LOGDEBUG_TO(logger_ptr, message)  LOGGER_WRITE(logger_ptr, LOG_DEBUG, message, 0)
#define LOGINFO_TO(logger_ptr, message)   LOGGER_WRITE(logger_ptr, LOG_INFO, message, 0)
#define LOGWARN_TO(logger_ptr, message)   LOGGER_WRITE(logger_ptr, LOG_WARN, message, 0)
#define LOGERROR_TO(logger_ptr, message)  LOGGER_WRITE_LAST_ERROR(logger_ptr, LOG_ERROR, message)
#define LOGFATAL_TO(logger_ptr, message)  LOGGER_WRITE_LAST_ERROR(logger_ptr, LOG_FATAL, message)
#define LOGERROR_CODE_TO(logger_ptr, message, error_code)  LOGGER_WRITE(logger_ptr, LOG_ERROR, message, error_code)
#define LOGFATAL_CODE_TO(logger_ptr, message, error_code)  LOGGER_WRITE(logger_ptr, LOG_FATAL, message, error_code)

// Logger "default" (kept by the factory, no lookup by name)
#define LOGTRACE(message)  LOGTRACE_TO(CLoggerFactory::Default(), message)
#define LOGDEBUG(message)  LOGDEBUG_TO(CLoggerFactory::Default(), message)
#define LOGINFO(message)   LOGINFO_TO(CLoggerFactory::Default(), message)
#define LOGWARN(message)   LOGWARN_TO(CLoggerFactory::Default(), message)
#define LOGERROR(message)  LOGERROR_TO(CLoggerFactory::Default(), message)
#define LOGFATAL(message)  LOGFATAL_TO(CLoggerFactory::Default(), message)
#define LOGERROR_CODE(message, error_code)  LOGERROR_CODE_TO(CLoggerFactory::Default(), message, error_code)
#define LOGFATAL_CODE(message, error_code)  LOGFATAL_CODE_TO(CLoggerFactory::Default(), message, error_code)

// Named logger (found by name on every call - keep a pointer and use ..._TO in hot code)
#define LOGTRACE_N(logger_name, message)  LOGTRACE_TO(CLoggerFactory::GetLogger(logger_name), message)
#define LOGDEBUG_N(logger_name, message)  LOGDEBUG_TO(CLoggerFactory::GetLogger(logger_name), message)
#define LOGINFO_N(logger_name, message)   LOGINFO_TO(CLoggerFactory::GetLogger(logger_name), message)
#define LOGWARN_N(logger_name, message)   LOGWARN_TO(CLoggerFactory::GetLogger(logger_name), message)
#define LOGERROR_N(logger_name, message)  LOGERROR_TO(CLoggerFactory::GetLogger(logger_name), message)
#define LOGFATAL_N(logger_name, message)  LOGFATAL_TO(CLoggerFactory::GetLogger(logger_name), message)

// Conditional logging to the default logger: LOGIF(spread > 30, LOG_WARN, "wide spread")
#define LOGIF(condition, level, message) \
   do { \
      if(condition) \
         LOGGER_WRITE(CLoggerFactory::Default(), level, message, 0); \
   } while(0)

// Performance timing: runs code_block, logs its duration at DEBUG level
#define LOGEXECUTION_TIME(message, code_block) \
   do { \
      ulong _lg_started_ = GetMicrosecondCount(); \
      code_block; \
      ulong _lg_elapsed_ = GetMicrosecondCount() - _lg_started_; \
      LOGDEBUG(StringFormat("%s [Duration: %.3f ms]", message, _lg_elapsed_ / 1000.0)); \
   } while(0)

// Entry/Exit logging macros
#define LOGFUNCTION_ENTRY() LOGTRACE("Function entry: " + __FUNCTION__)
#define LOGFUNCTION_EXIT()  LOGTRACE("Function exit: " + __FUNCTION__)

// Trade-specific logging macros
#define LOGTRADE_OPEN(symbol, type, volume, price) \
   LOGINFO(StringFormat("Trade opened: %s %s %.2f lots at %.5f", symbol, EnumToString(type), volume, price))

#define LOGTRADE_CLOSE(symbol, volume, price, profit) \
   LOGINFO(StringFormat("Trade closed: %s %.2f lots at %.5f, profit: %.2f", symbol, volume, price, profit))
