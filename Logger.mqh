//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Main include file for the logging system                        |
//| Include this file to get access to all logging functionality    |
//+------------------------------------------------------------------+

// Core components (БЕЗ макросов)
#include "Core\LogRecord.mqh"
#include "Core\Interfaces.mqh"
#include "Core\Logger.mqh"

// Handlers
#include "Handlers\ConsoleHandler.mqh"
#include "Handlers\FileHandler.mqh"
#include "Handlers\SqliteHandler.mqh"

// Formatters
#include "Formatters\SimpleFormatter.mqh"
#include "Formatters\DetailedFormatter.mqh"

// Filters
#include "Filters\LevelFilter.mqh"
#include "Filters\RegexFilter.mqh"

// Factory
#include "Factory\LoggerFactory.mqh"

// Макросы подключаем В САМОМ КОНЦЕ, когда все классы уже определены
#include "Core\Macros.mqh"

//+------------------------------------------------------------------+
//| Logger system version information                               |
//+------------------------------------------------------------------+
#define LOGGER_VERSION_MAJOR    1
#define LOGGER_VERSION_MINOR    0
#define LOGGER_VERSION_BUILD    0
#define LOGGER_VERSION_STRING   "1.0.0"

//+------------------------------------------------------------------+
//| Easy access functions                                            |
//+------------------------------------------------------------------+
ILogger* GetLogger(string name = "default")
{
   return CLoggerFactory::GetLogger(name);
}

void FlushAllLoggers()
{
   CLoggerFactory::FlushAll();
}

void ShutdownLogging()
{
   CLoggerFactory::Shutdown();
}