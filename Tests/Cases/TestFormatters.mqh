//+------------------------------------------------------------------+
//|                                               TestFormatters.mqh |
//| Форматтеры и фильтры                                             |
//+------------------------------------------------------------------+
void TestFormatters()
{
   SLogRecord rec = CreateLogRecord(LOG_INFO, "hello", "mylog", "F.mq5", 7, "Fn", 0);
   SLogRecord err = CreateLogRecord(LOG_ERROR, "boom", "mylog", "F.mq5", 9, "Fn", 42);
   SLogRecord odd = CreateLogRecord(LOG_INFO, "a  b   c %file% %level%", "mylog", "F.mq5", 7, "Fn", 0);

   LT_CASE("format: simple default pattern");
   {
      CSimpleFormatter f;
      string s = f.Format(rec);
      LT_CHECK(StringFind(s, "[INFO] hello") > 0);
      LT_EQ(StringFind(s, TimeToString(rec.timestamp, TIME_DATE | TIME_SECONDS)), 0);
   }
   LT_CASE("format: custom pattern fields");
   {
      CSimpleFormatter f("%level%|%file%|%line%|%function%|%error%|%message%");
      LT_EQ(f.Format(err), "ERROR|F.mq5|9|Fn|42|boom");
   }
   LT_CASE("format: detailed has source and error code");
   {
      CDetailedFormatter f;
      string s = f.Format(err);
      LT_CHECK(StringFind(s, "mylog: boom") > 0);
      LT_CHECK(StringFind(s, "[F.mq5:9:Fn]") > 0);
      LT_CHECK(StringFind(s, "[Error: 42]") > 0);
      LT_CHECK(StringFind(f.Format(rec), "Error") < 0);
   }
   LT_KNOWN("format: message text is not altered", "F-20, F-21");
   {
      CSimpleFormatter s("%level% %message%");
      LT_EQ(s.Format(odd), "INFO a  b   c %file% %level%");
      CDetailedFormatter d("%logger% %message%");
      LT_EQ(d.Format(odd), "mylog a  b   c %file% %level%");
   }
   LT_KNOWN("format: simple formatter fills %logger%", "F-22");
   {
      CSimpleFormatter f("%logger%: %message%");
      LT_EQ(f.Format(rec), "mylog: hello");
   }
   LT_KNOWN("format: same record formats to the same string", "F-18");
   {
      CDetailedFormatter f;
      string s1 = f.Format(rec);
      Sleep(50);
      string s2 = f.Format(rec);
      Sleep(50);
      string s3 = f.Format(rec);
      LT_CHECK(s1 == s2 && s2 == s3);
   }

   LT_CASE("filter: level minimum, range, exclusion");
   {
      CLevelFilter f(LOG_WARN);
      LT_CHECK(!f.ShouldLog(rec));
      LT_CHECK(f.ShouldLog(err));
      f.SetLevelRange(LOG_DEBUG, LOG_INFO);
      LT_CHECK(f.ShouldLog(rec));
      LT_CHECK(!f.ShouldLog(err));
      f.SetAllLevels();
      f.ExcludeLevel(LOG_ERROR);
      LT_CHECK(f.ShouldLog(rec));
      LT_CHECK(!f.ShouldLog(err));
      f.Enable(false);
      LT_CHECK(f.ShouldLog(err));
   }
   LT_CASE("filter: text include and exclude");
   {
      CRegexFilter f(false);
      LT_CHECK(f.ShouldLog(rec));
      f.AddIncludePattern("HELL");
      LT_CHECK(f.ShouldLog(rec));
      LT_CHECK(!f.ShouldLog(err));
      f.AddIncludePattern("boom");
      f.AddExcludePattern("oo");
      LT_CHECK(!f.ShouldLog(err));
      CRegexFilter cs(true);
      cs.AddIncludePattern("HELL");
      LT_CHECK(!cs.ShouldLog(rec));
   }
}
