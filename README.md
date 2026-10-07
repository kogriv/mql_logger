# mql_logger — журналирование для программ MQL5

Библиотека для советников, индикаторов и скриптов MetaTrader 5: уровни сообщений, вывод в журнал терминала,
в файл и в базу SQLite, свой вид строки, отбор записей. Версия 2.0.0 — что изменилось, см. [`CHANGELOG.md`](CHANGELOG.md).

- Выключенный уровень стоит одной проверки: строка сообщения не строится (0,01 мкс на вызов).
- Запись в базу переживает критическую ошибку программы (`array out of range` и подобные).
- Тесты: 55 случаев, `Tests/`.

## Установка

Папку библиотеки положить в `MQL5\Include\Logger` (или подключить git-сабмодулем), в программе:

```mql5
#include <Logger\Logger.mqh>
```

## Быстрый старт

Полные примеры, которые собираются: [`Examples/QuickStart.mq5`](Examples/QuickStart.mq5) (скрипт) и
[`Examples/ExpertSkeleton.mq5`](Examples/ExpertSkeleton.mq5) (каркас советника).

```mql5
#include <Logger\Logger.mqh>

void OnStart()
{
   LOGINFO("Скрипт запущен на " + _Symbol);                 // логгер по умолчанию: журнал терминала, от INFO
   LOGWARN(StringFormat("Спред %d пунктов", (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
   ShutdownLogging();                                       // сбросить буферы, закрыть файлы и базы
}
```

В журнале терминала:

```
2026.10.07 07:28:27 [INFO] default: Скрипт запущен на EURUSD [Script.mq5:5:OnStart]
```

## Уровни

| Уровень | Значение | Для чего |
|---|---|---|
| `LOG_TRACE` | 0 | ход выполнения по шагам |
| `LOG_DEBUG` | 1 | отладочные значения |
| `LOG_INFO` | 2 | обычные события |
| `LOG_WARN` | 3 | подозрительное, работа продолжается |
| `LOG_ERROR` | 4 | ошибка |
| `LOG_FATAL` | 5 | дальше работать нельзя |

Запись отсекается в трёх местах: уровень логгера (`SetLevel`, по умолчанию `INFO`), уровень обработчика
(`SetLevel`, по умолчанию всё), фильтр обработчика.

## Макросы

Все макросы сначала проверяют уровень и только потом вычисляют сообщение, а в запись кладут файл, строку и
функцию вызова.

| Логгер `default` | По имени | По указателю | Уровень |
|---|---|---|---|
| `LOGTRACE(msg)` | `LOGTRACE_N("имя", msg)` | `LOGTRACE_TO(ptr, msg)` | TRACE |
| `LOGDEBUG(msg)` | `LOGDEBUG_N` | `LOGDEBUG_TO` | DEBUG |
| `LOGINFO(msg)` | `LOGINFO_N` | `LOGINFO_TO` | INFO |
| `LOGWARN(msg)` | `LOGWARN_N` | `LOGWARN_TO` | WARN |
| `LOGERROR(msg)` | `LOGERROR_N` | `LOGERROR_TO` | ERROR, код — `GetLastError()` |
| `LOGFATAL(msg)` | `LOGFATAL_N` | `LOGFATAL_TO` | FATAL, код — `GetLastError()` |
| `LOGERROR_CODE(msg, code)` | — | `LOGERROR_CODE_TO(ptr, msg, code)` | ERROR со своим кодом |
| `LOGFATAL_CODE(msg, code)` | — | `LOGFATAL_CODE_TO(ptr, msg, code)` | FATAL со своим кодом |

- `…_TO(ptr, …)` — основной способ в классах: указатель `ILogger*` (или `CLogger*`) хранится в поле; `NULL`
  допустим — вызов ничего не делает.
- `…_N("имя", …)` ищет логгер по имени на каждый вызов (5 мкс) — в часто вызываемом коде держите указатель.
- Имена `LOG_INFO(...)` заняты значениями уровней, поэтому макросы пишутся слитно: `LOGINFO`.

Ещё:

```mql5
LOGIF(spread > 30, LOG_WARN, "Широкий спред");            // условие, уровень, сообщение — логгер default
LOGEXECUTION_TIME("Пересчёт", { Recalculate(); });        // выполнить и записать длительность (DEBUG)
LOGFUNCTION_ENTRY();  LOGFUNCTION_EXIT();                 // TRACE: вход и выход из функции
LOGTRADE_OPEN(_Symbol, ORDER_TYPE_BUY, 0.10, price);      // INFO: "Trade opened: EURUSD ORDER_TYPE_BUY 0.10 lots at 1.23450"
LOGTRADE_CLOSE(_Symbol, 0.10, price, profit);
```

Без макросов — методы логгера: `Trace`, `Debug`, `Info`, `Warn`, `Error(msg, code)`, `Fatal(msg, code)` и
`Log(level, msg, code, file, line, func)`. Они сообщение получают уже построенным; чтобы не строить его зря —
`if(logger.IsEnabled(LOG_DEBUG)) …` или макросы.

## Логгеры и фабрика

Логгеры создаёт и хранит `CLoggerFactory`; всё созданное через неё она же освобождает.

```mql5
CLogger* a = CLoggerFactory::GetLogger("orders");                          // найти или создать с конфигурацией по умолчанию
CLogger* b = CLoggerFactory::CreateConsoleLogger("ui", LOG_DEBUG);         // журнал терминала
CLogger* c = CLoggerFactory::CreateFileLogger("audit", "audit.log");       // файл
CLogger* d = CLoggerFactory::CreateDatabaseLogger("trace", "trace.db", LOG_TRACE);   // база
CLogger* e = CLoggerFactory::CreateCompositeLogger("ea", true, "ea.log", "ea.db");   // всё сразу
```

Своя конфигурация:

```mql5
SLoggerConfig config;
config.level = LOG_DEBUG;
config.console_output = true;
config.file_output = true;        config.log_file = "ea.log";
config.database_output = true;    config.database_file = "ea.db";
config.db_auto_commit = true;     // база: запись сразу (по умолчанию) или пакетами по db_batch_size
config.detailed_format = true;    // подробная строка в журнале и файле
CLogger* logger = CLoggerFactory::CreateLogger("ea", config);
```

Правила:

- Имя: 1–50 знаков — латинские буквы, цифры, `_`, `-`, `.`. Недопустимое имя — `NULL` и одна строка в журнал
  терминала.
- Логгер с таким именем уже есть — возвращается он, новая конфигурация не применяется (повторный `OnInit` при
  смене периода графика получает свой прежний логгер). Нужна другая — сначала `CLoggerFactory::RemoveLogger(имя)`.
- `RemoveLogger` закрывает обработчики логгера (файл, базу), если ими не пользуется другой логгер.
- `ShutdownLogging()` — всё сбросить и закрыть; после него логгеры создаются заново.
- `CLoggerFactory::SetGlobalLevel(level)`, `EnableAll(bool)`, `FlushAll()` — для всех логгеров сразу.

### Профили

Готовые наборы для советника — уровень логгера равен наименьшему уровню его обработчиков:

| Профиль | Журнал терминала | База `<имя>.db` | Для чего |
|---|---|---|---|
| `LOGGER_PROFILE_PERFORMANCE` | от WARN | нет | оптимизация: всё ниже WARN отсекается одной проверкой |
| `LOGGER_PROFILE_PRODUCTION` | от WARN | от INFO | работа на графике |
| `LOGGER_PROFILE_DEBUG` | от WARN | от TRACE | разбор поведения в одиночном тесте |

```mql5
input ENUM_LOGGER_PROFILE InpLogProfile = LOGGER_PROFILE_PERFORMANCE;
...
g_logger = CLoggerFactory::CreateProfileLogger("MyExpert", InpLogProfile);
```

## Обработчики

Обработчик получает запись, проверяет свой уровень и фильтр и выводит её. К логгеру можно добавить несколько
(`logger.AddHandler(handler)`).

### Журнал терминала — `CConsoleHandler`

`CLoggerFactory::CreateConsoleHandler(use_print = true, show_alerts = false)`; `show_alerts` — окно `Alert` для
ERROR и FATAL.

### Файл — `CFileHandler`

```mql5
CFileHandler* file = CLoggerFactory::CreateFileHandler("ea.log", /*append*/true, /*auto_flush*/false,
                                                       /*common*/false, /*unicode*/false);
file.SetMaxFileSize(5 * 1024 * 1024);   // ротация при 5 МБ
file.SetMaxArchives(10);                // хранить 10 архивов
file.SetFlushInterval(10);              // сброс буфера не реже раза в 10 с
```

- Файл — в `MQL5\Files` программы (в тестере — в папке агента); `common = true` — общая папка терминалов.
- Кодировка — UTF-8 без BOM; `unicode = true` — UTF-16. Журнал можно читать, пока программа работает.
- `append = true` дописывает в существующий файл; `false` — начинает файл заново при первом открытии.
- `auto_flush = true` — каждая запись сразу на диск; иначе буфер 8 КБ и сброс по интервалу, в `Flush()` и при
  закрытии.
- Ротация: `ea.log` → `ea.1.log`, `ea.2.log`, … (больше номер — новее); номера прошлых запусков не
  перезаписываются.
- Файл недоступен — одна строка в журнал терминала, повтор открытия раз в 5 с; сколько записей не сохранено —
  `DroppedCount()`.

### База SQLite — `CSqliteHandler`

```mql5
CSqliteHandler* db = CLoggerFactory::CreateSqliteHandler("ea.db", "logs", /*auto_commit*/true, /*batch_size*/100);
```

| Режим | Время на запись | При критической ошибке программы |
|---|---|---|
| по записи (`auto_commit = true`, по умолчанию) | 0,15 мс | все записи в базе |
| пакетами (`auto_commit = false`) | 0,04 мс | незакоммиченный хвост (до `batch_size` записей) теряется |
| по записи + `SetDurable(true)` | 1,6 мс | все записи в базе, каждая дождалась диска |

- Коммит пакета — каждые `batch_size` записей, в `Flush()` и при закрытии.
- Индексы при записи не создаются (с ними запись вдвое медленнее). Перед разбором большого журнала —
  `db.SetCreateIndexes(true)` или запрос `CREATE INDEX`.
- `GetRecordCount()`, `ClearOldRecords(days)`, `ExecuteQuery(sql)`, `FailedCount()`.

Таблица (`logs`):

| Столбец | Что |
|---|---|
| `id` | номер строки |
| `ticktime`, `timestamp` | время сервера (последний тик; в тестере — время модели): текстом и секундами |
| `time_local` | часы компьютера, секунды (в тестере — время модели) |
| `elapsed_us` | микросекунды от запуска программы |
| `seq` | номер записи в программе |
| `level` | 0…5 |
| `logger_name`, `message` | имя логгера, текст |
| `source_file`, `source_line`, `function_name` | место вызова |
| `error_code` | код ошибки |
| `created_at` | время вставки по часам компьютера, UTC |
| `thread_id` | всегда 0 |

```sql
-- ошибки и предупреждения последнего запуска
SELECT ticktime, level, message, source_file, source_line, error_code FROM logs WHERE level >= 3 ORDER BY id;
-- где программа проводит время: промежутки между соседними записями
SELECT id, message, elapsed_us - LAG(elapsed_us) OVER (ORDER BY id) AS gap_us FROM logs ORDER BY gap_us DESC LIMIT 20;
```

## Вид строки

Без форматтера журнал и файл получают:

```
время_сервера [УРОВЕНЬ] имя_логгера: текст [файл:строка:функция] [Error: код]
```

Части в скобках появляются, когда место вызова и код заданы. Свой вид — форматтер с шаблоном:

```mql5
handler.SetFormatter(CLoggerFactory::CreateSimpleFormatter("%elapsed% %level% %logger%: %message% %error_info%"));
handler.SetFormatter(CLoggerFactory::CreateDetailedFormatter());            // уровень выровнен, место вызова и код
handler.SetFormatter(CLoggerFactory::CreateDetailedFormatter("", true));    // многострочный
```

| Поле | Значение |
|---|---|
| `%timestamp%` | время сервера (последний тик; в тестере — модели), до секунды |
| `%localtime%` | часы компьютера, до секунды |
| `%elapsed%` | секунды от запуска программы, 6 знаков после точки |
| `%seq%` | номер записи в программе |
| `%level%` | уровень |
| `%logger%` | имя логгера |
| `%message%` | текст — вставляется как есть |
| `%file%`, `%line%`, `%function%` | место вызова по частям |
| `%source_info%` | `[файл:строка:функция]`, пусто без места вызова |
| `%error%` | код ошибки, пусто при 0 |
| `%error_code%` | код ошибки всегда |
| `%error_info%` | `[Error: код]`, пусто при 0 |

Пустое поле забирает с собой один соседний пробел шаблона. Неизвестное `%имя%` остаётся в строке. Часов
компьютера с миллисекундами в MQL5 нет — промежутки меряйте по `%elapsed%`.

## Фильтры

```mql5
CLevelFilter* levels = CLoggerFactory::CreateLevelFilter(LOG_DEBUG);
levels.SetLevelRange(LOG_DEBUG, LOG_INFO);     // только DEBUG и INFO
levels.ExcludeLevel(LOG_DEBUG);                // кроме DEBUG
handler.SetFilter(levels);

CSubstringFilter* text = CLoggerFactory::CreateSubstringFilter(/*case_sensitive*/false);
text.AddIncludePattern("order");               // пропускать записи со словом order
text.AddExcludePattern("heartbeat");           // исключение сильнее включения
handler.SetFilter(text);
```

`CSubstringFilter` ищет подстроку, не регулярное выражение. `CLevelFilter` нужен для диапазона и исключений;
простой нижний порог — `handler.SetLevel(...)`. У обработчика один фильтр.

## В тестере и на агентах

- Файлы и базы пишутся в `MQL5\Files` агента (`Tester\Agent-…\MQL5\Files`); на удалённом агенте они остаются на
  его машине. Сбор журналов проходов — в работе (`docs/backlog/LOG-BL-10`).
- Для оптимизации — профиль `PERFORMANCE` и макросы: вызов ниже WARN стоит 0,01 мкс.
- Время в записях — время модели.

## Как это выполняется

Программа MQL5 выполняется в одном потоке, обработчики событий (`OnTick`, `OnTimer`, …) — по очереди, поэтому
блокировок в библиотеке нет. Обработчик, форматтер или фильтр может сам писать в логгер — такие вложенные записи
доставляются; цепочка глубже 4 обрывается, оборванные записи считает `logger.DroppedCount()`.

`_LastError` библиотека не сбрасывает и при успешной записи не меняет.

## Тесты

`Tests/LoggerTests.mqh` — все случаи одним скриптом: подключите его из скрипта в папке `Scripts` терминала
(`#include <Logger\Tests\LoggerTests.mqh>`) и запустите; в журнале — строки «… passed / failed» и итог
«N of M passed». Файлы тестов (`lgt_*` в `MQL5\Files`) удаляются.

## Документы

[`docs/`](docs/README.md): устройство (`design/architecture.md`), проекты изменений, разбор кода, пробелы и бэклог.
