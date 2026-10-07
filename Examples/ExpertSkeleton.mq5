//+------------------------------------------------------------------+
//|                                               ExpertSkeleton.mq5 |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
//| Каркас советника с логгером: профиль — входным параметром,      |
//| указатель на логгер передаётся в классы, запись — макросами      |
//| LOG…_TO. Сделок не совершает.                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include <Logger\Logger.mqh>

input ENUM_LOGGER_PROFILE InpLogProfile = LOGGER_PROFILE_PERFORMANCE;   // Профиль журнала

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

ILogger*    g_logger = NULL;
CBarCounter g_counter;

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
   g_counter.SetLogger(g_logger);
   LOGINFO_TO(g_logger, StringFormat("Запуск на %s %s", _Symbol, EnumToString(_Period)));
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
   ShutdownLogging();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   g_counter.OnTick();
}
