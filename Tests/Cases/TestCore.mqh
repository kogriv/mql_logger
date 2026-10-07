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
