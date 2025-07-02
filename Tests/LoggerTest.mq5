//+------------------------------------------------------------------+
//|                                                  LoggerTest.mq5 |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property script_show_inputs

//--- Include the logger system
#include <Logger\Logger.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== MQL5 Logger System Test ===");
   
   // Test basic logger creation
   TestBasicLogging();
   
   // Test different handlers
   TestHandlers();
   
   // Test formatters
   TestFormatters();
   
   // Test filters
   TestFilters();
   
   // Test macros
   TestMacros();

   // Test database handler
   TestDatabase();

   // Test detailed source information
   TestDetailedSourceInfo();
   
   // Test function tracing
   TestFunctionTracing();
   
   // Test performance timing
   TestPerformanceTiming();

   // Test detailed database logging
   TestDetailedDatabaseLogging();
   
   // Test database logging with macros
   TestDatabaseMacroLogging();
   
   // Test composite detailed logging
   TestCompositeDetailedLogging();
   
   Print("=== Test completed ===");
}

//+------------------------------------------------------------------+
//| Test basic logging functionality                                |
//+------------------------------------------------------------------+
void TestBasicLogging()
{
   Print("--- Testing basic logging ---");
   
   // Get default logger
   ILogger* logger = GetLogger();
   if(logger == NULL)
   {
      Print("ERROR: Failed to create default logger");
      return;
   }
   
   // Test different log levels
   logger.Trace("This is a TRACE message");
   logger.Debug("This is a DEBUG message"); 
   logger.Info("This is an INFO message");
   logger.Warn("This is a WARN message");
   logger.Error("This is an ERROR message", 12345);
   logger.Fatal("This is a FATAL message", 67890);
   
   Print("Basic logging test completed");
}

//+------------------------------------------------------------------+
//| Test different handlers                                          |
//+------------------------------------------------------------------+
void TestHandlers()
{
   Print("--- Testing handlers ---");
   
   // Create console logger - используем числовое значение
   ILogger* console_logger = CLoggerFactory::CreateConsoleLogger("console_test", (ENUM_LOG_LEVEL)1); // LOG_DEBUG = 1
   if(console_logger != NULL)
   {
      console_logger.Info("Console handler test message");
   }
   
   // Create file logger - используем числовое значение
   ILogger* file_logger = CLoggerFactory::CreateFileLogger("file_test", "test_log.txt", (ENUM_LOG_LEVEL)2); // LOG_INFO = 2
   if(file_logger != NULL)
   {
      file_logger.Info("File handler test message");
      file_logger.Warn("File warning message");
      file_logger.Error("File error message");
   }
   
   Print("Handler testing completed");
}

//+------------------------------------------------------------------+
//| Test formatters                                                  |
//+------------------------------------------------------------------+
void TestFormatters()
{
   Print("--- Testing formatters ---");
   
   // Create logger with simple formatter
   ILogger* simple_logger = CLoggerFactory::CreateLogger("simple_format");
   if(simple_logger != NULL)
   {
      CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
      CSimpleFormatter* formatter = CLoggerFactory::CreateSimpleFormatter("%timestamp% [%level%] %message%");
      
      if(handler != NULL && formatter != NULL)
      {
         handler.SetFormatter(formatter);
         simple_logger.AddHandler(handler);
         simple_logger.Info("Simple formatter test");
      }
   }
   
   // Create logger with detailed formatter
   ILogger* detailed_logger = CLoggerFactory::CreateLogger("detailed_format");
   if(detailed_logger != NULL)
   {
      CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
      CDetailedFormatter* formatter = CLoggerFactory::CreateDetailedFormatter("", false);
      
      if(handler != NULL && formatter != NULL)
      {
         handler.SetFormatter(formatter);
         detailed_logger.AddHandler(handler);
         detailed_logger.Info("Detailed formatter test");
      }
   }
   
   Print("Formatter testing completed");
}

//+------------------------------------------------------------------+
//| Test filters                                                     |
//+------------------------------------------------------------------+
void TestFilters()
{
   Print("--- Testing filters ---");
   
   // Create logger with level filter
   ILogger* filtered_logger = CLoggerFactory::CreateLogger("filtered");
   if(filtered_logger != NULL)
   {
      CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
      CLevelFilter* filter = CLoggerFactory::CreateLevelFilter((ENUM_LOG_LEVEL)3); // LOG_WARN = 3
      
      if(handler != NULL && filter != NULL)
      {
         handler.SetFilter(filter);
         filtered_logger.AddHandler(handler);
         
         // These should not appear (below WARN level)
         filtered_logger.Debug("Debug message - should NOT appear");
         filtered_logger.Info("Info message - should NOT appear");
         
         // These should appear (WARN level and above)
         filtered_logger.Warn("Warning message - should appear");
         filtered_logger.Error("Error message - should appear");
      }
   }
   
   Print("Filter testing completed");
}

//+------------------------------------------------------------------+
//| Test logging macros                                             |
//+------------------------------------------------------------------+
void TestMacros()
{
   Print("--- Testing macros ---");
   
   // Test basic macros
   LOGTRACE("Trace macro test");
   LOGDEBUG("Debug macro test");
   LOGINFO("Info macro test");
   LOGWARN("Warning macro test");
   LOGERROR("Error macro test");
   LOGFATAL("Fatal macro test");
   
   // Test named logger macros
   LOGINFO_N("test_logger", "Named logger macro test");
   
   // Test backward compatibility
   //LOG_INFO_MSG("Backward compatibility test");
   
   Print("Macro testing completed");
}

//+------------------------------------------------------------------+
//| Test database handler                                            |
//+------------------------------------------------------------------+
void TestDatabase()
{
   Print("--- Testing database handler ---");
   
   // Create database logger
   ILogger* db_logger = CLoggerFactory::CreateDatabaseLogger("db_test", "test_logs.db", (ENUM_LOG_LEVEL)2); // LOG_INFO
   if(db_logger != NULL)
   {
      db_logger.Info("Database handler test message");
      db_logger.Warn("Database warning message");
      db_logger.Error("Database error message", 404);
      db_logger.Fatal("Database fatal message", 500);
      
      // Force flush to ensure data is written
      db_logger.Flush();
      
      Print("Database logging completed - check test_logs.db file");
   }
   else
   {
      Print("ERROR: Failed to create database logger");
   }
   
   // Test composite logger (console + database)
   ILogger* composite_logger = CLoggerFactory::CreateCompositeLogger("composite_test", true, "", "composite_test.db");
   if(composite_logger != NULL)
   {
      composite_logger.Info("Composite logger test - should appear in console and database");
      composite_logger.Flush();
   }
   
   Print("Database testing completed");
}

//+------------------------------------------------------------------+
//| Test detailed source information logging                        |
//+------------------------------------------------------------------+
void TestDetailedSourceInfo()
{
   Print("--- Testing detailed source information ---");
   
   // Create logger with detailed formatter showing source info
   ILogger* detailed_logger = CLoggerFactory::CreateLogger("source_info_test");
   if(detailed_logger != NULL)
   {
      CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
      CDetailedFormatter* formatter = CLoggerFactory::CreateDetailedFormatter("", false); // single-line format
      
      if(handler != NULL && formatter != NULL)
      {
         // Enable all detailed information
         formatter.SetShowSourceInfo(true);
         formatter.SetShowErrorInfo(true);
         
         handler.SetFormatter(formatter);
         detailed_logger.AddHandler(handler);
         
         // Test direct Log method with source info
         detailed_logger.Log((ENUM_LOG_LEVEL)2, "Direct log call with source info", 0, __FILE__, __LINE__, __FUNCTION__);
         detailed_logger.Log((ENUM_LOG_LEVEL)4, "Error with source and error code", 12345, __FILE__, __LINE__, __FUNCTION__);
      }
   }
   
   // Test multiline detailed format
   ILogger* multiline_logger = CLoggerFactory::CreateLogger("multiline_test");
   if(multiline_logger != NULL)
   {
      CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
      CDetailedFormatter* formatter = CLoggerFactory::CreateDetailedFormatter("", true); // multiline format
      
      if(handler != NULL && formatter != NULL)
      {
         formatter.SetShowSourceInfo(true);
         formatter.SetShowErrorInfo(true);
         
         handler.SetFormatter(formatter);
         multiline_logger.AddHandler(handler);
         
         multiline_logger.Log((ENUM_LOG_LEVEL)3, "Multiline format test message", 999, __FILE__, __LINE__, __FUNCTION__);
      }
   }
   
   // Test macros (they automatically include source info)
   Print("Testing macros with automatic source info:");
   LOGINFO("Macro with automatic source info");
   LOGERROR_CODE("Macro error with code", 777);
   
   Print("Detailed source information testing completed");
}

//+------------------------------------------------------------------+
//| Helper function to test function entry/exit logging            |
//+------------------------------------------------------------------+
void TestFunctionTracing()
{
   Print("--- Testing function tracing ---");
   
   // Set logger to TRACE level to see entry/exit
   ILogger* trace_logger = CLoggerFactory::CreateConsoleLogger("trace_test", (ENUM_LOG_LEVEL)0); // LOG_TRACE
   if(trace_logger != NULL)
   {
      // Temporarily set as default for macros
      // Note: This is a simplified test - in real usage you'd configure the default logger
   }
   
   // Test function entry/exit macros
   LOGFUNCTION_ENTRY();
   
   // Simulate some work
   Sleep(10);
   LOGINFO("Doing some work inside TestFunctionTracing");
   
   LOGFUNCTION_EXIT();
   
   Print("Function tracing testing completed");
}

//+------------------------------------------------------------------+
//| Test performance timing macro                                   |
//+------------------------------------------------------------------+
void TestPerformanceTiming()
{
   Print("--- Testing performance timing ---");
   
   // Test execution time macro
   LOGEXECUTION_TIME("Performance test operation", {
      // Simulate some work
      for(int i = 0; i < 1000; i++)
      {
         MathSin(i * 0.01);
      }
      Sleep(50); // Add some delay to see timing
   });
   
   Print("Performance timing testing completed");
}

//+------------------------------------------------------------------+
//| Test detailed database logging with source information         |
//+------------------------------------------------------------------+
void TestDetailedDatabaseLogging()
{
   Print("--- Testing detailed database logging ---");
   
   // Create database logger for detailed info
   ILogger* detailed_db_logger = CLoggerFactory::CreateDatabaseLogger("detailed_db_test", "detailed_logs.db", (ENUM_LOG_LEVEL)0); // LOG_TRACE
   
   if(detailed_db_logger != NULL)
   {
      Print("Testing detailed database logging with source information...");
      
      // Test all log levels with source information
      detailed_db_logger.Log((ENUM_LOG_LEVEL)0, "TRACE: Database trace message with source info", 0, __FILE__, __LINE__, __FUNCTION__);
      detailed_db_logger.Log((ENUM_LOG_LEVEL)1, "DEBUG: Database debug message with source info", 0, __FILE__, __LINE__, __FUNCTION__);
      detailed_db_logger.Log((ENUM_LOG_LEVEL)2, "INFO: Database info message with source info", 0, __FILE__, __LINE__, __FUNCTION__);
      detailed_db_logger.Log((ENUM_LOG_LEVEL)3, "WARN: Database warning with source info", 0, __FILE__, __LINE__, __FUNCTION__);
      detailed_db_logger.Log((ENUM_LOG_LEVEL)4, "ERROR: Database error with source and error code", 404, __FILE__, __LINE__, __FUNCTION__);
      detailed_db_logger.Log((ENUM_LOG_LEVEL)5, "FATAL: Database fatal error with source and error code", 500, __FILE__, __LINE__, __FUNCTION__);
      
      // Test with different error codes
      detailed_db_logger.Log((ENUM_LOG_LEVEL)4, "Network connection failed", 10060, __FILE__, __LINE__, __FUNCTION__);
      detailed_db_logger.Log((ENUM_LOG_LEVEL)4, "File not found", 2, __FILE__, __LINE__, __FUNCTION__);
      detailed_db_logger.Log((ENUM_LOG_LEVEL)3, "Low disk space warning", 0, __FILE__, __LINE__, __FUNCTION__);
      
      // Force flush to ensure all data is written to database
      detailed_db_logger.Flush();
      
      Print("Detailed database logging completed - check detailed_logs.db");
      Print("Database should contain: timestamp, level, logger_name, message, source_file, source_line, function_name, error_code");
   }
   else
   {
      Print("ERROR: Failed to create detailed database logger");
   }
}

//+------------------------------------------------------------------+
//| Test database logging with macros (automatic source info)     |
//+------------------------------------------------------------------+
void TestDatabaseMacroLogging()
{
   Print("--- Testing database logging with macros ---");
   
   // Create database logger for macro testing
   ILogger* macro_db_logger = CLoggerFactory::CreateDatabaseLogger("macro_db_test", "macro_logs.db", (ENUM_LOG_LEVEL)1); // LOG_DEBUG
   
   if(macro_db_logger != NULL)
   {
      // Temporarily make this logger the default for macros testing
      // Note: In real implementation, you might want to configure the factory's default logger
      
      Print("Testing database logging with macros (source info included automatically)...");
      
      // These will use the default logger, but we can test the concept
      // by calling the database logger directly with macro-like calls
      macro_db_logger.Log((ENUM_LOG_LEVEL)1, "DEBUG macro test in database", 0, __FILE__, __LINE__, __FUNCTION__);
      macro_db_logger.Log((ENUM_LOG_LEVEL)2, "INFO macro test in database", 0, __FILE__, __LINE__, __FUNCTION__);
      macro_db_logger.Log((ENUM_LOG_LEVEL)3, "WARN macro test in database", 0, __FILE__, __LINE__, __FUNCTION__);
      macro_db_logger.Log((ENUM_LOG_LEVEL)4, "ERROR macro test in database", GetLastError(), __FILE__, __LINE__, __FUNCTION__);
      
      // Simulate some trading-related logs
      macro_db_logger.Log((ENUM_LOG_LEVEL)2, "Trade opened: EURUSD BUY 0.10 lots at 1.1234", 0, __FILE__, __LINE__, __FUNCTION__);
      macro_db_logger.Log((ENUM_LOG_LEVEL)2, "Trade closed: EURUSD 0.10 lots at 1.1245, profit: 11.00", 0, __FILE__, __LINE__, __FUNCTION__);
      macro_db_logger.Log((ENUM_LOG_LEVEL)4, "Order failed: insufficient margin", 134, __FILE__, __LINE__, __FUNCTION__);
      
      macro_db_logger.Flush();
      
      Print("Database macro logging completed - check macro_logs.db");
   }
   else
   {
      Print("ERROR: Failed to create macro database logger");
   }
}

//+------------------------------------------------------------------+
//| Test composite logging (console + database) with details      |
//+------------------------------------------------------------------+
void TestCompositeDetailedLogging()
{
   Print("--- Testing composite detailed logging ---");
   
   // Create composite logger with both console and database output
   ILogger* composite_logger = CLoggerFactory::CreateCompositeLogger("composite_detailed", true, "", "composite_detailed.db");
   
   if(composite_logger != NULL)
   {
      Print("Testing composite logging (console + database) with detailed information...");
      
      // These messages should appear both in console and database
      composite_logger.Log((ENUM_LOG_LEVEL)2, "Composite: Application started", 0, __FILE__, __LINE__, __FUNCTION__);
      composite_logger.Log((ENUM_LOG_LEVEL)2, "Composite: Configuration loaded successfully", 0, __FILE__, __LINE__, __FUNCTION__);
      composite_logger.Log((ENUM_LOG_LEVEL)3, "Composite: Warning - high CPU usage detected", 0, __FILE__, __LINE__, __FUNCTION__);
      composite_logger.Log((ENUM_LOG_LEVEL)4, "Composite: Error - connection timeout", 10060, __FILE__, __LINE__, __FUNCTION__);
      composite_logger.Log((ENUM_LOG_LEVEL)2, "Composite: Application shutting down", 0, __FILE__, __LINE__, __FUNCTION__);
      
      composite_logger.Flush();
      
      Print("Composite detailed logging completed");
      Print("Check console output above and composite_detailed.db file");
   }
   else
   {
      Print("ERROR: Failed to create composite detailed logger");
   }
}
