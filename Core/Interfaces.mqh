//+------------------------------------------------------------------+
//|                                                   Interfaces.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

#include "LogRecord.mqh"

//+------------------------------------------------------------------+
//| Logger interface                                                 |
//+------------------------------------------------------------------+
class ILogger
{
public:
   virtual void      Trace(string message) = 0;
   virtual void      Debug(string message) = 0;
   virtual void      Info(string message) = 0;
   virtual void      Warn(string message) = 0;
   virtual void      Error(string message, int error_code = 0) = 0;
   virtual void      Fatal(string message, int error_code = 0) = 0;
   
   // Main logging method with full source information
   virtual void      Log(ENUM_LOG_LEVEL level, string message, int error_code = 0, 
                        string file = "", int line = 0, string func = "") = 0;
   
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) = 0;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) = 0;
   virtual void      AddHandler(ILogHandler* handler) = 0;
   virtual void      RemoveHandler(ILogHandler* handler) = 0;
   virtual void      Flush() = 0;
   virtual string    Name() = 0;
};

//+------------------------------------------------------------------+
//| Log handler interface                                            |
//+------------------------------------------------------------------+
class ILogHandler
{
public:
   virtual bool      Handle(const SLogRecord &record) = 0;
   virtual void      SetFormatter(ILogFormatter* formatter) = 0;
   virtual void      SetFilter(ILogFilter* filter) = 0;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) = 0;
   virtual void      Flush() = 0;
   virtual void      Close() = 0;
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) = 0;
};

//+------------------------------------------------------------------+
//| Log formatter interface                                          |
//+------------------------------------------------------------------+
class ILogFormatter
{
public:
   virtual string    Format(const SLogRecord &record) = 0;
   virtual void      SetPattern(string pattern) = 0;
};

//+------------------------------------------------------------------+
//| Log filter interface                                             |
//+------------------------------------------------------------------+
class ILogFilter
{
public:
   virtual bool      ShouldLog(const SLogRecord &record) = 0;
};