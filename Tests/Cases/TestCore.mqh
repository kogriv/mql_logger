//+------------------------------------------------------------------+
//|                                                     TestCore.mqh |
//| Ядро: уровни, запись, обработчики, вложенные записи              |
//+------------------------------------------------------------------+
void TestCore()
{
   //--- уровни
   LT_CASE("core: level cuts lower records");
   {
      CCaptureHandler cap;
      CLogger* lg = LtBareLogger("lgt_core_lvl", LOG_INFO);
      LT_CHECK(lg != NULL);
      lg.AddHandler(GetPointer(cap));
      lg.Trace("t"); lg.Debug("d"); lg.Info("i"); lg.Warn("w"); lg.Error("e"); lg.Fatal("f");
      LT_EQ(cap.m_count, 4);
      LT_CHECK(!lg.IsEnabled(LOG_DEBUG));
      LT_CHECK(lg.IsEnabled(LOG_INFO));
      lg.SetLevel(LOG_ERROR);
      lg.Warn("w2"); lg.Error("e2");
      LT_EQ(cap.m_count, 5);
      lg.Enable(false);
      lg.Fatal("f2");
      LT_EQ(cap.m_count, 5);
      LT_CHECK(!lg.IsEnabled(LOG_FATAL));
      CLoggerFactory::Shutdown();
   }
   //--- поля записи
   LT_CASE("core: record carries all fields");
   {
      CCaptureHandler cap;
      CLogger* lg = LtBareLogger("lgt_core_rec");
      lg.AddHandler(GetPointer(cap));
      lg.Log(LOG_ERROR, "text  with   spaces", 42, "File.mq5", 7, "Fn");
      LT_EQ(cap.m_count, 1);
      LT_EQ((int)cap.m_last.level, (int)LOG_ERROR);
      LT_EQ(cap.m_last.message, "text  with   spaces");
      LT_EQ(cap.m_last.logger_name, "lgt_core_rec");
      LT_EQ(cap.m_last.source_file, "File.mq5");
      LT_EQ(cap.m_last.source_line, 7);
      LT_EQ(cap.m_last.function_name, "Fn");
      LT_EQ(cap.m_last.error_code, 42);
      lg.Error("short form", 5004);
      LT_EQ(cap.m_last.error_code, 5004);
      LT_EQ(cap.m_last.source_file, "");
      CLoggerFactory::Shutdown();
   }
   //--- несколько обработчиков
   LT_CASE("core: several handlers, remove, flush");
   {
      CCaptureHandler a, b;
      CLogger* lg = LtBareLogger("lgt_core_multi");
      lg.AddHandler(GetPointer(a));
      lg.AddHandler(GetPointer(b));
      LT_EQ(lg.GetHandlerCount(), 2);
      lg.Info("one");
      LT_EQ(a.m_count, 1);
      LT_EQ(b.m_count, 1);
      lg.Flush();
      LT_EQ(a.m_flushes, 1);
      LT_EQ(b.m_flushes, 1);
      lg.RemoveHandler(GetPointer(a));
      lg.Info("two");
      LT_EQ(a.m_count, 1);
      LT_EQ(b.m_count, 2);
      LT_EQ(lg.GetHandlerCount(), 1);
      CLoggerFactory::Shutdown();
      // обработчик создан не фабрикой: логгер и фабрика его не закрывают
      LT_CHECK(!b.m_closed);
   }
   //--- счётчики по уровням
   LT_CASE("core: record counters by level");
   {
      CLogger* lg = LtBareLogger("lgt_core_cnt", LOG_INFO);
      lg.Debug("below the logger level - not counted");
      lg.Info("i"); lg.Info("i"); lg.Warn("w"); lg.Error("e", 1);
      LT_EQ(lg.Count(LOG_DEBUG), 0);
      LT_EQ(lg.Count(LOG_INFO), 2);
      LT_EQ(lg.Count(LOG_WARN), 1);
      LT_EQ(lg.Count(LOG_ERROR), 1);
      LT_EQ(lg.Count(LOG_FATAL), 0);
      lg.ResetCounts();
      LT_EQ(lg.Count(LOG_INFO), 0);
      CLoggerFactory::Shutdown();
   }
   //--- обработчик в память
   LT_CASE("core: memory handler keeps the last lines");
   {
      CMemoryHandler* mem = CLoggerFactory::CreateMemoryHandler(3, LOG_WARN);
      CLogger* lg = LtBareLogger("lgt_core_mem");
      lg.AddHandler(mem);
      lg.Info("below the handler level");
      LT_EQ(mem.Count(), 0);
      lg.Warn("one"); lg.Error("two", 7);
      LT_EQ(mem.Count(), 2);
      LT_EQ(mem.Overwritten(), 0);
      LT_CHECK(StringFind(mem.Line(0), "[WARN] lgt_core_mem: one") > 0);
      LT_CHECK(StringFind(mem.Line(1), "two [Error: 7]") > 0);
      lg.Warn("three"); lg.Warn("four"); lg.Warn("five");
      LT_EQ(mem.Count(), 3);
      LT_EQ(mem.Total(), 5);
      LT_EQ(mem.Overwritten(), 2);
      LT_CHECK(StringFind(mem.Line(0), "three") > 0);
      LT_CHECK(StringFind(mem.Line(2), "five") > 0);
      LT_EQ(mem.Line(3), "");
      string parts[];
      LT_EQ(StringSplit(mem.Text("\n"), '\n', parts), 3);
      mem.SetFormatter(CLoggerFactory::CreateSimpleFormatter("%level%:%message%"));
      lg.Warn("six");
      LT_EQ(mem.Line(2), "WARN:six");
      mem.Clear();
      LT_EQ(mem.Count(), 0);
      LT_EQ(mem.Text(), "");
      CLoggerFactory::Shutdown();
   }
   //--- запись из обработчика в другой логгер
   LT_CASE("core: record written from a handler reaches another logger");
   {
      CRelayHandler relay;
      CCaptureHandler sink;
      CLogger* src = LtBareLogger("lgt_core_src");
      CLogger* dst = LtBareLogger("lgt_core_dst");
      relay.m_target = dst;
      src.AddHandler(GetPointer(relay));
      dst.AddHandler(GetPointer(sink));
      src.Info("x");
      LT_EQ(relay.m_count, 1);
      LT_EQ(sink.m_count, 1);
      CLoggerFactory::Shutdown();
   }
   //--- запись из обработчика в свой же логгер не зацикливается
   LT_CASE("core: handler writing to its own logger does not loop");
   {
      CRelayHandler relay;
      CLogger* lg = LtBareLogger("lgt_core_self");
      relay.m_target = lg;
      lg.AddHandler(GetPointer(relay));
      lg.Info("x");
      LT_EQ(relay.m_count, LOGGER_MAX_DEPTH);
      LT_EQ(lg.DroppedCount(), 1);
      lg.Info("y");
      LT_EQ(relay.m_count, 2 * LOGGER_MAX_DEPTH);
      LT_EQ(lg.DroppedCount(), 2);
      CLoggerFactory::Shutdown();
   }
}
