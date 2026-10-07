//+------------------------------------------------------------------+
//|                                                   TestMacros.mqh |
//| Макросы: все раскрываются, пишут место вызова                    |
//| LOGIF здесь нет: он не собирается (F-30), появится с LOG-BL-09.  |
//+------------------------------------------------------------------+
int g_lt_evaluations = 0;

string LtCounted(const string text)
{
   g_lt_evaluations++;
   return text;
}

void TestMacros()
{
   SLoggerConfig quiet;
   quiet.console_output = false;
   quiet.level = LOG_INFO;
   CLoggerFactory::Shutdown();
   CLoggerFactory::SetDefaultConfig(quiet);

   LT_CASE("macros: default logger macros carry the call site");
   {
      CCaptureHandler cap;
      CLoggerFactory::GetLogger("default").AddHandler(GetPointer(cap));
      LOGTRACE("t"); LOGDEBUG("d");
      LT_EQ(cap.m_count, 0);
      LOGINFO("info text"); int line = __LINE__;
      LT_EQ(cap.m_count, 1);
      LT_EQ(cap.m_last.message, "info text");
      LT_EQ(cap.m_last.source_line, line);
      LT_EQ(cap.m_last.source_file, __FILE__);
      LT_EQ(cap.m_last.function_name, __FUNCTION__);
      LOGWARN("w");
      LT_EQ((int)cap.m_last.level, (int)LOG_WARN);
      LOGERROR_CODE("e", 4756);
      LT_EQ((int)cap.m_last.level, (int)LOG_ERROR);
      LT_EQ(cap.m_last.error_code, 4756);
      LOGFATAL_CODE("f", 5004);
      LT_EQ((int)cap.m_last.level, (int)LOG_FATAL);
      LT_EQ(cap.m_last.error_code, 5004);
      ResetLastError();
      LOGERROR("no error pending");
      LT_EQ(cap.m_last.error_code, 0);
      LOGFATAL("no error pending");
      LT_EQ(cap.m_count, 6);
      CLoggerFactory::Shutdown();
   }
   LT_CASE("macros: named logger macros");
   {
      CCaptureHandler cap;
      CLogger* lg = LtBareLogger("lgt_named");
      lg.AddHandler(GetPointer(cap));
      LOGTRACE_N("lgt_named", "t"); LOGDEBUG_N("lgt_named", "d"); LOGINFO_N("lgt_named", "i");
      LOGWARN_N("lgt_named", "w"); LOGERROR_N("lgt_named", "e"); LOGFATAL_N("lgt_named", "f");
      LT_EQ(cap.m_count, 6);
      LT_EQ(cap.m_last.logger_name, "lgt_named");
      CLoggerFactory::Shutdown();
   }
   LT_CASE("macros: helpers expand and log");
   {
      CCaptureHandler cap;
      CLogger* lg = CLoggerFactory::GetLogger("default");
      lg.SetLevel(LOG_TRACE);
      lg.AddHandler(GetPointer(cap));
      LOGFUNCTION_ENTRY();
      LOGFUNCTION_EXIT();
      LT_EQ(cap.m_count, 2);
      LOGEXECUTION_TIME("timed", { Sleep(1); });
      LT_EQ(cap.m_count, 3);
      LT_CHECK(StringFind(cap.m_last.message, "timed [Duration:") == 0);
      LOGTRADE_OPEN("EURUSD", ORDER_TYPE_BUY, 0.1, 1.2345);
      LT_CHECK(StringFind(cap.m_last.message, "Trade opened: EURUSD ORDER_TYPE_BUY 0.10 lots at 1.23450") == 0);
      LOGTRADE_CLOSE("EURUSD", 0.1, 1.2355, 10.0);
      LT_CHECK(StringFind(cap.m_last.message, "Trade closed: EURUSD 0.10 lots at 1.23550, profit: 10.00") == 0);
      CLoggerFactory::Shutdown();
   }
   LT_KNOWN("macros: message is not built when the level is off", "F-15");
   {
      CCaptureHandler cap;
      CLoggerFactory::GetLogger("default").AddHandler(GetPointer(cap));
      g_lt_evaluations = 0;
      LOGTRACE(LtCounted("costly"));
      LOGDEBUG(LtCounted("costly"));
      LT_EQ(cap.m_count, 0);
      LT_EQ(g_lt_evaluations, 0);
      LOGINFO(LtCounted("needed"));
      LT_EQ(g_lt_evaluations, 1);
      CLoggerFactory::Shutdown();
   }

   SLoggerConfig def;
   CLoggerFactory::SetDefaultConfig(def);
}
