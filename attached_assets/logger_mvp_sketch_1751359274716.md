# Thread-safety в MQL5
Thread-safety = безопасность при многопоточном доступе. Когда несколько потоков одновременно обращаются к одному объекту без "поломки" данных.

Проблема без thread-safety:
```cpp
// Два потока одновременно:
Thread1: counter = 5; counter++; // ожидает 6
Thread2: counter = 5; counter++; // ожидает 6
// Результат: counter = 6 (а должно быть 7!)
```

В MQL5 ситуация особая:  
❌ Классического многопоточия НЕТ:  
- Один основной поток выполнения
- События обрабатываются последовательно
- Нет std::thread или подобного
- Нет синхронизации потоков (mutex, condition_variable и т.д.)

✅ НО есть псевдо-многопоточность:
- Асинхронные события (OnTimer, OnTrade, OnTick и т.д.)
```cpp
// Разные "потоки" событий:
OnTick()     // Тики цен
OnTimer()    // Таймеры  
OnTrade()    // Торговые события
OnChart()    // События графика
```
- Параллельные вызовы функций в разных контекстах

🤔 **Нужен ли thread-safety в MQL?**
Формально НЕТ - события обрабатываются последовательно.

НО практически ДА для:  
- Глобальных переменных между разными EA  
- Файлового ввода-вывода  
- Общих ресурсов (GlobalVariable)  

Простая реализация в MQL:
```cpp
class CThreadSafeLogger
{
private:
   static bool m_lock;
   
public:
   void Log(string msg)
   {
      if(m_lock) return; // Простая блокировка
      m_lock = true;
      
      // Логирование
      printf(msg);
      
      m_lock = false;
   }
};
```

**Вывод:** В MQL5 thread-safety нужен редко, но для логгера стоит предусмотреть базовую защиту от повторного входа.

### Thread ID в MQL5
В текущей реализации `thread_id = 0`, так как MQL5 не предоставляет 
API для получения ID потока. В будущем, если появится многопоточность, 
можно будет добавить соответствующую функцию.

# Требования и набросок архитектуры

## 🎯 Цели и принципы
**Основные цели:**
- **Модульность** - легкое добавление новых способов вывода
- **Расширяемость** - возможность -добавления функций без изменения существующего кода
- **Производительность** - минимальное влияние на торговые операции
- **Надежность** - отказоустойчивость при ошибках записи

**Принципы SOLID:**
- **Single Responsibility** - каждый класс отвечает за одну задачу
- **Open/Closed** - открыт для расширения, закрыт для модификации
- **Dependency Inversion** - зависимость от абстракций, не от конкретных классов

## 🏗️ Архитектурная диаграмма
```plaintext
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client Code   │───▶│     ILogger      │◄───│  LoggerFactory  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │     CLogger      │
                    └──────────────────┘
                              │
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
            ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
            │ ILogHandler │ │ILogFormatter│ │ ILogFilter  │
            └─────────────┘ └─────────────┘ └─────────────┘
                    │
        ┌───────────┼───────────┬───────────┐
        ▼           ▼           ▼           ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ConsoleHandler│ │ FileHandler │ │SqliteHandler│ │ PushHandler │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

## 📋 Компоненты системы
### 1. Основные интерфейсы
```cpp
//+------------------------------------------------------------------+
//| Уровни логирования                                               |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_TRACE = 0,    // Детальная отладочная информация
   LOG_DEBUG = 1,    // Отладочная информация
   LOG_INFO = 2,     // Информационные сообщения
   LOG_WARN = 3,     // Предупреждения
   LOG_ERROR = 4,    // Ошибки
   LOG_FATAL = 5     // Критические ошибки
};

//+------------------------------------------------------------------+
//| Структура лог-записи                                             |
//+------------------------------------------------------------------+
struct SLogRecord
{
   ENUM_LOG_LEVEL    level;           // Уровень сообщения
   datetime          timestamp;       // Время создания
   string            logger_name;     // Имя логгера
   string            message;         // Текст сообщения
   string            source_file;     // Файл источника
   int               source_line;     // Строка источника
   string            function_name;   // Имя функции
   int               thread_id;       // ID потока (для будущего Пока 0 для MQL5)
   int               error_code;      // Код ошибки (если есть)
};

//+------------------------------------------------------------------+
//| Интерфейс логгера                                                |
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
   // Основной метод с полной информацией о источнике
   virtual void      Log(ENUM_LOG_LEVEL level, string message, int error_code = 0, 
                        string file = "", int line = 0, string func = "") = 0;
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) = 0;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) = 0;
   virtual void      AddHandler(ILogHandler* handler) = 0;
   virtual void      RemoveHandler(ILogHandler* handler) = 0;
};

//+------------------------------------------------------------------+
//| Интерфейс обработчика логов                                      |
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
};

//+------------------------------------------------------------------+
//| Интерфейс форматтера                                             |
//+------------------------------------------------------------------+
class ILogFormatter
{
public:
   virtual string    Format(const SLogRecord &record) = 0;
   virtual void      SetPattern(string pattern) = 0;
};

//+------------------------------------------------------------------+
//| Интерфейс фильтра                                                |
//+------------------------------------------------------------------+
class ILogFilter
{
public:
   virtual bool      ShouldLog(const SLogRecord &record) = 0;
};
```

### 2. Основной класс логгера
```cpp
//+------------------------------------------------------------------+
//| Основной класс логгера                                           |
//+------------------------------------------------------------------+
class CLogger : public ILogger
{
private:
   string            m_name;              // Имя логгера
   ENUM_LOG_LEVEL    m_level;             // Минимальный уровень
   CArrayObj         m_handlers;          // Список обработчиков
   bool              m_enabled;           // Включен ли логгер
   static bool       m_global_lock;       // Глобальная блокировка
   
   void              CreateLogRecord(ENUM_LOG_LEVEL level, string message, 
                                   int error_code, string file, int line, string func,
                                   SLogRecord &record);
   bool              AcquireLock();
   void              ReleaseLock();

   datetime          m_last_flush_time;   // Время последнего сброса
   int               m_auto_flush_interval; // Интервал авто-сброса (сек)
   
   void              CheckAutoFlush();

public:
                     CLogger(string name);
                    ~CLogger();
   
   // Реализация ILogger
   virtual void      Trace(string message) override;
   virtual void      Debug(string message) override;
   virtual void      Info(string message) override;
   virtual void      Warn(string message) override;
   virtual void      Error(string message, int error_code = 0) override;
   virtual void      Fatal(string message, int error_code = 0) override;
   virtual void      Log(ENUM_LOG_LEVEL level, string message, int error_code = 0) override;
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) override;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override;
   virtual void      AddHandler(ILogHandler* handler) override;
   virtual void      RemoveHandler(ILogHandler* handler) override;
   
   // Дополнительные методы
   string            Name() const { return m_name; }
   void              Enable(bool enabled) { m_enabled = enabled; }
   bool              IsEnabled() const { return m_enabled; }
   void              Flush();
   void              SetAutoFlushInterval(int seconds) { m_auto_flush_interval = seconds; }
};

bool CLogger::m_global_lock = false;

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger(string name) : m_name(name), 
                                m_level(LOG_INFO), 
                                m_enabled(true)
{
   m_handlers.FreeMode(false); // Не удаляем объекты автоматически
}

void CLogger::CheckAutoFlush()
{
   if(m_auto_flush_interval > 0 && 
      TimeCurrent() - m_last_flush_time >= m_auto_flush_interval)
   {
      Flush();
      m_last_flush_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Основной метод логирования                                       |
//+------------------------------------------------------------------+
void CLogger::Log(ENUM_LOG_LEVEL level, string message, int error_code = 0)
{
   if(!m_enabled || !IsEnabled(level))
      return;
      
   if(!AcquireLock())
      return; // Избегаем рекурсии
   
   SLogRecord record;
   CreateLogRecord(level, message, error_code, record);
   
   // Отправляем во все обработчики
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      ILogHandler* handler = m_handlers.At(i);
      if(handler != NULL)
      {
         handler.Handle(record);
      }
   }
   // Проверяем необходимость автоматического сброса
   CheckAutoFlush();
   ReleaseLock();
}

//+------------------------------------------------------------------+
//| Создание записи лога                                             |
//+------------------------------------------------------------------+
void CLogger::CreateLogRecord(ENUM_LOG_LEVEL level, string message, 
                             int error_code, string file, int line, string func,
                             SLogRecord &record)
{
   record.level = level;
   record.timestamp = TimeCurrent();
   record.logger_name = m_name;
   record.message = message;
   record.error_code = error_code;
   record.source_file = file;        // Реальный источник!
   record.source_line = line;        // Реальная строка!
   record.function_name = func;      // Реальная функция!
   record.thread_id = 0;             // В MQL5 пока не актуально
}

void CLogger::Flush()
{
   if(!AcquireLock())
      return; // Защита от рекурсии
   
   // Вызываем Flush() у всех обработчиков
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      ILogHandler* handler = m_handlers.At(i);
      if(handler != NULL)
      {
         handler.Flush();
      }
   }
   
   ReleaseLock();
}

CLogger::~CLogger()
{
   // Принудительно сбрасываем все буферы перед уничтожением
   Flush();
   
   // Закрываем все обработчики
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      ILogHandler* handler = m_handlers.At(i);
      if(handler != NULL)
      {
         handler.Close();
      }
   }
}

```

### Управление буферизацией (Flush Management)

**Проблема:** Буферизованные обработчики (файлы, БД) могут потерять данные 
при аварийном завершении программы.

**Решение:** Централизованное управление сбросом буферов:

```cpp
class CLogger 
{
public:
   void Flush();                           // Ручной сброс всех буферов
   void SetAutoFlushInterval(int seconds); // Автоматический сброс
};

// Реализация
void CLogger::Flush()
{
   for(int i = 0; i < m_handlers.Total(); i++)
   {
      ILogHandler* handler = m_handlers.At(i);
      if(handler != NULL)
         handler.Flush();
   }
}
```
**Когда вызывается Flush:**
- Вручную: `logger.Flush()`
- Автоматически: каждые N секунд
- При завершении: в деструкторе логгера
- При критических ошибках: `LOG_FATAL` автоматически вызывает Flush


### 3. Обработчики (Handlers)
`Include\Logging\Handlers\ConsoleHandler.mqh`
```cpp
//+------------------------------------------------------------------+
//| Обработчик вывода в консоль                                      |
//+------------------------------------------------------------------+
class CConsoleHandler : public ILogHandler
{
private:
   ILogFormatter*    m_formatter;
   ILogFilter*       m_filter;
   ENUM_LOG_LEVEL    m_level;

public:
                     CConsoleHandler();
                    ~CConsoleHandler();
   
   virtual bool      Handle(const SLogRecord &record) override;
   virtual void      SetFormatter(ILogFormatter* formatter) override;
   virtual void      SetFilter(ILogFilter* filter) override;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override;
   virtual void      Flush() override;
   virtual void      Close() override;
};

//+------------------------------------------------------------------+
//| Обработка записи                                                 |
//+------------------------------------------------------------------+
bool CConsoleHandler::Handle(const SLogRecord &record)
{
   if(record.level < m_level)
      return true;
      
   if(m_filter != NULL && !m_filter.ShouldLog(record))
      return true;
   
   string formatted_message;
   if(m_formatter != NULL)
      formatted_message = m_formatter.Format(record);
   else
      formatted_message = record.message;
   
   // Выбираем функцию вывода в зависимости от уровня
   switch(record.level)
   {
      case LOG_ERROR:
      case LOG_FATAL:
         PrintFormat("ERROR: %s", formatted_message);
         break;
      case LOG_WARN:
         PrintFormat("WARN: %s", formatted_message);
         break;
      default:
         Print(formatted_message);
         break;
   }
   
   return true;
}
```
`Include\Logging\Handlers\FileHandler.mqh`
```cpp
//+------------------------------------------------------------------+
//| Обработчик записи в файл                                         |
//+------------------------------------------------------------------+
class CFileHandler : public ILogHandler
{
private:
   string            m_filename;
   int               m_file_handle;
   ILogFormatter*    m_formatter;
   ILogFilter*       m_filter;
   ENUM_LOG_LEVEL    m_level;
   bool              m_auto_flush;
   int               m_max_file_size;     // Максимальный размер файла (байт)
   int               m_backup_count;      // Количество backup файлов
   
   bool              OpenFile();
   void              CloseFile();
   bool              ShouldRotate();
   void              RotateFile();

public:
                     CFileHandler(string filename);
                    ~CFileHandler();
   
   virtual bool      Handle(const SLogRecord &record) override;
   virtual void      SetFormatter(ILogFormatter* formatter) override;
   virtual void      SetFilter(ILogFilter* filter) override;
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override;
   virtual void      Flush() override;
   virtual void      Close() override;
   
   // Специфичные методы
   void              SetAutoFlush(bool auto_flush) { m_auto_flush = auto_flush; }
   void              SetMaxFileSize(int size) { m_max_file_size = size; }
   void              SetBackupCount(int count) { m_backup_count = count; }
};

//+------------------------------------------------------------------+
//| Обработка записи в файл                                          |
//+------------------------------------------------------------------+
bool CFileHandler::Handle(const SLogRecord &record)
{
   if(record.level < m_level)
      return true;
      
   if(m_filter != NULL && !m_filter.ShouldLog(record))
      return true;
   
   if(m_file_handle == INVALID_HANDLE && !OpenFile())
      return false;
   
   // Проверяем необходимость ротации
   if(ShouldRotate())
      RotateFile();
   
   string formatted_message;
   if(m_formatter != NULL)
      formatted_message = m_formatter.Format(record);
   else
      formatted_message = record.message;
   
   // Записываем в файл
   uint bytes_written = FileWriteString(m_file_handle, formatted_message + "\n");
   
   if(m_auto_flush)
      FileFlush(m_file_handle);
   
   return bytes_written > 0;
}
```
`Include\Logging\Handlers\SqliteHandler.mqh`
```cpp
//+------------------------------------------------------------------+
//| Обработчик записи в SQLite                                       |
//+------------------------------------------------------------------+
class CSqliteHandler : public ILogHandler
{
private:
   string            m_database_path;
   int               m_db_handle;
   ILogFormatter*    m_formatter;
   ILogFilter*       m_filter;
   ENUM_LOG_LEVEL    m_level;
   string            m_table_name;
   bool              m_batch_mode;
   CArrayObj         m_batch_records;
   int               m_batch_size;
   
   bool              OpenDatabase();
   void              CloseDatabase();
   bool              CreateTable();
   bool              InsertRecord(const SLogRecord &record);
   void              FlushBatch();

public:
                     CSqliteHandler(string database_path, string table_name = "logs");
                    ~CSqliteHandler();
   
   virtual bool      Handle(const SLogRecord &record) override;
   virtual void      SetFormatter(ILogFormatter* formatter) override;
   virtual void      SetFilter(ILogFilter* filter) override;
// unfinished
```
#### Важность Flush для разных обработчиков:

**ConsoleHandler:**
- Flush не критичен (вывод мгновенный)
- Реализация: пустая функция

**FileHandler:**
- Flush критически важен (данные в буфере ОС)
- Реализация: `FileFlush(m_file_handle)`

**SqliteHandler:**
- Flush важен для пакетных операций
- Реализация: завершение транзакции + COMMIT

**Приоритет:**

**Высокий приоритет:**
- ✅ `CLogger.Flush()` вызывает `handler.Flush()` для всех
- ✅ Автоматический Flush в деструкторе

**Средний приоритет:**
- ⚠️ Периодический автоматический Flush
- ⚠️ Автоматический Flush при FATAL ошибках

**Пример использования:**
```cpp
// Критическая операция - принудительно сбрасываем буферы
LOG_ERROR(logger, "Критическая ошибка торговли", GetLastError());
logger.Flush(); // Гарантируем запись на диск

// Или автоматически каждые 30 секунд
logger.SetAutoFlushInterval(30);
```

### Правильное отслеживание источника вызова

**Проблема:** Макросы __FILE__, __LINE__, __FUNCTION__ в методе CreateLogRecord 
показывают место в Logger.mqh, а не реальный источник.  
В MQL5 __FILE__, __LINE__, __FUNCTION__ — это всё макросы времени компиляции.
Если вставлять их внутрь CreateLogRecord, а не из вызывающего кода,   они будут показывать всегда `Logger.mqh`, строка N, а не caller.

**Решение:** Сделать перегруженные Log(...) с __FILE__, __LINE__, __FUNCTION__ в вызывающем коде. Передавать информацию о источнике через параметры + макросы:

```cpp
// Расширенный метод Log
void Log(ENUM_LOG_LEVEL level, string message, int error_code, 
         string file, int line, string func);

// В Logger.mqh или отдельном Macros.mqh
#define LOG_TRACE(logger, msg) logger.Log(LOG_TRACE, msg, 0, __FILE__, __LINE__, __FUNCTION__)
#define LOG_DEBUG(logger, msg) logger.Log(LOG_DEBUG, msg, 0, __FILE__, __LINE__, __FUNCTION__)
#define LOG_INFO(logger, msg)  logger.Log(LOG_INFO, msg, 0, __FILE__, __LINE__, __FUNCTION__)
#define LOG_WARN(logger, msg)  logger.Log(LOG_WARN, msg, 0, __FILE__, __LINE__, __FUNCTION__)
#define LOG_ERROR(logger, msg, err) logger.Log(LOG_ERROR, msg, err, __FILE__, __LINE__, __FUNCTION__)
#define LOG_FATAL(logger, msg, err) logger.Log(LOG_FATAL, msg, err, __FILE__, __LINE__, __FUNCTION__)
```

**Пример использования:**
```cpp
// Старый способ (плохо):
logger.Info("Открыта позиция");  // Покажет Logger.mqh:123

// Новый способ (хорошо):
LOG_INFO(logger, "Открыта позиция");  // Покажет Expert.mq5:45
```

**Результат:** Точное указание места вызова в логах.

### Дублирование функциональности ILogFilter и SetLevel
Есть дублирование функциональности, но они работают на разных уровнях:
SetLevel - простая фильтрация:
```cpp
handler.SetLevel(LOG_WARN);
// Пропускает только: WARN, ERROR, FATAL
// Блокирует: TRACE, DEBUG, INFO
```
ILogFilter - сложная фильтрация:
```cpp
// Может делать то же самое:
class CLevelFilter : public ILogFilter
{
   bool ShouldLog(const SLogRecord &record) override
   {
      return record.level >= LOG_WARN; // То же что SetLevel!
   }
};
```

Вариант решения: SetLevel как синтаксический сахар
```cpp
class CBaseHandler : public ILogHandler
{
private:
   ILogFilter* m_filter;
   
public:
   void SetLevel(ENUM_LOG_LEVEL level) override
   {
      // Автоматически создаем LevelFilter
      if(m_filter != NULL) delete m_filter;
      m_filter = new CLevelFilter(level);
   }
   
   void SetFilter(ILogFilter* filter) override
   {
      if(m_filter != NULL) delete m_filter;
      m_filter = filter;
   }
};

```

Почему:

✅ SetLevel остается для простоты использования
✅ SetFilter для продвинутых случаев
✅ Внутри SetLevel автоматически создает LevelFilter
✅ Обратная совместимость

**Реализация:**
```cpp
void CBaseHandler::SetLevel(ENUM_LOG_LEVEL level)
{
   // Автоматически создаем LevelFilter
   SetFilter(new CLevelFilter(level));
}

void CBaseHandler::SetFilter(ILogFilter* filter)
{
   if(m_filter != NULL) delete m_filter;
   m_filter = filter;
}
```

**Использование:**
```cpp
// Простой случай
handler.SetLevel(LOG_WARN);

// Сложный случай  
handler.SetFilter(new CRegexFilter("ERROR.*trading"));

// Композитный фильтр
auto composite = new CCompositeFilter();
composite.SetLevel(LOG_INFO);
composite.SetCustomFilter(new CTimeFilter(start, end));
handler.SetFilter(composite);
```
Вывод: Оставляем оба, но SetLevel реализуем через SetFilter внутри.


# Описание архитектуры системы логирования для MQL5

## 🎯 Общая концепция
Представьте систему логирования как почтовую службу:

- **Логгер** = почтовое отделение (принимает письма)
- **Обработчики** (Handlers) = способы доставки (курьер, авиапочта, email)
- **Форматтеры** = оформление конверта (адрес, марки)
- **Фильтры** = сортировка почты (срочная, обычная, спам)

## 🏗️ Архитектурные паттерны
### 1. Strategy Pattern (Стратегия)
Используется для динамического выбора способа логирования (консоль, файл, база данных).
**Проблема:** Нужны разные способы вывода логов  
**Решение:** Каждый способ = отдельная стратегия  
```plaintext

┌─────────────┐    выбирает    ┌─────────────────┐
│   Logger    │ ──────────────▶ │   ILogHandler   │
└─────────────┘                └─────────────────┘
                                        △
                        ┌───────────────┼───────────────┐
                        │               │               │
                ┌───────────────┐ ┌─────────────┐ ┌─────────────┐
                │ConsoleHandler │ │ FileHandler │ │SqliteHandler│
                └───────────────┘ └─────────────┘ └─────────────┘
```

**Как работает:**

- Логгер не знает, КАК выводить сообщения
- Он просто передает сообщение всем подключенным обработчикам
- Каждый обработчик решает сам, что с сообщением делать

### 2. Factory Pattern (Фабрика)
Используется для создания объектов обработчиков (консоль, файл, база данных).
**Проблема:** Нужно создавать объекты разных типов  
**Решение:** Фабрика создает объекты нужного типа  
```plaintext

┌─────────────┐    создает    ┌─────────────────┐
│   Logger    │ ──────────────▶ │   ILogHandler   │
└─────────────┘                └─────────────────┘
                                        △
                        ┌───────────────┼───────────────┐
                        │               │               │
                ┌───────────────┐ ┌─────────────┐ ┌─────────────┐
                │ConsoleHandler │ │ FileHandler │ │SqliteHandler│
                └───────────────┘ └─────────────┘ └─────────────┘
```

**Как работает:**

- Логгер не знает, КАК создавать обработчики
- Он просто просит фабрику создать нужный обработчик
- Фабрика создает обработчик нужного типа

### 3. Chain of Responsibility (Цепочка обязанностей)
Используется для обработки логов несколькими обработчиками последовательно.
**Проблема:** Нужно обрабатывать логи разными способами
**Решение:** Обработчики образуют цепочку  
```plaintext
Сообщение проходит через цепочку обработчиков:

Сообщение → Handler1 → Handler2 → Handler3 → ...
              │          │          │
              ▼          ▼          ▼
           Console     File      SQLite
```
**Как работает:**
- Логгер отправляет сообщение первому обработчику
- Если обработчик не может обработать, передает следующему
- И так до последнего обработчика в цепочке
- Если ни один не обработал, сообщение игнорируется

### 4. Template Method (Шаблонный метод)
Используется для определения общего алгоритма логирования с возможностью переопределения шагов.
**Проблема:** Нужно иметь общий алгоритм логирования  
**Решение:** Определяем шаблонный метод в базовом классе
```plaintext
Все обработчики работают по одной схеме:

1. Проверить уровень сообщения
2. Применить фильтр
3. Отформатировать сообщение  
4. Вывести сообщение
5. Сбросить буферы (если нужно)
```
**Как работает:**
- Базовый класс определяет общий алгоритм
- Подклассы переопределяют только специфичные шаги
- Логгер вызывает общий метод, не зная деталей реализации

## 📊 Детальная схема работы
Жизненный цикл лог-сообщения:
```plaintext
┌─────────────────────────────────────────────────────────────────┐
│                    1. Создание сообщения                        │
│  logger.Info("Открыта позиция BUY EURUSD 0.1 lot");             │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                 2. Проверка уровня логгера                      │
│  if (LOG_INFO >= logger.GetLevel()) { продолжаем }              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                3. Создание SLogRecord                           │
│  record.level = LOG_INFO                                        │
│  record.timestamp = 2024-01-15 14:30:25                         │
│  record.message = "Открыта позиция..."                          │
│  record.logger_name = "TradingBot"                              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              4. Отправка всем обработчикам                      │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │ Console     │    │ File        │    │ SQLite      │          │
│  │ Handler     │    │ Handler     │    │ Handler     │          │
│  └─────────────┘    └─────────────┘    └─────────────┘          │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│           5. Каждый обработчик работает независимо              │
│                                                                 │
│  Console: Print("INFO: Открыта позиция...")                     │
│  File:    WriteToFile("2024-01-15 14:30:25 INFO ...")           │
│  SQLite:  INSERT INTO logs VALUES (...)                         │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Компоненты системы (подробно)

### 1. SLogRecord - структура данных
Это "паспорт" каждого сообщения:
```plaintext
┌─────────────────────────────────────────┐
│              SLogRecord                 │
├─────────────────────────────────────────┤
│ level: LOG_INFO                         │  ← Важность сообщения
│ timestamp: 2024-01-15 14:30:25          │  ← Когда произошло
│ logger_name: "TradingBot"               │  ← Кто отправил
│ message: "Открыта позиция BUY..."       │  ← Что случилось
│ source_file: "Expert.mq5"               │  ← В каком файле
│ source_line: 145                        │  ← На какой строке
│ function_name: "OpenPosition"           │  ← В какой функции
│ error_code: 0                           │  ← Код ошибки (если есть)
└─────────────────────────────────────────┘
```

## 📚 Логирование
Это "контракт" - что должен уметь любой логгер:
```plaintext
┌─────────────────────────────────────────┐
│              ILogger                    │
├─────────────────────────────────────────┤
│ + Trace(message)                        │  ← Детальная отладка
│ + Debug(message)                        │  ← Отладочная информация  
│ + Info(message)                         │  ← Обычная информация
│ + Warn(message)                         │  ← Предупреждения
│ + Error(message, error_code)            │  ← Ошибки
│ + Fatal(message, error_code)            │  ← Критические ошибки
│ + SetLevel(level)                       │  ← Установить мин. уровень
│ + AddHandler(handler)                   │  ← Добавить обработчик
│ + RemoveHandler(handler)                │  ← Убрать обработчик
└─────────────────────────────────────────┘
```

### 3. CLogger - основная реализация
Это "мозг" системы:
```plaintext
┌─────────────────────────────────────────┐
│              CLogger                    │
├─────────────────────────────────────────┤
│ - m_name: string                        │  ← Имя логгера
│ - m_level: ENUM_LOG_LEVEL               │  ← Минимальный уровень
│ - m_handlers: CArrayObj                 │  ← Список обработчиков
│ - m_enabled: bool                       │  ← Включен ли логгер
│ - m_global_lock: static bool            │  ← Защита от рекурсии
├─────────────────────────────────────────┤
│ + Log(level, message, error_code)       │  ← Главный метод
│ + CreateLogRecord(...)                  │  ← Создать запись
│ + AcquireLock() / ReleaseLock()         │  ← Блокировки
└─────────────────────────────────────────┘
```
Алгоритм работы CLogger.Log():
```plaintext
1. Проверить: включен ли логгер?
   НЕТ → выход
   
2. Проверить: достаточен ли уровень сообщения?
   НЕТ → выход
   
3. Получить блокировку (защита от рекурсии)
   НЕ УДАЛОСЬ → выход
   
4. Создать SLogRecord со всеми данными
   
5. Для каждого обработчика в списке:
   - Вызвать handler.Handle(record)
   
6. Освободить блокировку
```

### 4. ILogHandler - интерфейс обработчика
"Контракт" для всех способов вывода:
```plaintext
┌─────────────────────────────────────────┐
│            ILogHandler                  │
├─────────────────────────────────────────┤
│ + Handle(record): bool                  │  ← Обработать сообщение
│ + SetFormatter(formatter)               │  ← Установить форматтер
│ + SetFilter(filter)                     │  ← Установить фильтр
│ + SetLevel(level)                       │  ← Свой уровень фильтрации
│ + Flush()                               │  ← Принудительный сброс
│ + Close()                               │  ← Закрыть ресурсы
└─────────────────────────────────────────┘
```

### 5. Конкретные обработчики
#### ConsoleHandler - вывод в консоль
```plaintext
┌─────────────────────────────────────────┐
│          ConsoleHandler                 │
├─────────────────────────────────────────┤
│ Что делает:                             │
│ 1. Получает SLogRecord                  │
│ 2. Проверяет уровень и фильтры          │
│ 3. Форматирует сообщение                │
│ 4. Вызывает Print() или PrintFormat()   │
│                                         │
│ Особенности:                            │
│ - Мгновенный вывод                      │
│ - Цветовая индикация по уровням         │
│ - Не требует ресурсов                   │
└─────────────────────────────────────────┘
```
#### FileHandler - вывод в файл
```plaintext
┌─────────────────────────────────────────┐
│           FileHandler                   │
├─────────────────────────────────────────┤
│ Что делает:                             │
│ 1. Открывает файл (если не открыт)      │
│ 2. Проверяет размер файла               │
│ 3. Ротирует файл (если нужно)           │
│ 4. Записывает отформатированное сообщение│
│ 5. Сбрасывает буферы (опционально)      │
│                                         │
│ Особенности:                            │
│ - Ротация файлов по размеру             │
│ - Автоматическое создание папок         │
│ - Буферизация для производительности    │
│ - Обработка ошибок записи               │
└─────────────────────────────────────────┘
```
#### SqliteHandler - вывод в SQLite
```plaintext
┌─────────────────────────────────────────┐
│          SqliteHandler                  │
├─────────────────────────────────────────┤
│ Что делает:                             │
│ 1. Подключается к SQLite базе           │
│ 2. Создает таблицу (если не существует) │
│ 3. Вставляет запись в таблицу           │
│ 4. Поддерживает пакетную вставку        │
│                                         │
│ Структура таблицы:                      │
│ CREATE TABLE logs (                     │
│   id INTEGER PRIMARY KEY,               │
│   timestamp TEXT,                       │
│   level TEXT,                           │
│   logger_name TEXT,                     │
│   message TEXT,                         │
│   source_file TEXT,                     │
│   source_line INTEGER,                  │
│   error_code INTEGER                    │
│ );                                      │
└─────────────────────────────────────────┘
```

## 🔄 Паттерн работы обработчика

Каждый обработчик работает по единому алгоритму:

```plaintext
┌─────────────────────────────────────────┐
│         Handler.Handle(record)          │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│    1. Проверка уровня                   │
│    if (record.level < m_level)          │
│        return true; // пропускаем       │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│    2. Применение фильтра                │
│    if (m_filter != NULL &&              │
│        !m_filter.ShouldLog(record))     │
│        return true; // фильтр отклонил  │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│    3. Форматирование                    │
│    string formatted_message;            │
│    if (m_formatter != NULL)             │
│        formatted_message =              │
│            m_formatter.Format(record);  │
│    else                                 │
│        formatted_message = record.message;│
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│    4. Вывод сообщения                   │
│    // Специфичная логика для каждого    │
│    // типа обработчика                  │
│    DoActualOutput(formatted_message);   │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│    5. Возврат результата                │
│    return success; // true/false        │
└─────────────────────────────────────────┘
```

## 🎨 Форматтеры (ILogFormatter)

**Концепция форматирования:**
Форматтер превращает "сырые" данные в красивую строку:
```plaintext
Входные данные (SLogRecord):
├─ level: LOG_INFO
├─ timestamp: 2024-01-15 14:30:25
├─ logger_name: "TradingBot"
├─ message: "Открыта позиция BUY EURUSD"
└─ error_code: 0

                    │
                    ▼ Форматтер применяет шаблон
                    
Выходная строка:
"2024-01-15 14:30:25 [INFO] TradingBot: Открыта позиция BUY EURUSD"
```

**Типы форматтеров:**
**SimpleFormatter** - простое форматирование:
```plaintext
Шаблон: "{timestamp} [{level}] {logger}: {message}"
Результат: "2024-01-15 14:30:25 [INFO] TradingBot: Открыта позиция"
```
**DetailedFormatter** - подробное форматирование:
```plaintext
Шаблон: "{timestamp} [{level}] {logger} ({file}:{line}) - {message}"
Результат: "2024-01-15 14:30:25 [INFO] TradingBot (Expert.mq5:145) - Открыта позиция"
```
**JsonFormatter** - JSON формат:
```plaintext
Результат: 
{
  "timestamp": "2024-01-15T14:30:25",
  "level": "INFO",
  "logger": "TradingBot",
  "message": "Открыта позиция BUY EURUSD",
  "source": "Expert.mq5:145"
}
```

## 🔍 Фильтры (ILogFilter)

**Концепция фильтрации:**
Фильтр решает: "Нужно ли обрабатывать это сообщение?"
```plaintext
┌─────────────────────────────────────────┐
│           SLogRecord                    │
│   level: LOG_DEBUG                      │
│   message: "Проверка индикатора"        │
│   logger_name: "TradingBot"             │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│         LevelFilter                     │
│   min_level: LOG_INFO                   │
│                                         │
│   ShouldLog(record):                    │
│   return record.level >= LOG_INFO       │
│                                         │
│   Результат: FALSE (DEBUG < INFO)       │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│    Сообщение отклонено фильтром         │
│         (не будет выведено)             │
└─────────────────────────────────────────┘
```

**Типы фильтров:**
LevelFilter - фильтр по уровню:
```cpp
class CLevelFilter : public ILogFilter
{
private:
    ENUM_LOG_LEVEL m_min_level;
    
public:
    bool ShouldLog(const SLogRecord &record) override
    {
        return record.level >= m_min_level;
    }
};
```
RegexFilter - фильтр по содержимому:
```cpp
class CRegexFilter : public ILogFilter
{
private:
    string m_pattern;
    bool m_include; // true = включать совпадения, false = исключать
    
public:
    bool ShouldLog(const SLogRecord &record) override
    {
        bool matches = StringFind(record.message, m_pattern) >= 0;
        return m_include ? matches : !matches;
    }
};
```
TimeFilter - фильтр по времени:
```cpp
class CTimeFilter : public ILogFilter
{
private:
    datetime m_start_time;
    datetime m_end_time;
    
public:
    bool ShouldLog(const SLogRecord &record) override
    {
        return record.timestamp >= m_start_time && 
               record.timestamp <= m_end_time;
    }
};
```

## 🏭 Factory Pattern - создание логгеров
**Проблема:** Создание логгера с нужными обработчиками - сложная задача.  

**Решение:** Фабрика, которая создает готовые конфигурации:
```cpp
┌─────────────────────────────────────────┐
│          LoggerFactory                  │
├─────────────────────────────────────────┤
│ + CreateConsoleLogger(name)             │
│ + CreateFileLogger(name, filename)      │
│ + CreateDatabaseLogger(name, db_path)   │
│ + CreateComboLogger(name, config)       │
└─────────────────────────────────────────┘
```

Примеры использования:
```cpp
// Простой консольный логгер
ILogger* console_logger = LoggerFactory::CreateConsoleLogger("Console");

// Логгер с записью в файл
ILogger* file_logger = LoggerFactory::CreateFileLogger("FileLog", "trading.log");

// Комбинированный логгер (консоль + файл + база)
LoggerConfig config;
config.enable_console = true;
config.enable_file = true;
config.file_path = "logs/trading.log";
config.enable_database = true;
config.db_path = "logs/trading.db";

ILogger* combo_logger = LoggerFactory::CreateComboLogger("Trading", config);
```

## 📈 Уровни логирования (детально)
Иерархия уровней:
```plaintextTRACE (0)    ← Самый подробный
  │
DEBUG (1)    ← Отладочная информация
  │
INFO (2)     ← Обычная информация
  │
WARN (3)     ← Предупреждения
  │
ERROR (4)    ← Ошибки
  │
FATAL (5)    ← Критические ошибки
```

**Правило фильтрации:**
Если установлен уровень INFO, то выводятся сообщения: INFO, WARN, ERROR, FATAL (но не TRACE и DEBUG)

Практические примеры:
```cpp
// TRACE - очень детальная отладка
logger.Trace("Входим в функцию CalculateIndicator()");
logger.Trace("RSI value = 45.67, MA value = 1.2345");

// DEBUG - отладочная информация
logger.Debug("Проверяем условия для открытия позиции");
logger.Debug("Spread = 2 pips, доступная маржа = $1000");

// INFO - обычная информация о работе
logger.Info("Открыта позиция BUY EURUSD 0.1 lot по цене 1.2345");
logger.Info("Получен новый тик: EURUSD bid=1.2344 ask=1.2346");

// WARN - предупреждения (не критично, но стоит обратить внимание)
logger.Warn("Высокий спред: 5 pips (обычно 2 pips)");
logger.Warn("Низкий уровень маржи: осталось $100");

// ERROR - ошибки (что-то пошло не так)
logger.Error("Не удалось открыть позицию", GetLastError());
logger.Error("Ошибка подключения к серверу котировок");

// FATAL - критические ошибки (программа может упасть)
logger.Fatal("Критическая ошибка памяти", GetLastError());
logger.Fatal("Потеряно соединение с торговым сервером");
```

## 🔒 Защита от рекурсии
Проблема:
```cpp
// Опасная ситуация:
logger.Info("Начинаем торговлю");
  └─ FileHandler пытается записать в файл
      └─ Ошибка записи в файл
          └─ FileHandler вызывает logger.Error("Ошибка записи")
              └─ Снова FileHandler...
                  └─ БЕСКОНЕЧНАЯ РЕКУРСИЯ!
```
Решение - глобальная блокировка:
```cpp
class CLogger 
{
private:
    static bool m_global_lock;
    
    bool AcquireLock()
    {
        if(m_global_lock) 
            return false; // Уже заблокировано
        m_global_lock = true;
        return true;
    }
    
    void ReleaseLock()
    {
        m_global_lock = false;
    }
};
```

# 🚀 MVP (Minimum Viable Product) - что реализуем сначала
## Steps
### Этап 1 - Базовая функциональность:
```cpp
✅ SLogRecord - структура данных
✅ ILogger интерфейс
✅ CLogger - основная реализация
✅ ConsoleHandler - вывод в терминал
✅ FileHandler - запись в файлы
✅ SqliteHandler - запись в базу данных
✅ SimpleFormatter - простое форматирование
✅ DetailedFormatter - подробное форматирование
✅ LevelFilter - фильтр по уровню
✅ RegexFilter - фильтрация по содержимому
✅ LoggerFactory - фабрика логгеров
✅ Source tracing - макросы для правильного отслеживания источника
✅ Flush management - централизованное управление сбросом буферов
✅ Глобальная блокировка для защиты от рекурсии
```

### Этап 2 - Расширение функциональности:
```cpp
✅ TimeFilter - фильтрация по времени
✅ Ротация файлов
✅ Автоматический Flush по таймеру
✅ Пакетная запись в БД (batch mode)
✅ Композитные фильтры
```

### Этап 3 - Продвинутые возможности:
```cpp
✅ JsonFormatter - JSON формат
✅ PushHandler - отправка уведомлений
✅ EmailHandler - отправка по email
✅ Конфигурация из файлов
✅ Синглтоны и кеширование логгеров
✅ Асинхронное логирование
✅ Интеграция с внешними системами (ELK, Grafana)
✅ Метрики производительности
```

## 💡 Преимущества такой архитектуры
**1. Модульность**
- Каждый компонент независим
- Легко тестировать отдельно
- Можно заменять части без влияния на остальные
**2. Расширяемость**
- Новый способ вывода = новый Handler
- Новый формат = новый Formatter
- Новое условие фильтрации = новый Filter
**3. Гибкость**
- Один логгер может иметь много обработчиков
- Каждый обработчик может иметь свой форматтер и фильтр
- Разные уровни фильтрации на разных уровнях
**4. Производительность**
- Ранняя фильтрация по уровням
- Ленивое форматирование (только если нужно)
- Буферизация для файлов и БД

Эта архитектура позволяет начать с простого и постепенно наращивать функциональность без переписывания существующего кода.


# Структура файлов с зависимостями 
## Структура файлов
```plaintext
Include/Logger/
├── Logger.mqh                  // Главный include (подключает все остальное)
├── Core/
│   ├── Interfaces.mqh          // ILogger, ILogHandler, ILogFormatter, ILogFilter
│   ├── LogRecord.mqh           // SLogRecord + ENUM_LOG_LEVEL
│   ├── Logger.mqh              // CLogger
│   └── Macros.mqh              // LOG_INFO, LOG_ERROR и т.д.
├── Handlers/
│   ├── ConsoleHandler.mqh
│   ├── FileHandler.mqh
│   └── SqliteHandler.mqh
├── Formatters/
│   ├── SimpleFormatter.mqh
│   └── DetailedFormatter.mqh
├── Filters/
│   ├── LevelFilter.mqh
│   └── RegexFilter.mqh
└── Factory/
    └── LoggerFactory.mqh
```
## Зависимости
Logger.mqh включает все остальные файлы
Handlers зависят от Interfaces.mqh
Formatters зависят от LogRecord.mqh

# Простой план разработки этапа 1 (MVP) по шагам

## План разработки (Этап 1)

### Шаг 1: Базовые структуры
- Создать ENUM_LOG_LEVEL
- Создать SLogRecord
- Создать все интерфейсы (ILogger, ILogHandler, etc.)

### Шаг 2: Основной логгер
- Реализовать CLogger с базовым функционалом
- Добавить глобальную блокировку
- Добавить Flush management

### Шаг 3: Обработчики
- ConsoleHandler (простой)
- FileHandler (с базовой записью)
- SqliteHandler (с базовой записью)

### Шаг 4: Форматтеры и фильтры
- SimpleFormatter, DetailedFormatter
- LevelFilter, RegexFilter

### Шаг 5: Фабрика и макросы
- LoggerFactory с базовыми методами
- Макросы LOG_INFO, LOG_ERROR и т.д.

### Шаг 6: Главный include файл
- Logger.mqh который подключает все компоненты

## **3. Детали для SQLite** ✅

### SQLite структура (для SqliteHandler)
```sql
CREATE TABLE logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    level TEXT NOT NULL,
    logger_name TEXT NOT NULL,
    message TEXT NOT NULL,
    source_file TEXT,
    source_line INTEGER,
    function_name TEXT,
    error_code INTEGER DEFAULT 0
);

CREATE INDEX idx_logs_timestamp ON logs(timestamp);
CREATE INDEX idx_logs_level ON logs(level);
```

## Базовый пример использования
```cpp
#include <Logger/Logger.mqh>

void OnStart()
{
   // Создаем логгер через фабрику
   ILogger* logger = LoggerFactory::CreateComboLogger("Trading");
   
   // Используем макросы для удобства
   LOG_INFO(logger, "Торговый робот запущен");
   LOG_WARN(logger, "Высокий спред: 5 pips");
   LOG_ERROR(logger, "Ошибка открытия позиции", GetLastError());
   
   // Принудительно сбрасываем буферы
   logger.Flush();
   
   delete logger;
}
```

## Что НЕ нужно в плане:
❌ Полные реализации классов (это уже разработка)
❌ Детальные алгоритмы (будем делать по ходу)
❌ Сложная обработка ошибок (GetLastError достаточно)
❌ Юнит-тесты (ad-hoc тестирование - специфика MQL)

