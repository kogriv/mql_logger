//+------------------------------------------------------------------+
//|                                               ExpertSkeleton.mq5 |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
//| Каркас советника с логгером: профиль — входным параметром,      |
//| указатель на логгер передаётся в классы, запись — макросами      |
//| LOG…_TO. В оптимизации итог журнала каждого прохода (счётчики и |
//| строки от WARN) уходит в терминал кадром и складывается в базу   |
//| MQL5\Files\ExpertSkeleton_passes.db. Сделок не совершает.        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include <Logger\Logger.mqh>
#include <Logger\Tester\TesterLog.mqh>

input ENUM_LOGGER_PROFILE InpLogProfile = LOGGER_PROFILE_PERFORMANCE;   // Профиль журнала
input int                 InpDemoWarnings = 3;                          // Пример: сколько предупреждений записать при запуске

//+------------------------------------------------------------------+
//| Класс со своим указателем на логгер                              |
//+------------------------------------------------------------------+
class CBarCounter
{
private:
   ILogger*          m_logger;
   datetime          m_last_bar;
   int               m_bars;

public:
                     CBarCounter(void) : m_logger(NULL), m_last_bar(0), m_bars(0) {}
   void              SetLogger(ILogger* logger) { m_logger = logger; }

   void              OnTick(void)
   {
      datetime bar = iTime(_Symbol, _Period, 0);
      // При выключенном TRACE эта строка стоит одной проверки: StringFormat не вызывается
      LOGTRACE_TO(m_logger, StringFormat("tick %.5f", SymbolInfoDouble(_Symbol, SYMBOL_BID)));
      if(bar == m_last_bar)
         return;
      m_last_bar = bar;
      m_bars++;
      LOGDEBUG_TO(m_logger, StringFormat("Новый бар %s, всего %d", TimeToString(bar), m_bars));
      if(m_bars % 100 == 0)
         LOGINFO_TO(m_logger, StringFormat("Пройдено %d баров", m_bars));
   }
};

CLogger*            g_logger = NULL;
CMemoryHandler*     g_memory = NULL;      // последние строки от WARN — для кадра прохода
CBarCounter         g_counter;
CTesterLogCollector g_collector;          // приём кадров в терминале

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Повторный OnInit (смена периода графика) вернёт тот же логгер
   g_logger = CLoggerFactory::CreateProfileLogger("ExpertSkeleton", InpLogProfile);
   if(g_logger == NULL)
   {
      Print("Логгер не создан");
      return INIT_FAILED;
   }
   if(g_memory == NULL)
   {
      g_memory = CLoggerFactory::CreateMemoryHandler(100, LOG_WARN);
      g_logger.AddHandler(g_memory);
   }
   g_counter.SetLogger(g_logger);
   LOGINFO_TO(g_logger, StringFormat("Запуск на %s %s", _Symbol, EnumToString(_Period)));
   for(int i = 0; i < InpDemoWarnings; i++)
      LOGWARN_TO(g_logger, StringFormat("Пример предупреждения %d из %d", i + 1, InpDemoWarnings));
   if(InpDemoWarnings > 0 && InpDemoWarnings % 4 == 0)
      LOGERROR_CODE_TO(g_logger, "Пример ошибки: её проход будет виден в терминале", 4756);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LOGINFO_TO(g_logger, StringFormat("Останов, причина %d", reason));
   g_counter.SetLogger(NULL);
   g_logger = NULL;
   g_memory = NULL;
   ShutdownLogging();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   g_counter.OnTick();
}

//+------------------------------------------------------------------+
//| Конец прохода на агенте: итог журнала — кадром в терминал        |
//+------------------------------------------------------------------+
double OnTester()
{
   double result = (double)InpDemoWarnings;
   LogTesterSend(g_logger, g_memory, result);
   return result;
}

//+------------------------------------------------------------------+
//| Оптимизация началась (выполняется в терминале)                   |
//+------------------------------------------------------------------+
void OnTesterInit()
{
   g_collector.Open("ExpertSkeleton_passes.db");
}

//+------------------------------------------------------------------+
//| Пришли кадры проходов (выполняется в терминале)                  |
//+------------------------------------------------------------------+
void OnTesterPass()
{
   g_collector.Collect();
}

//+------------------------------------------------------------------+
//| Оптимизация закончилась (выполняется в терминале)                |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
   g_collector.Collect();
   PrintFormat("Журналы проходов: %d, из них с ошибками %d, не разобрано кадров %d — %s",
               g_collector.Passes(), g_collector.PassesWithErrors(), g_collector.Failed(), g_collector.Path());
   g_collector.Close();
}
