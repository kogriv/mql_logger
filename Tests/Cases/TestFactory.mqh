//+------------------------------------------------------------------+
//|                                                  TestFactory.mqh |
//| Фабрика: реестр, имена, профили                                  |
//+------------------------------------------------------------------+
void TestFactory()
{
   LT_CASE("factory: logger is created once and found by name");
   {
      CLoggerFactory::Shutdown();
      LT_EQ(CLoggerFactory::GetLoggerCount(), 0);
      CLogger* a = LtBareLogger("lgt_fa");
      LT_CHECK(a != NULL);
      LT_CHECK(CLoggerFactory::GetLogger("lgt_fa") == a);
      LT_EQ(CLoggerFactory::GetLoggerCount(), 1);
      LT_EQ(a.Name(), "lgt_fa");
      LtBareLogger("lgt_fb");
      LT_EQ(CLoggerFactory::GetLoggerCount(), 2);
      CLoggerFactory::RemoveLogger("lgt_fa");
      LT_EQ(CLoggerFactory::GetLoggerCount(), 1);
      CLoggerFactory::Shutdown();
      LT_EQ(CLoggerFactory::GetLoggerCount(), 0);
   }
   LT_CASE("factory: configuration builds handlers");
   {
      SLoggerConfig cfg;
      cfg.name = "lgt_fcfg";
      cfg.console_output = false;
      cfg.file_output = true;
      cfg.log_file = "lgt_fcfg.log";
      cfg.database_output = true;
      cfg.database_file = "lgt_fcfg.db";
      cfg.level = LOG_DEBUG;
      CLogger* lg = CLoggerFactory::CreateLogger("lgt_fcfg", cfg);
      LT_CHECK(lg != NULL);
      LT_EQ(lg.GetHandlerCount(), 2);
      LT_CHECK(lg.IsEnabled(LOG_DEBUG));
      LT_CHECK(!lg.IsEnabled(LOG_TRACE));
      lg.Info("to both");
      CLoggerFactory::Shutdown();
      string lines[];
      LT_EQ(LtReadLines("lgt_fcfg.log", lines), 1);
      LT_EQ(LtDbLong("lgt_fcfg.db", "SELECT COUNT(*) FROM logs"), 1);
   }
   LT_CASE("factory: set level and enable for all loggers");
   {
      CLogger* a = LtBareLogger("lgt_ga");
      CLogger* b = LtBareLogger("lgt_gb");
      CLoggerFactory::SetGlobalLevel(LOG_ERROR);
      LT_CHECK(!a.IsEnabled(LOG_WARN) && !b.IsEnabled(LOG_WARN));
      LT_CHECK(a.IsEnabled(LOG_ERROR) && b.IsEnabled(LOG_ERROR));
      CLoggerFactory::EnableAll(false);
      LT_CHECK(!a.IsEnabled(LOG_FATAL) && !b.IsEnabled(LOG_FATAL));
      CLoggerFactory::Shutdown();
   }
   LT_CASE("factory: dot is allowed in a logger name");
   {
      CLogger* lg = LtBareLogger("lgt.module");
      LT_CHECK(lg != NULL);
      if(lg != NULL)
         LT_EQ(lg.Name(), "lgt.module");
      CLoggerFactory::Shutdown();
   }
   LT_CASE("factory: invalid name gives NULL, not the default logger");
   {
      SLoggerConfig quiet;
      quiet.console_output = false;
      CLoggerFactory::SetDefaultConfig(quiet);
      LT_CHECK(CLoggerFactory::GetLogger("bad name!") == NULL);
      LT_CHECK(CLoggerFactory::GetLogger("") == NULL);
      LT_CHECK(LtBareLogger("bad/name") == NULL);
      LT_CHECK(CLoggerFactory::CreateProfileLogger("bad name", LOGGER_PROFILE_PERFORMANCE) == NULL);
      LT_EQ(CLoggerFactory::GetLoggerCount(), 0);
      //--- макросы с несуществующим логгером ничего не делают
      LOGINFO_N("bad name!", "nowhere");
      SLoggerConfig def;
      CLoggerFactory::SetDefaultConfig(def);
      CLoggerFactory::Shutdown();
   }
   LT_CASE("factory: creating a logger again returns the existing one");
   {
      CCaptureHandler cap;
      CLogger* first = LtBareLogger("lgt_again", LOG_WARN);
      first.AddHandler(GetPointer(cap));
      LT_CHECK(CLoggerFactory::Exists("lgt_again"));
      LT_CHECK(!CLoggerFactory::Exists("lgt_never"));
      SLoggerConfig other;
      other.level = LOG_TRACE;
      other.file_output = true;
      other.log_file = "lgt_again.log";
      LT_CHECK(CLoggerFactory::CreateLogger("lgt_again", other) == first);
      LT_CHECK(CLoggerFactory::CreateProfileLogger("lgt_again", LOGGER_PROFILE_DEBUG) == first);
      LT_EQ(first.GetHandlerCount(), 1);
      LT_CHECK(!first.IsEnabled(LOG_INFO));
      LT_CHECK(!FileIsExist("lgt_again.log"));
      LT_CHECK(!FileIsExist("lgt_again.db"));
      //--- другая конфигурация — после удаления
      CLoggerFactory::RemoveLogger("lgt_again");
      CLogger* second = CLoggerFactory::CreateLogger("lgt_again", other);
      LT_CHECK(second != NULL && second.IsEnabled(LOG_TRACE));
      CLoggerFactory::Shutdown();
   }
   LT_CASE("factory: removing a logger closes its handlers, shared ones stay");
   {
      CLogger* db = CLoggerFactory::CreateDatabaseLogger("lgt_rm", "lgt_rm.db", LOG_INFO);
      db.Info("one");
      LT_CHECK(!FileDelete("lgt_rm.db"));          // база открыта обработчиком
      ResetLastError();
      CLoggerFactory::RemoveLogger("lgt_rm");
      LT_CHECK(FileDelete("lgt_rm.db"));           // закрыта вместе с логгером
      //--- общий обработчик
      CFileHandler* shared = CLoggerFactory::CreateFileHandler("lgt_shared2.log", false, true);
      CLogger* a = LtBareLogger("lgt_sa");
      CLogger* b = LtBareLogger("lgt_sb");
      a.AddHandler(shared);
      b.AddHandler(shared);
      a.Info("from a");
      CLoggerFactory::RemoveLogger("lgt_sa");
      b.Info("from b");
      string lines[];
      LT_EQ(LtReadLines("lgt_shared2.log", lines), 2);
      CLoggerFactory::RemoveAllLoggers();
      LT_EQ(CLoggerFactory::GetLoggerCount(), 0);
      LT_CHECK(FileDelete("lgt_shared2.log"));
      CLoggerFactory::Shutdown();
   }
   LT_CASE("factory: profiles build the expected handlers");
   {
      CLogger* perf = CLoggerFactory::CreateProfileLogger("lgt_perf", LOGGER_PROFILE_PERFORMANCE);
      LT_CHECK(perf != NULL);
      LT_EQ(perf.GetHandlerCount(), 1);
      CLogger* dbg = CLoggerFactory::CreateProfileLogger("lgt_dbg", LOGGER_PROFILE_DEBUG);
      LT_EQ(dbg.GetHandlerCount(), 2);
      dbg.Trace("trace goes to the database");
      CLoggerFactory::Shutdown();
      LT_EQ(LtDbLong("lgt_dbg.db", "SELECT COUNT(*) FROM logs WHERE level=0"), 1);
   }
   LT_CASE("factory: profile sets the logger level to the lowest handler level");
   {
      CLogger* perf = CLoggerFactory::CreateProfileLogger("lgt_perf2", LOGGER_PROFILE_PERFORMANCE);
      LT_CHECK(!perf.IsEnabled(LOG_TRACE));
      LT_CHECK(!perf.IsEnabled(LOG_INFO));
      LT_CHECK(perf.IsEnabled(LOG_WARN));
      CLogger* prod = CLoggerFactory::CreateProfileLogger("lgt_prod", LOGGER_PROFILE_PRODUCTION);
      LT_CHECK(!prod.IsEnabled(LOG_DEBUG));
      LT_CHECK(prod.IsEnabled(LOG_INFO));
      CLogger* dbg = CLoggerFactory::CreateProfileLogger("lgt_dbg2", LOGGER_PROFILE_DEBUG);
      LT_CHECK(dbg.IsEnabled(LOG_TRACE));
      CLoggerFactory::Shutdown();
      LT_EQ(LtDbLong("lgt_prod.db", "SELECT COUNT(*) FROM logs"), 1);
   }
   LT_CASE("factory: composite logger passes database settings to its own handler");
   {
      CLogger* lg = CLoggerFactory::CreateCompositeLogger("lgt_comp", false, "", "lgt_comp.db", false, 50);
      LT_CHECK(lg != NULL);
      LT_EQ(lg.GetHandlerCount(), 1);
      ResetLastError();
      for(int i = 0; i < 120; i++)
         lg.Info("rec");
      LT_EQ(GetLastError(), 0);
      CLoggerFactory::Shutdown();
      LT_EQ(LtDbLong("lgt_comp.db", "SELECT COUNT(*) FROM logs"), 120);
   }
   LT_CASE("factory: default logger is cached and recreated after shutdown");
   {
      SLoggerConfig quiet;
      quiet.console_output = false;
      CLoggerFactory::SetDefaultConfig(quiet);
      CLogger* d1 = CLoggerFactory::Default();
      LT_CHECK(d1 != NULL);
      LT_CHECK(CLoggerFactory::Default() == d1);
      LT_CHECK(CLoggerFactory::GetLogger("default") == d1);
      CLoggerFactory::RemoveLogger("default");
      LT_EQ(CLoggerFactory::GetLoggerCount(), 0);
      LT_CHECK(CLoggerFactory::Default() != NULL);
      LT_EQ(CLoggerFactory::GetLoggerCount(), 1);
      SLoggerConfig def;
      CLoggerFactory::SetDefaultConfig(def);
      CLoggerFactory::Shutdown();
   }
   LtCleanup();
}
