//+------------------------------------------------------------------+
//|                                                     TestFile.mqh |
//| Запись в файл: прямая, буфер, дозапись, ротация                  |
//+------------------------------------------------------------------+
void TestFile()
{
   string lines[];
   //--- прямая запись
   LT_CASE("file: direct write is readable back");
   {
      CFileHandler* h = new CFileHandler("lgt_direct.log", false, true);
      LT_CHECK(h.Handle(CreateLogRecord(LOG_INFO, "first message", "lgt", "F.mq5", 3, "Fn", 0)));
      LT_CHECK(h.Handle(CreateLogRecord(LOG_ERROR, "second, код 5", "lgt", "", 0, "", 5)));
      delete h;
      LT_EQ(LtReadLines("lgt_direct.log", lines), 2);
      if(ArraySize(lines) == 2)
      {
         LT_CHECK(StringFind(lines[0], "first message") >= 0);
         LT_CHECK(StringFind(lines[0], "[INFO]") >= 0);
         LT_CHECK(StringFind(lines[0], "[F.mq5:3:Fn]") >= 0);
         LT_CHECK(StringFind(lines[1], "second, код 5") >= 0);
         LT_CHECK(StringFind(lines[1], "[Error: 5]") >= 0);
      }
   }
   //--- буфер
   LT_CASE("file: buffered records are all written by close");
   {
      CFileHandler* h = new CFileHandler("lgt_buf.log", false, false);
      h.Handle(CreateLogRecord(LOG_INFO, "one", "lgt"));
      h.Handle(CreateLogRecord(LOG_INFO, "two", "lgt"));
      h.Flush();
      h.Handle(CreateLogRecord(LOG_INFO, "three", "lgt"));
      delete h;
      LT_EQ(LtReadLines("lgt_buf.log", lines), 3);
   }
   //--- режим перезаписи
   LT_CASE("file: rewrite mode starts an empty file");
   {
      CFileHandler* h = new CFileHandler("lgt_rewrite.log", false, true);
      h.Handle(CreateLogRecord(LOG_INFO, "one", "lgt"));
      delete h;
      h = new CFileHandler("lgt_rewrite.log", false, true);
      h.Handle(CreateLogRecord(LOG_INFO, "two", "lgt"));
      delete h;
      LT_EQ(LtReadLines("lgt_rewrite.log", lines), 1);
   }
   //--- дозапись между сеансами
   LT_KNOWN("file: append keeps records of the previous session", "F-01");
   {
      CFileHandler* h = new CFileHandler("lgt_append.log", true, true);
      h.Handle(CreateLogRecord(LOG_INFO, "one", "lgt"));
      delete h;
      h = new CFileHandler("lgt_append.log", true, true);
      h.Handle(CreateLogRecord(LOG_INFO, "two", "lgt"));
      delete h;
      LT_EQ(LtReadLines("lgt_append.log", lines), 2);
   }
   //--- ротация
   LT_KNOWN("file: rotation loses no records", "F-02");
   {
      CFileHandler* h = new CFileHandler("lgt_rot.log", false, true);
      h.SetMaxFileSize(600);
      int accepted = 0;
      for(int i = 0; i < 60; i++)
         if(h.Handle(CreateLogRecord(LOG_INFO, StringFormat("line %03d", i), "lgt")))
            accepted++;
      delete h;
      int files = 0;
      int kept = LtCountLinesByMask("lgt_rot*", files);
      LT_EQ(accepted, 60);
      LT_EQ(kept, 60);
      LT_CHECK(files > 2);
   }
   //--- чтение журнала во время работы
   LT_KNOWN("file: log can be read while the handler keeps it open", "F-04");
   {
      CFileHandler* h = new CFileHandler("lgt_shared.log", false, true);
      h.Handle(CreateLogRecord(LOG_INFO, "one", "lgt"));
      LT_EQ(LtReadLines("lgt_shared.log", lines), 1);
      delete h;
   }
   LtCleanup();
}
