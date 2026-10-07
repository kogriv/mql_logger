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
   ResetLastError();
   LtCleanup();
}
