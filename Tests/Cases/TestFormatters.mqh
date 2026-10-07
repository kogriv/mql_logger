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
   LT_CASE("format: message text is not altered");
   {
      CSimpleFormatter s("%level% %message%");
      LT_EQ(s.Format(odd), "INFO a  b   c %file% %level%");
      CDetailedFormatter d("%logger% %message%");
      LT_EQ(d.Format(odd), "mylog a  b   c %file% %level%");
   }
   LT_CASE("format: simple formatter fills %logger%");
   {
      CSimpleFormatter f("%logger%: %message%");
      LT_EQ(f.Format(rec), "mylog: hello");
   }
   LT_CASE("format: same record formats to the same string");
   {
      CDetailedFormatter f;
      string s1 = f.Format(rec);
      Sleep(50);
      string s2 = f.Format(rec);
      Sleep(50);
      string s3 = f.Format(rec);
      LT_CHECK(s1 == s2 && s2 == s3);
   }

   LT_CASE("format: empty fields leave no stray spaces, unknown names stay");
   {
      CDetailedFormatter d;
      string s = d.Format(rec);
      LT_EQ(StringSubstr(s, StringLen(s) - 18), "hello [F.mq5:7:Fn]");
      SLogRecord bare = CreateLogRecord(LOG_WARN, "tail  ", "mylog");
      s = d.Format(bare);
      LT_EQ(StringSubstr(s, StringLen(s) - 13), "mylog: tail  ");
      CSimpleFormatter f("%timestamp% [%level%] %message% 100% %nosuch% %error%");
      f.SetShowTimestamp(false);
      LT_EQ(f.Format(rec), "[INFO] hello 100% %nosuch%");
      CSimpleFormatter hidden("%logger%: %message%");
      hidden.SetShowLoggerName(false);
      LT_EQ(hidden.Format(rec), ": hello");
   }
   LT_CASE("format: time fields");
   {
      CSimpleFormatter f("%seq%|%elapsed%|%localtime%");
      SLogRecord a = CreateLogRecord(LOG_INFO, "a", "t");
      SLogRecord b = CreateLogRecord(LOG_INFO, "b", "t");
      LT_EQ(b.sequence, a.sequence + 1);
      LT_CHECK(b.elapsed_us >= a.elapsed_us);
      LT_CHECK(a.time_local > 0);
      string parts[];
      LT_EQ(StringSplit(f.Format(a), '|', parts), 3);
      if(ArraySize(parts) == 3)
      {
         LT_EQ(parts[0], IntegerToString((long)a.sequence));
         LT_EQ(parts[1], StringFormat("%.6f", a.elapsed_us / 1000000.0));
         LT_EQ(parts[2], TimeToString(a.time_local, TIME_DATE | TIME_SECONDS));
      }
   }
   LT_CASE("format: multiline layout");
   {
      CDetailedFormatter m("", true);
      string s = m.Format(err);
      LT_CHECK(StringFind(s, "=== ERROR ===\nTime: ") == 0);
      LT_CHECK(StringFind(s, "\nMessage: boom\nSource: F.mq5:9 in Fn()\nError: 42\n================") > 0);
   }
   LT_CASE("format: default line of handlers without a formatter");
   {
      string s = LogFormatDefault(err);
      LT_EQ(StringFind(s, TimeToString(err.timestamp, TIME_DATE | TIME_SECONDS) + " [ERROR] mylog: boom [F.mq5:9:Fn] [Error: 42]"), 0);
      SLogRecord bare = CreateLogRecord(LOG_INFO, "a  b", "");
      LT_EQ(LogFormatDefault(bare), TimeToString(bare.timestamp, TIME_DATE | TIME_SECONDS) + " [INFO] a  b");
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
      CSubstringFilter f(false);
      LT_CHECK(f.ShouldLog(rec));
      f.AddIncludePattern("HELL");
      LT_CHECK(f.ShouldLog(rec));
      LT_CHECK(!f.ShouldLog(err));
      f.AddIncludePattern("boom");
      f.AddExcludePattern("oo");
      LT_CHECK(!f.ShouldLog(err));
      CSubstringFilter cs(true);
      cs.AddIncludePattern("HELL");
      LT_CHECK(!cs.ShouldLog(rec));
      // прежнее имя класса и метода фабрики по-прежнему работают
      CRegexFilter* old = CLoggerFactory::CreateRegexFilter(false);
      old.AddExcludePattern("BOOM");
      LT_CHECK(!old.ShouldLog(err));
      CSubstringFilter* fresh = CLoggerFactory::CreateSubstringFilter();
      LT_CHECK(fresh != NULL && fresh.ShouldLog(err));
      CLoggerFactory::Shutdown();
   }
}
