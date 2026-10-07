//+------------------------------------------------------------------+
//|                                                  LoggerTests.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
//| Все тесты библиотеки одним скриптом. Запуск: скрипт, который    |
//| подключает этот файл, из папки Scripts терминала:               |
//|    #include <Logger\Tests\LoggerTests.mqh>                       |
//| Файлы тестов создаются в MQL5\Files с именами lgt_* и удаляются.|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"

#include "..\Logger.mqh"
#include "LogTestKit.mqh"
#include "Cases\TestCore.mqh"
#include "Cases\TestFile.mqh"
#include "Cases\TestSqlite.mqh"
#include "Cases\TestFormatters.mqh"
#include "Cases\TestFactory.mqh"
#include "Cases\TestMacros.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   LT.Begin("Logger " + LOGGER_VERSION_STRING);
   LtCleanup();
   TestCore();
   TestFile();
   TestSqlite();
   TestFormatters();
   TestFactory();
   TestMacros();
   CLoggerFactory::Shutdown();
   LtCleanup();
   LT.Finish();
}
