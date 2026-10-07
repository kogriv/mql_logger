//+------------------------------------------------------------------+
//|                                                   QuickStart.mq5 |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
//| Скрипт-пример: логгер по умолчанию, свой логгер с файлом и      |
//| базой, шаблон строки, фильтр. Файлы появятся в MQL5\Files:      |
//| quickstart.log, quickstart.db.                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include <Logger\Logger.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//| (тест библиотеки вызывает QuickStart() сам и определяет          |
//| LOGGER_EXAMPLE_NO_ENTRY, чтобы здесь не было второго OnStart)    |
//+------------------------------------------------------------------+
#ifndef LOGGER_EXAMPLE_NO_ENTRY
void OnStart()
{
   QuickStart();
}
#endif

//+------------------------------------------------------------------+
//| Пример                                                           |
//+------------------------------------------------------------------+
void QuickStart()
{
   //--- 1. Логгер по умолчанию: журнал терминала, уровень INFO
   LOGINFO("Скрипт запущен на " + _Symbol);
   LOGDEBUG("Не появится: уровень DEBUG ниже INFO");
   LOGWARN(StringFormat("Спред %d пунктов", (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));

   //--- 2. Свой логгер: журнал терминала + файл + база
   SLoggerConfig config;
   config.level = LOG_DEBUG;
   config.console_output = true;
   config.file_output = true;
   config.log_file = "quickstart.log";
   config.database_output = true;
   config.database_file = "quickstart.db";
   CLogger* logger = CLoggerFactory::CreateLogger("quickstart", config);
   if(logger == NULL)
      return;

   //--- 3. Запись через указатель: строка строится, только если уровень включён
   LOGDEBUG_TO(logger, StringFormat("Баланс %.2f", AccountInfoDouble(ACCOUNT_BALANCE)));
   LOGINFO_TO(logger, "Запись с местом вызова");
   if(!SymbolSelect("NO_SUCH_SYMBOL", true))
      LOGERROR_TO(logger, "Символ не выбран");          // код GetLastError() попадёт в запись
   ResetLastError();

   //--- 4. Свой вид строки и фильтр для отдельного обработчика
   CConsoleHandler* console = CLoggerFactory::CreateConsoleHandler();
   console.SetFormatter(CLoggerFactory::CreateSimpleFormatter("%elapsed% %level% %logger%: %message% %error_info%"));
   CSubstringFilter* filter = CLoggerFactory::CreateSubstringFilter(false);
   filter.AddExcludePattern("шум");
   console.SetFilter(filter);
   CLogger* custom = CLoggerFactory::CreateLogger("custom", LoggerConfigSilent());
   custom.AddHandler(console);
   custom.Info("Видно: своя строка с временем от запуска");
   custom.Info("Не видно: это шум");

   //--- 5. Завершение: сбросить буферы, закрыть файлы и базы
   ShutdownLogging();
}

//+------------------------------------------------------------------+
//| Конфигурация без обработчиков: их добавляем сами                 |
//+------------------------------------------------------------------+
SLoggerConfig LoggerConfigSilent()
{
   SLoggerConfig config;
   config.console_output = false;
   config.level = LOG_TRACE;
   return config;
}
