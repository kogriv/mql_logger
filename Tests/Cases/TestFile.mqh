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
   LT_CASE("file: buffered records appear after Flush");
   {
      CFileHandler* h = new CFileHandler("lgt_buf.log", false, false);
      h.Handle(CreateLogRecord(LOG_INFO, "one", "lgt"));
      h.Handle(CreateLogRecord(LOG_INFO, "two", "lgt"));
      LT_EQ(LtReadLines("lgt_buf.log", lines), 0);
      h.Flush();
      LT_EQ(LtReadLines("lgt_buf.log", lines), 2);
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
   LT_CASE("file: append keeps records of the previous session");
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
   LT_CASE("file: rotation loses no records");
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
   LT_CASE("file: log can be read while the handler keeps it open");
   {
      CFileHandler* h = new CFileHandler("lgt_shared.log", false, true);
      h.Handle(CreateLogRecord(LOG_INFO, "one", "lgt"));
      LT_EQ(LtReadLines("lgt_shared.log", lines), 1);
      delete h;
   }
   //--- имена архивов
   LT_CASE("file: archives are numbered, earlier ones are never overwritten");
   {
      for(int run = 0; run < 2; run++)
      {
         CFileHandler* h = new CFileHandler("lgt_arc.v2.log", true, true);
         h.SetMaxFileSize(200);
         for(int i = 0; i < 20; i++)
            h.Handle(CreateLogRecord(LOG_INFO, StringFormat("run %d line %03d", run, i), "lgt"));
         delete h;
      }
      int files = 0;
      LT_EQ(LtCountLinesByMask("lgt_arc*", files), 40);
      LT_CHECK(FileIsExist("lgt_arc.v2.1.log"));
      LT_CHECK(FileIsExist("lgt_arc.v2.2.log"));
      LT_CHECK(!FileIsExist("lgt_arc.1.v2.log"));
   }
   LT_CASE("file: archive limit keeps only the newest files");
   {
      CFileHandler* h = new CFileHandler("lgt_lim.log", false, true);
      h.SetMaxFileSize(200);
      h.SetMaxArchives(2);
      for(int i = 0; i < 60; i++)
         h.Handle(CreateLogRecord(LOG_INFO, StringFormat("line %03d", i), "lgt"));
      delete h;
      int files = 0;
      LtCountLinesByMask("lgt_lim*", files);
      LT_EQ(files, 3);
      LT_CHECK(!FileIsExist("lgt_lim.1.log"));
      LT_EQ(LtReadLines("lgt_lim.log", lines) > 0, true);
      if(ArraySize(lines) > 0)
         LT_CHECK(StringFind(lines[ArraySize(lines) - 1], "line 059") >= 0);
   }
   //--- кодировка
   LT_CASE("file: UTF-8 by default, UTF-16 on request");
   {
      CFileHandler* h = new CFileHandler("lgt_utf8.log", false, true);
      h.Handle(CreateLogRecord(LOG_INFO, "текст", "lgt"));
      delete h;
      LT_CHECK(!LtIsUtf16("lgt_utf8.log"));
      LT_EQ(LtReadLines("lgt_utf8.log", lines), 1);
      if(ArraySize(lines) == 1)
         LT_CHECK(StringFind(lines[0], "текст") >= 0);
      h = new CFileHandler("lgt_utf16.log", false, true, false, true);
      h.Handle(CreateLogRecord(LOG_INFO, "текст", "lgt"));
      delete h;
      LT_CHECK(LtIsUtf16("lgt_utf16.log"));
      LT_EQ(LtReadLines("lgt_utf16.log", lines), 1);
      if(ArraySize(lines) == 1)
         LT_CHECK(StringFind(lines[0], "текст") >= 0);
   }
   //--- файл не открывается
   LT_CASE("file: unopenable file drops records and counts them");
   {
      CFileHandler* h = new CFileHandler("lgt_bad|name?.log", true, true);
      LT_CHECK(!h.IsOpen());
      LT_CHECK(!h.Handle(CreateLogRecord(LOG_INFO, "one", "lgt")));
      LT_CHECK(!h.Handle(CreateLogRecord(LOG_INFO, "two", "lgt")));
      LT_EQ(h.DroppedCount(), 2);
      delete h;
      ResetLastError();
   }
   LtCleanup();
}
