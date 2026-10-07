//+------------------------------------------------------------------+
//|                                                   TestSqlite.mqh |
//| Запись в базу SQLite                                             |
//+------------------------------------------------------------------+
void TestSqlite()
{
   //--- строки и столбцы
   LT_CASE("sqlite: rows and columns are stored");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_rows.db");
      LT_CHECK(h.Handle(CreateLogRecord(LOG_INFO, "plain", "lgt_a")));
      LT_CHECK(h.Handle(CreateLogRecord(LOG_WARN, "it's a 'quoted'  text, кириллица", "lgt_a", "F.mq5", 17, "Fn", 0)));
      LT_CHECK(h.Handle(CreateLogRecord(LOG_ERROR, "with code", "lgt_b", "", 0, "", 4756)));
      delete h;
      LT_EQ(LtDbLong("lgt_rows.db", "SELECT COUNT(*) FROM logs"), 3);
      LT_EQ(LtDbLong("lgt_rows.db", "SELECT level FROM logs WHERE id=2"), 3);
      LT_EQ(LtDbText("lgt_rows.db", "SELECT message FROM logs WHERE id=2"), "it's a 'quoted'  text, кириллица");
      LT_EQ(LtDbText("lgt_rows.db", "SELECT source_file FROM logs WHERE id=2"), "F.mq5");
      LT_EQ(LtDbLong("lgt_rows.db", "SELECT source_line FROM logs WHERE id=2"), 17);
      LT_EQ(LtDbText("lgt_rows.db", "SELECT function_name FROM logs WHERE id=2"), "Fn");
      LT_EQ(LtDbText("lgt_rows.db", "SELECT logger_name FROM logs WHERE id=3"), "lgt_b");
      LT_EQ(LtDbLong("lgt_rows.db", "SELECT error_code FROM logs WHERE id=3"), 4756);
   }
   //--- уровень обработчика
   LT_CASE("sqlite: handler level cuts lower records");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_level.db");
      h.SetLevel(LOG_WARN);
      LT_CHECK(!h.Handle(CreateLogRecord(LOG_INFO, "no", "lgt")));
      LT_CHECK(h.Handle(CreateLogRecord(LOG_ERROR, "yes", "lgt")));
      delete h;
      LT_EQ(LtDbLong("lgt_level.db", "SELECT COUNT(*) FROM logs"), 1);
   }
   //--- счётчик записей
   LT_CASE("sqlite: GetRecordCount returns the number of rows");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_count.db");
      for(int i = 0; i < 3; i++)
         h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      LT_EQ(h.GetRecordCount(), 3);
      delete h;
   }
   //--- пакетный режим
   LT_CASE("sqlite: batch mode keeps every row after close");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_batch.db", "logs", false, 100);
      for(int i = 0; i < 5; i++)
         h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      delete h;
      LT_EQ(LtDbLong("lgt_batch.db", "SELECT COUNT(*) FROM logs"), 5);
   }
   LT_CASE("sqlite: batch mode commits without SQL errors");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_batch_err.db", "logs", false, 100);
      ResetLastError();
      for(int i = 0; i < 250; i++)
         h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      int err = GetLastError();
      delete h;
      LT_EQ(err, 0);
      LT_EQ(LtDbLong("lgt_batch_err.db", "SELECT COUNT(*) FROM logs"), 250);
   }
   LT_CASE("sqlite: switching a live handler to batch mode and back works");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_switch.db");
      h.SetAutoCommit(false);
      h.SetBatchSize(2);
      ResetLastError();
      for(int i = 0; i < 3; i++)
         h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      h.SetAutoCommit(true);
      LT_EQ(h.GetRecordCount(), 3);
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      int err = GetLastError();
      delete h;
      LT_EQ(err, 0);
      LT_EQ(LtDbLong("lgt_switch.db", "SELECT COUNT(*) FROM logs"), 4);
   }
   //--- новые столбцы времени и база прежней версии
   LT_CASE("sqlite: time columns are stored, an older table is upgraded");
   {
      int db = DatabaseOpen("lgt_old.db", DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
      LT_CHECK(db != INVALID_HANDLE);
      DatabaseExecute(db, "CREATE TABLE logs (id INTEGER PRIMARY KEY AUTOINCREMENT, ticktime DATETIME NOT NULL, "
                          "level INTEGER NOT NULL, logger_name TEXT NOT NULL, message TEXT NOT NULL, source_file TEXT, "
                          "source_line INTEGER, function_name TEXT, thread_id INTEGER, error_code INTEGER, "
                          "timestamp INTEGER NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)");
      DatabaseExecute(db, "INSERT INTO logs (ticktime, level, logger_name, message, timestamp) "
                          "VALUES ('2026.01.09 10:00:00', 2, 'old', 'old row', 1767952800)");
      DatabaseClose(db);
      CSqliteHandler* h = new CSqliteHandler("lgt_old.db");
      LT_CHECK(h.IsOpen());
      SLogRecord rec = CreateLogRecord(LOG_INFO, "new row", "lgt");
      LT_CHECK(h.Handle(rec));
      LT_EQ(h.GetRecordCount(), 2);
      LT_EQ(h.FailedCount(), 0);
      delete h;
      LT_EQ(LtDbText("lgt_old.db", "SELECT message FROM logs WHERE id=1"), "old row");
      LT_EQ(LtDbLong("lgt_old.db", "SELECT seq FROM logs WHERE id=2"), (long)rec.sequence);
      LT_EQ(LtDbLong("lgt_old.db", "SELECT elapsed_us FROM logs WHERE id=2"), (long)rec.elapsed_us);
      LT_EQ(LtDbLong("lgt_old.db", "SELECT time_local FROM logs WHERE id=2"), (long)rec.time_local);
      LT_EQ(LtDbLong("lgt_old.db", "SELECT timestamp FROM logs WHERE id=2"), (long)rec.timestamp);
   }
   //--- запись не трогает код последней ошибки вызывающего
   LT_CASE("sqlite: writing keeps the caller's last error code");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_lasterr.db");
      FileOpen("lgt_no_such_file.bin", FILE_READ | FILE_BIN);
      int expected = GetLastError();
      LT_CHECK(expected != 0);
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      LT_EQ(GetLastError(), expected);
      delete h;
      LT_EQ(GetLastError(), expected);
      ResetLastError();
   }
   //--- индексы только по требованию
   LT_CASE("sqlite: indexes are created on request only");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_idx.db", "logs", false, 100);
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      delete h;
      LT_EQ(LtDbLong("lgt_idx.db", "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name LIKE 'idx_logs_%'"), 0);
      h = new CSqliteHandler("lgt_idx.db", "logs", false, 100);
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      ResetLastError();
      h.SetCreateIndexes(true);
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      LT_EQ(GetLastError(), 0);
      delete h;
      LT_EQ(LtDbLong("lgt_idx.db", "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name LIKE 'idx_logs_%'"), 4);
      LT_EQ(LtDbLong("lgt_idx.db", "SELECT COUNT(*) FROM logs"), 3);
   }
   //--- два обработчика на одной базе (два экземпляра программы)
   LT_CASE("sqlite: two handlers on one database, record-by-record mode");
   {
      CSqliteHandler* a = new CSqliteHandler("lgt_two.db");
      CSqliteHandler* b = new CSqliteHandler("lgt_two.db");
      int stored = 0;
      for(int i = 0; i < 20; i++)
      {
         if(a.Handle(CreateLogRecord(LOG_INFO, "from a", "lgt")))
            stored++;
         if(b.Handle(CreateLogRecord(LOG_INFO, "from b", "lgt")))
            stored++;
      }
      LT_EQ(stored, 40);
      LT_EQ(a.FailedCount() + b.FailedCount(), 0);
      delete a;
      delete b;
      LT_EQ(LtDbLong("lgt_two.db", "SELECT COUNT(*) FROM logs"), 40);
   }
   //--- очистка
   LT_CASE("sqlite: Clear empties the table in both write modes");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_clear.db");
      for(int i = 0; i < 5; i++)
         h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      LT_CHECK(h.Clear());
      LT_EQ(h.GetRecordCount(), 0);
      h.SetAutoCommit(false);
      ResetLastError();
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      LT_CHECK(h.Clear());
      h.Handle(CreateLogRecord(LOG_INFO, "kept", "lgt"));
      LT_EQ(GetLastError(), 0);
      delete h;
      LT_EQ(LtDbLong("lgt_clear.db", "SELECT COUNT(*) FROM logs"), 1);
   }
   //--- режим сброса на диск
   LT_CASE("sqlite: durable mode can be switched in both write modes");
   {
      CSqliteHandler* h = new CSqliteHandler("lgt_durable.db", "logs", false, 100);
      ResetLastError();
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      h.SetDurable(true);
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      h.SetAutoCommit(true);
      h.SetDurable(false);
      h.Handle(CreateLogRecord(LOG_INFO, "rec", "lgt"));
      LT_EQ(GetLastError(), 0);
      LT_EQ(h.GetRecordCount(), 3);
      delete h;
   }
   ResetLastError();
   LtCleanup();
}
