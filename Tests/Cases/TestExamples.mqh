//+------------------------------------------------------------------+
//|                                                 TestExamples.mqh |
//| Пример из README выполняется и оставляет то, что обещает         |
//+------------------------------------------------------------------+
#define LOGGER_EXAMPLE_NO_ENTRY
#include "..\..\Examples\QuickStart.mq5"

void TestExamples()
{
   LT_CASE("examples: QuickStart runs and writes its file and database");
   {
      CLoggerFactory::Shutdown();
      FileDelete("quickstart.log");
      FileDelete("quickstart.db");
      QuickStart();
      LT_EQ(CLoggerFactory::GetLoggerCount(), 0);          // пример закрывает журналирование сам
      string lines[];
      LT_EQ(LtReadLines("quickstart.log", lines), 3);
      if(ArraySize(lines) == 3)
      {
         LT_CHECK(StringFind(lines[0], "[DEBUG] quickstart: ") > 0);
         LT_CHECK(StringFind(lines[2], "[ERROR] quickstart: ") > 0);
         LT_CHECK(StringFind(lines[2], "[Error: ") > 0);
      }
      LT_EQ(LtDbLong("quickstart.db", "SELECT COUNT(*) FROM logs"), 3);
      LT_EQ(LtDbLong("quickstart.db", "SELECT COUNT(*) FROM logs WHERE level = 4 AND error_code <> 0"), 1);
      LT_CHECK(FileDelete("quickstart.log"));
      LT_CHECK(FileDelete("quickstart.db"));
      FileDelete("quickstart.db-shm");
      FileDelete("quickstart.db-wal");
      ResetLastError();
   }
}
