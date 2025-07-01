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
#include "Logger.mqh"

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
   
   // Create console logger
   ILogger* console_logger = CLoggerFactory::CreateConsoleLogger("console_test", LOG_DEBUG);
   if(console_logger != NULL)
   {
      console_logger.Info("Console handler test message");
   }
   
   // Create file logger
   ILogger* file_logger = CLoggerFactory::CreateFileLogger("file_test", "test_log.txt", LOG_INFO);
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
      CLevelFilter* filter = CLoggerFactory::CreateLevelFilter(LOG_WARN);
      
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
   LOG_TRACE("Trace macro test");
   LOG_DEBUG("Debug macro test");
   LOG_INFO("Info macro test");
   LOG_WARN("Warning macro test");
   LOG_ERROR("Error macro test");
   LOG_FATAL("Fatal macro test");
   
   // Test named logger macros
   LOG_INFO_N("test_logger", "Named logger macro test");
   
   Print("Macro testing completed");
}