//+------------------------------------------------------------------+
//|                                                    TesterLog.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
//| Журналы проходов оптимизации — в терминал.                      |
//|                                                                  |
//| Проход идёт на агенте (в том числе на другой машине), его файлы |
//| и журнал остаются там. Здесь итог прохода уходит в терминал     |
//| кадром: число записей по уровням и последние строки из           |
//| CMemoryHandler. В терминале кадры складываются в базу SQLite.   |
//|                                                                  |
//| В советнике:                                                     |
//|   double OnTester()      { LogTesterSend(logger, memory); ... } |
//|   void OnTesterInit()    { collector.Open("MyEA_passes.db"); }  |
//|   void OnTesterPass()    { collector.Collect(); }               |
//|   void OnTesterDeinit()  { collector.Close(); }                 |
//| Пример — Examples\ExpertSkeleton.mq5.                            |
//|                                                                  |
//| Не подключается из Logger.mqh: #include <Logger\Tester\TesterLog.mqh> |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "..\Logger.mqh"
#include "..\Handlers\MemoryHandler.mqh"

// Идентификатор кадров библиотеки (FrameAdd / FrameFilter)
#define LOGGER_FRAME_ID 20261007

//+------------------------------------------------------------------+
//| Вызвать в OnTester(): отправить итог журнала прохода в терминал  |
//|   logger — чьи счётчики отправить;                              |
//|   memory — строки (можно NULL: только счётчики);                |
//|   value  — число, которое будет записано рядом (например,       |
//|            результат OnTester).                                  |
//| Вне оптимизации ничего не делает и возвращает false.            |
//+------------------------------------------------------------------+
bool LogTesterSend(CLogger* logger, CMemoryHandler* memory = NULL, double value = 0.0)
{
   if(logger == NULL || !MQLInfoInteger(MQL_OPTIMIZATION))
      return false;

   // Первая строка — счётчики, дальше — строки журнала
   string text = StringFormat("%I64d,%I64d,%I64d,%I64d,%I64d,%I64d,%I64d",
                              logger.Count(LOG_TRACE), logger.Count(LOG_DEBUG), logger.Count(LOG_INFO),
                              logger.Count(LOG_WARN), logger.Count(LOG_ERROR), logger.Count(LOG_FATAL),
                              memory != NULL ? memory.Overwritten() : 0);
   if(memory != NULL && memory.Count() > 0)
      text += "\n" + memory.Text("\n");

   uchar data[];
   int size = StringToCharArray(text, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(size > 1)
      ArrayResize(data, size - 1);   // без завершающего нуля

   return FrameAdd(logger.Name(), LOGGER_FRAME_ID, value, data);
}

//+------------------------------------------------------------------+
//| Приём кадров в терминале и запись в базу                        |
//|   passes     — проход, входные параметры, число записей по      |
//|                уровням;                                          |
//|   pass_lines — строки журнала прохода.                          |
//+------------------------------------------------------------------+
class CTesterLogCollector
{
private:
   int               m_db;                // Database handle
   string            m_path;              // Database file in MQL5\Files of the terminal
   int               m_passes;            // Frames stored
   int               m_passes_with_errors; // Passes with ERROR or FATAL records
   int               m_failed;            // Frames that could not be stored

   string            Escape(string text) { StringReplace(text, "'", "''"); return text; }

public:
                     CTesterLogCollector(void) : m_db(INVALID_HANDLE), m_path(""), m_passes(0),
                                                 m_passes_with_errors(0), m_failed(0) {}
                    ~CTesterLogCollector(void) { Close(); }

   bool              Open(string database_path, bool clear = true);   // OnTesterInit
   int               Collect();                                        // OnTesterPass, returns frames stored
   void              Close();                                          // OnTesterDeinit

   int               Passes() const { return m_passes; }
   int               PassesWithErrors() const { return m_passes_with_errors; }
   int               Failed() const { return m_failed; }
   string            Path() const { return m_path; }
};

//+------------------------------------------------------------------+
//| Открыть базу; clear — начать с пустых таблиц                    |
//+------------------------------------------------------------------+
bool CTesterLogCollector::Open(string database_path, bool clear = true)
{
   Close();
   m_path = database_path;
   m_passes = 0;
   m_passes_with_errors = 0;
   m_failed = 0;

   m_db = DatabaseOpen(m_path, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
   if(m_db == INVALID_HANDLE)
   {
      PrintFormat("Logger: cannot open %s for pass logs, error %d", m_path, GetLastError());
      return false;
   }

   bool ok = DatabaseExecute(m_db, "CREATE TABLE IF NOT EXISTS passes ("
                                   "pass INTEGER PRIMARY KEY, logger TEXT, value REAL, inputs TEXT, "
                                   "trace INTEGER, debug INTEGER, info INTEGER, warn INTEGER, error INTEGER, "
                                   "fatal INTEGER, lines_lost INTEGER)") &&
             DatabaseExecute(m_db, "CREATE TABLE IF NOT EXISTS pass_lines ("
                                   "pass INTEGER NOT NULL, n INTEGER NOT NULL, line TEXT NOT NULL, "
                                   "PRIMARY KEY (pass, n))");
   if(ok && clear)
      ok = DatabaseExecute(m_db, "DELETE FROM passes") && DatabaseExecute(m_db, "DELETE FROM pass_lines");
   if(!ok)
   {
      PrintFormat("Logger: cannot prepare %s for pass logs, error %d", m_path, GetLastError());
      Close();
   }
   return ok;
}

//+------------------------------------------------------------------+
//| Забрать пришедшие кадры библиотеки                              |
//+------------------------------------------------------------------+
int CTesterLogCollector::Collect()
{
   if(m_db == INVALID_HANDLE)
      return 0;

   ulong pass;
   string name;
   long id;
   double value;
   uchar data[];
   int stored = 0;

   while(FrameNext(pass, name, id, value, data))
   {
      if(id != LOGGER_FRAME_ID)
         continue;

      string text = CharArrayToString(data, 0, WHOLE_ARRAY, CP_UTF8);
      string lines[];
      int count = StringSplit(text, '\n', lines);
      string counts[];
      if(count < 1 || StringSplit(lines[0], ',', counts) != 7)
      {
         m_failed++;
         continue;
      }

      string params[];
      uint params_count = 0;
      string inputs = "";
      if(FrameInputs(pass, params, params_count))
      {
         for(uint i = 0; i < params_count; i++)
            inputs += (i > 0 ? "; " : "") + params[i];
      }

      bool ok = DatabaseTransactionBegin(m_db);
      ok = ok && DatabaseExecute(m_db, StringFormat(
              "INSERT OR REPLACE INTO passes (pass, logger, value, inputs, trace, debug, info, warn, error, fatal, lines_lost) "
              "VALUES (%I64u, '%s', %.10g, '%s', %s, %s, %s, %s, %s, %s, %s)",
              pass, Escape(name), value, Escape(inputs),
              counts[0], counts[1], counts[2], counts[3], counts[4], counts[5], counts[6]));
      ok = ok && DatabaseExecute(m_db, StringFormat("DELETE FROM pass_lines WHERE pass = %I64u", pass));
      for(int i = 1; i < count && ok; i++)
         ok = DatabaseExecute(m_db, StringFormat("INSERT INTO pass_lines (pass, n, line) VALUES (%I64u, %d, '%s')",
                                                 pass, i, Escape(lines[i])));
      if(ok)
         ok = DatabaseTransactionCommit(m_db);
      else
         DatabaseTransactionRollback(m_db);

      if(!ok)
      {
         m_failed++;
         continue;
      }
      stored++;
      m_passes++;
      if(StringToInteger(counts[4]) + StringToInteger(counts[5]) > 0)
         m_passes_with_errors++;
   }
   return stored;
}

//+------------------------------------------------------------------+
//| Закрыть базу                                                    |
//+------------------------------------------------------------------+
void CTesterLogCollector::Close()
{
   if(m_db != INVALID_HANDLE)
   {
      DatabaseClose(m_db);
      m_db = INVALID_HANDLE;
   }
}
