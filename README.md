# Профессиональная система логирования для MQL5

Полнофункциональная система логирования для MetaTrader 5 с модульной архитектурой, множественными обработчиками и расширенными возможностями фильтрации.

## 🚀 Возможности

- **Модульная архитектура** - легкое добавление новых обработчиков и форматтеров
- **Множественные обработчики** - консоль, файлы, база данных SQLite
- **Гибкое форматирование** - простое и детальное форматирование сообщений
- **Продвинутая фильтрация** - по уровню логирования и регулярным выражениям
- **Thread-safety** - защита от конфликтов в псевдо-многопоточной среде MQL5
- **Фабрика логгеров** - централизованное управление и конфигурация
- **Удобные макросы** - быстрое логирование с автоматическим указанием источника

## 📁 Структура проекта

```
Logger.mqh                     // Главный файл подключения
├── Core/
│   ├── LogRecord.mqh          // Структура лог-записи и уровни
│   ├── Interfaces.mqh         // Интерфейсы системы
│   ├── Logger.mqh             // Основной класс логгера
│   └── Macros.mqh            // Макросы для быстрого логирования
├── Handlers/
│   ├── ConsoleHandler.mqh     // Вывод в терминал MetaTrader
│   ├── FileHandler.mqh        // Запись в файлы
│   └── SqliteHandler.mqh      // Запись в базу данных
├── Formatters/
│   ├── SimpleFormatter.mqh    // Простое форматирование
│   └── DetailedFormatter.mqh  // Детальное форматирование
├── Filters/
│   ├── LevelFilter.mqh        // Фильтрация по уровню
│   └── RegexFilter.mqh        // Фильтрация по содержимому
└── Factory/
    └── LoggerFactory.mqh      // Фабрика логгеров
```

## 🎯 Уровни логирования

```cpp
enum ENUM_LOG_LEVEL
{
   LOG_TRACE = 0,    // Детальная отладочная информация
   LOG_DEBUG = 1,    // Отладочная информация
   LOG_INFO = 2,     // Информационные сообщения
   LOG_WARN = 3,     // Предупреждения
   LOG_ERROR = 4,    // Ошибки
   LOG_FATAL = 5     // Критические ошибки
}
```

## 🛠 Быстрый старт

### 1. Базовое использование

```cpp
#include "Logger.mqh"

void OnStart()
{
   // Получить логгер по умолчанию
   ILogger* logger = GetLogger();
   
   // Логирование разных уровней
   logger.Info("Советник запущен");
   logger.Warn("Внимание: низкий баланс");
   logger.Error("Ошибка открытия позиции", GetLastError());
}
```

### 2. Использование макросов (рекомендуется)

```cpp
#include "Logger.mqh"

void OnTick()
{
   LOG_TRACE("Получен новый тик");
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   LOG_INFO("Текущая цена: " + DoubleToString(price, _Digits));
   
   if(price < 1.0000)
   {
      LOG_WARN("Цена ниже критического уровня!");
   }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   if(result.retcode != TRADE_RETCODE_DONE)
   {
      LOG_ERROR("Ошибка выполнения торговой операции");
   }
   else
   {
      LOG_INFO("Торговая операция выполнена успешно");
   }
}
```

## 📝 Примеры конфигурации

### 1. Логгер только для консоли

```cpp
void CreateConsoleLogger()
{
   // Создать логгер для вывода в консоль
   ILogger* logger = CLoggerFactory::CreateConsoleLogger("console", LOG_DEBUG);
   
   logger.Info("Сообщение в консоль");
   logger.Debug("Отладочное сообщение");
}
```

### 2. Логгер для записи в файл

```cpp
void CreateFileLogger()
{
   // Создать логгер для записи в файл
   ILogger* logger = CLoggerFactory::CreateFileLogger("trading", "trading.log", LOG_INFO);
   
   logger.Info("Запись в файл trading.log");
   logger.Warn("Предупреждение в файле");
   
   // Принудительно сохранить в файл
   logger.Flush();
}
```

### 3. Логгер с базой данных

```cpp
void CreateDatabaseLogger()
{
   // Создать логгер для записи в SQLite
   ILogger* logger = CLoggerFactory::CreateDatabaseLogger("db_logger", "logs.db", LOG_INFO);
   
   logger.Info("Запись в базу данных");
   logger.Error("Ошибка в базе данных", 123);
}
```

### 4. Композитный логгер (несколько обработчиков)

```cpp
void CreateCompositeLogger()
{
   // Создать логгер с выводом в консоль и файл
   ILogger* logger = CLoggerFactory::CreateCompositeLogger("multi", true, "app.log", "");
   
   logger.Info("Это сообщение появится и в консоли, и в файле");
}
```

## 🎨 Настройка форматирования

### 1. Простое форматирование

```cpp
void SetupSimpleFormatter()
{
   ILogger* logger = CLoggerFactory::CreateLogger("formatted");
   CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
   
   // Создать простой форматтер
   CSimpleFormatter* formatter = CLoggerFactory::CreateSimpleFormatter(
      "%timestamp% [%level%] %message%"
   );
   
   handler.SetFormatter(formatter);
   logger.AddHandler(handler);
   
   logger.Info("Сообщение с простым форматированием");
}
```

### 2. Детальное форматирование

```cpp
void SetupDetailedFormatter()
{
   ILogger* logger = CLoggerFactory::CreateLogger("detailed");
   CFileHandler* handler = CLoggerFactory::CreateFileHandler("detailed.log");
   
   // Создать детальный форматтер
   CDetailedFormatter* formatter = CLoggerFactory::CreateDetailedFormatter(
      "%timestamp% [%level%] %logger%: %message% %source_info% %error_info%",
      false  // не многострочный формат
   );
   
   handler.SetFormatter(formatter);
   logger.AddHandler(handler);
   
   logger.Info("Детально отформатированное сообщение");
}
```

### 3. Многострочное форматирование

```cpp
void SetupMultilineFormatter()
{
   ILogger* logger = CLoggerFactory::CreateLogger("multiline");
   CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
   
   // Создать многострочный форматтер
   CDetailedFormatter* formatter = CLoggerFactory::CreateDetailedFormatter("", true);
   
   handler.SetFormatter(formatter);
   logger.AddHandler(handler);
   
   logger.Error("Многострочное сообщение об ошибке", 404);
}
```

## 🔍 Фильтрация сообщений

### 1. Фильтрация по уровню

```cpp
void SetupLevelFilter()
{
   ILogger* logger = CLoggerFactory::CreateLogger("filtered");
   CConsoleHandler* handler = CLoggerFactory::CreateConsoleHandler();
   
   // Показывать только предупреждения и ошибки
   CLevelFilter* filter = CLoggerFactory::CreateLevelFilter(LOG_WARN);
   handler.SetFilter(filter);
   
   logger.AddHandler(handler);
   
   logger.Debug("Это сообщение НЕ появится");
   logger.Info("Это сообщение НЕ появится");
   logger.Warn("Это предупреждение ПОЯВИТСЯ");
   logger.Error("Эта ошибка ПОЯВИТСЯ");
}
```

### 2. Фильтрация по содержимому

```cpp
void SetupRegexFilter()
{
   ILogger* logger = CLoggerFactory::CreateLogger("regex_filtered");
   CFileHandler* handler = CLoggerFactory::CreateFileHandler("trades_only.log");
   
   // Записывать только сообщения о торговых операциях
   CRegexFilter* filter = CLoggerFactory::CreateRegexFilter(false); // без учета регистра
   filter.AddTradePatterns(); // добавить стандартные торговые паттерны
   filter.AddIncludePattern("ордер");
   filter.AddIncludePattern("позиция");
   
   handler.SetFilter(filter);
   logger.AddHandler(handler);
   
   logger.Info("Открыт ордер BUY"); // Запишется
   logger.Info("Закрыта позиция SELL"); // Запишется  
   logger.Info("Проверка соединения"); // НЕ запишется
}
```

## 📊 Продвинутые возможности

### 1. Настройка авто-сброса

```cpp
void SetupAutoFlush()
{
   ILogger* logger = CLoggerFactory::CreateLogger("auto_flush");
   
   // Автоматически сбрасывать буферы каждые 30 секунд
   logger.SetAutoFlushInterval(30);
   
   CFileHandler* handler = CLoggerFactory::CreateFileHandler("auto_flush.log", true, false);
   logger.AddHandler(handler);
   
   logger.Info("Это сообщение будет автоматически сохранено через 30 секунд");
}
```

### 2. Ротация файлов по размеру

```cpp
void SetupFileRotation()
{
   ILogger* logger = CLoggerFactory::CreateLogger("rotating");
   CFileHandler* handler = CLoggerFactory::CreateFileHandler("rotating.log");
   
   // Ротировать файл при достижении 1MB
   handler.SetMaxFileSize(1024 * 1024);
   
   logger.AddHandler(handler);
   
   for(int i = 0; i < 10000; i++)
   {
      logger.Info("Сообщение номер " + IntegerToString(i));
   }
}
```

### 3. Пакетная запись в базу данных

```cpp
void SetupBatchDatabase()
{
   CSqliteHandler* handler = CLoggerFactory::CreateSqliteHandler("batch.db", "logs");
   
   // Записывать в базу пакетами по 50 записей
   handler.SetBatchSize(50);
   handler.SetAutoCommit(false);
   
   ILogger* logger = CLoggerFactory::CreateLogger("batch");
   logger.AddHandler(handler);
   
   // Эти сообщения будут записаны одним пакетом
   for(int i = 0; i < 100; i++)
   {
      logger.Info("Пакетное сообщение " + IntegerToString(i));
   }
   
   logger.Flush(); // Принудительно записать оставшиеся
}
```

## 🎯 Специальные макросы

### 1. Макросы для торговых операций

```cpp
void TradeExample()
{
   string symbol = "EURUSD";
   double volume = 0.1;
   double price = 1.1234;
   double profit = 15.50;
   
   // Логирование открытия сделки
   LOG_TRADE_OPEN(symbol, ORDER_TYPE_BUY, volume, price);
   
   // Логирование закрытия сделки
   LOG_TRADE_CLOSE(symbol, volume, price, profit);
}
```

### 2. Макросы для отладки производительности

```cpp
void PerformanceExample()
{
   // Измерить время выполнения блока кода
   LOG_EXECUTION_TIME("Расчет индикаторов", {
      // Здесь ваш код для измерения
      for(int i = 0; i < 1000; i++)
      {
         MathSin(i * 0.01);
      }
   });
}
```

### 3. Макросы входа/выхода из функций

```cpp
void ExampleFunction()
{
   LOG_FUNCTION_ENTRY(); // Логировать вход в функцию
   
   // Ваш код функции
   Sleep(100);
   
   LOG_FUNCTION_EXIT();  // Логировать выход из функции
}
```

### 4. Условное логирование

```cpp
void ConditionalLogging()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Логировать только при низком балансе
   LOG_IF(balance < 1000, LOG_WARN, "Низкий баланс: " + DoubleToString(balance, 2));
}
```

## 🏭 Использование фабрики логгеров

### 1. Настройка конфигурации по умолчанию

```cpp
void SetupDefaultConfig()
{
   SLoggerConfig config;
   config.level = LOG_DEBUG;
   config.console_output = true;
   config.file_output = true;
   config.log_file = "default.log";
   config.detailed_format = true;
   config.auto_flush = false;
   config.flush_interval = 60;
   
   CLoggerFactory::SetDefaultConfig(config);
   
   // Теперь все новые логгеры будут использовать эту конфигурацию
   ILogger* logger = GetLogger("test");
}
```

### 2. Управление всеми логгерами

```cpp
void ManageAllLoggers()
{
   // Сбросить все буферы всех логгеров
   FlushAllLoggers();
   
   // Установить уровень для всех логгеров
   CLoggerFactory::SetGlobalLevel(LOG_WARN);
   
   // Включить/выключить все логгеры
   CLoggerFactory::EnableAll(false);
   
   // Узнать количество созданных логгеров
   int count = CLoggerFactory::GetLoggerCount();
   Print("Создано логгеров: " + IntegerToString(count));
   
   // Корректное завершение работы
   ShutdownLogging();
}
```

## 🛡 Thread Safety

Система автоматически обеспечивает thread-safety для MQL5:

```cpp
void MultiEventExample()
{
   // Эти вызовы из разных событий безопасны
   void OnTick()
   {
      LOG_INFO("Тик получен в OnTick");
   }
   
   void OnTimer()
   {
      LOG_INFO("Таймер сработал в OnTimer");
   }
   
   void OnTrade()
   {
      LOG_INFO("Торговое событие в OnTrade");
   }
}
```

## 📋 Полный пример в советнике

```cpp
//+------------------------------------------------------------------+
//|                                                   MyExpert.mq5 |
//+------------------------------------------------------------------+
#include "Logger.mqh"

input ENUM_LOG_LEVEL LogLevel = LOG_INFO;  // Уровень логирования

ILogger* g_logger = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Настроить логгер
   SLoggerConfig config;
   config.level = LogLevel;
   config.console_output = true;
   config.file_output = true;
   config.log_file = "MyExpert.log";
   config.detailed_format = true;
   
   g_logger = CLoggerFactory::CreateLogger("MyExpert", config);
   
   if(g_logger == NULL)
   {
      Print("Ошибка создания логгера");
      return INIT_FAILED;
   }
   
   LOG_INFO("Советник MyExpert инициализирован");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   LOG_EXECUTION_TIME("Обработка тика", {
      
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      LOG_DEBUG("Текущая цена: " + DoubleToString(price, _Digits));
      
      // Проверка условий для торговли
      if(ShouldOpenTrade())
      {
         if(OpenTrade())
         {
            LOG_INFO("Сделка открыта успешно");
         }
         else
         {
            LOG_ERROR("Ошибка открытия сделки");
         }
      }
   });
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LOG_INFO("Советник завершает работу. Причина: " + IntegerToString(reason));
   
   // Сохранить все логи
   FlushAllLoggers();
   
   // Корректно завершить работу логгера
   ShutdownLogging();
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   if(result.retcode == TRADE_RETCODE_DONE)
   {
      LOG_TRADE_OPEN(_Symbol, request.type, request.volume, result.price);
   }
   else
   {
      LOG_ERROR_CODE("Ошибка торговой операции", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Auxiliary functions                                              |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
   LOG_FUNCTION_ENTRY();
   
   // Ваша логика определения сигнала
   bool signal = true;
   
   LOG_IF(signal, LOG_DEBUG, "Сигнал для открытия сделки найден");
   
   LOG_FUNCTION_EXIT();
   return signal;
}

bool OpenTrade()
{
   LOG_FUNCTION_ENTRY();
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = 0.1;
   request.type = ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   bool success = OrderSend(request, result);
   
   if(success)
   {
      LOG_INFO("Запрос на открытие сделки отправлен");
   }
   else
   {
      LOG_ERROR("Ошибка отправки торгового запроса", GetLastError());
   }
   
   LOG_FUNCTION_EXIT();
   return success;
}
```

## 🔧 Установка и использование

1. Скопируйте файлы логгера в рабочую папку вашего MetaTrader 5
2. В вашем коде добавьте: `#include "Logger.mqh"`
3. Используйте макросы `LOG_INFO()`, `LOG_ERROR()` и другие для быстрого логирования
4. Или создайте настроенный логгер через `CLoggerFactory`

## 📚 Дополнительные возможности

- **Очистка старых записей**: `handler.ClearOldRecords(30)` - удалить записи старше 30 дней
- **Подсчет записей**: `handler.GetRecordCount()` - получить количество записей в БД
- **Настройка буферизации**: `handler.SetFlushInterval(120)` - сбрасывать каждые 2 минуты
- **Исключение уровней**: `filter.ExcludeLevel(LOG_DEBUG)` - исключить отладочные сообщения

---

**Автор**: kogriv  
**Версия**: 1.0.0  
**Совместимость**: MetaTrader 5, MQL5