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
// Create composite logger with both console and database output
ILogger* composite_logger = CLoggerFactory::CreateCompositeLogger("composite_detailed", true, "", "composite_detailed.db");

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== MQL5 Logger System Test ===");
   
   // Test composite detailed logging
   TestCompositeDetailedLogging();
   
   Print("=== Test completed ===");
}

//+------------------------------------------------------------------+
//| Test composite logging (console + database) with details      |
//+------------------------------------------------------------------+
void TestCompositeDetailedLogging()
{
   Print("--- Testing composite detailed logging ---");
   
   
   
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