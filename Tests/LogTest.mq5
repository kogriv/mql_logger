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

   // Test filters
   TestFilters();
   
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
   logger.SetLevel(LOG_WARN); // Только WARN, ERROR, FATAL будут выведены
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
      CLevelFilter* filter = CLoggerFactory::CreateLevelFilter(LOG_FATAL); // (ENUM_LOG_LEVEL)3 или LOG_WARN = 3
      
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
