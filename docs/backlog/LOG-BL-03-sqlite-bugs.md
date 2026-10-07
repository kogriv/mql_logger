# LOG-BL-03: SQLite — счётчик записей, `PRAGMA`, смена режима коммита

**Статус:** сделано (07.10.2026)  ·  **Приоритет:** P1
**Создано:** 2026-10-07  ·  **Источник:** LOG-GAP-04, F-07, F-08, F-09  ·  **Зависит от:** LOG-BL-01
**Затрагивает:** `Handlers/SqliteHandler.mqh`, `Factory/LoggerFactory.mqh`; поведение потребителей не меняется

## Зачем

Три ошибки, которые исправляются без смены устройства.

## Что сделать

1. `GetRecordCount()`: не присваивать результат `DatabaseColumnInteger` счётчику (`SqliteHandler.mqh`:386).
2. Убрать `PRAGMA synchronous = FULL` из `CommitBatch` и `CloseDatabase`; если режим нужен — задать один раз
   после открытия базы, до первой транзакции.
3. `SetAutoCommit`: при переходе в пакетный режим открыть транзакцию, при обратном — закоммитить открытую.
4. `CreateSqliteHandler` фабрики — параметры `auto_commit` и `batch_size`; `CreateCompositeLogger` перестаёт
   искать обработчик по подстроке пути (F-29).
5. Профиль `PRODUCTION`: убрать `SetBatchSize(10)`, который при автокоммите ничего не делает (до LOG-BL-04).

## Готово, когда

Тесты: счётчик равен числу вставок; 250 записей пакетами по 100 — ни одной строки «SQL query failed» в журнале;
переключение режима на готовом обработчике — без ошибок.

## Сделано (07.10.2026)

- `GetRecordCount()` возвращает число строк (F-07).
- `PRAGMA synchronous = FULL` убрана из коммита и закрытия (F-08): ошибок 5601 в пакетном режиме нет.
- Обработчик следит за открытой транзакцией (`BeginTransaction` / `CommitTransaction`); `SetAutoCommit` на
  работающем обработчике открывает или закрывает её (F-09).
- Фабрика: `CreateSqliteHandler(path, table, auto_commit, batch_size)`; в `SLoggerConfig` — `db_auto_commit`,
  `db_batch_size`; `CreateCompositeLogger` передаёт их через конфигурацию и больше не ищет обработчик по подстроке
  пути (F-29).
- Профили: лишние `SetAutoCommit(true)` / `SetBatchSize(...)` убраны (режим прежний — автокоммит, до LOG-BL-04).
- Из журнала терминала убраны строки «Database closed», «Committing N pending…», «SQLite handler configured»,
  «Logger factory shutdown…», «Force closing…» (часть F-11).
- Тесты: счётчик, 250 записей пакетами без ошибок SQL, переключение режима туда и обратно, составной логгер с
  пакетом 50 — проходят; пометки F-07, F-08, F-09 сняты.
