//+------------------------------------------------------------------+
//|                                                   LogTestKit.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
//| Проверки для тестов библиотеки. Вывод в журнал «Эксперты»:      |
//|   «<случай> passed» / «<случай> failed», итог «N of M passed»   |
//| (формат штатных тестов MetaQuotes; его разбирает mql-test unit). |
//| Случай с пометкой известной ошибки (LT_KNOWN) должен падать:    |
//| пока падает — считается пройденным и печатается «known»;        |
//| перестал падать — «failed», пометку пора снять.                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"

#include "..\Core\Interfaces.mqh"

//+------------------------------------------------------------------+
//| Набор проверок одного тест-скрипта                               |
//+------------------------------------------------------------------+
class CLogTestKit
{
private:
   string            m_case;            // текущий случай
   string            m_known;           // номер известной ошибки или ""
   int               m_cases;           // случаев всего
   int               m_failed;          // упавших случаев
   int               m_known_open;      // известных ошибок, которые ещё воспроизводятся
   int               m_checks_failed;   // упавших проверок в текущем случае

public:
                     CLogTestKit(void) : m_case(""), m_known(""), m_cases(0), m_failed(0),
                                         m_known_open(0), m_checks_failed(0) {}

   void              Begin(const string suite) { Print("Unit tests: ", suite); }

   void              Case(const string name, const string known = "")
   {
      EndCase();
      m_case = name;
      m_known = known;
      m_checks_failed = 0;
      m_cases++;
   }

   bool              Check(const bool cond, const string expr, const string file, const int line)
   {
      if(!cond)
      {
         m_checks_failed++;
         if(m_known == "")
            PrintFormat("%s: check failed: %s (%s:%d)", m_case, expr, file, line);
      }
      return cond;
   }

   void              EndCase(void)
   {
      if(m_case == "")
         return;
      if(m_known != "")
      {
         if(m_checks_failed > 0)
         {
            m_known_open++;
            PrintFormat("%s known (%s)", m_case, m_known);
         }
         else
         {
            m_failed++;
            PrintFormat("%s failed: marked as known (%s) but passes - remove the mark", m_case, m_known);
         }
      }
      else if(m_checks_failed > 0)
      {
         m_failed++;
         PrintFormat("%s failed", m_case);
      }
      else
         PrintFormat("%s passed", m_case);
      m_case = "";
   }

   int               Finish(void)
   {
      EndCase();
      if(m_known_open > 0)
         PrintFormat("known errors still open: %d", m_known_open);
      PrintFormat("%d of %d passed", m_cases - m_failed, m_cases);
      return m_failed;
   }
};

CLogTestKit LT;

#define LT_CASE(name)         LT.Case(name)
#define LT_KNOWN(name, ref)   LT.Case(name, ref)
#define LT_CHECK(cond)        LT.Check((cond), #cond, __FILE__, __LINE__)
#define LT_EQ(a, b)           LT.Check((a) == (b), #a " == " #b, __FILE__, __LINE__)

//+------------------------------------------------------------------+
//| Обработчик для тестов: считает записи и помнит их               |
//+------------------------------------------------------------------+
class CCaptureHandler : public ILogHandler
{
public:
   int               m_count;           // принято записей
   SLogRecord        m_last;            // последняя запись
   string            m_messages[];      // тексты по порядку
   int               m_flushes;         // вызовов Flush
   bool              m_closed;          // был Close

                     CCaptureHandler(void) : m_count(0), m_flushes(0), m_closed(false) {}

   virtual bool      Handle(const SLogRecord &record) override
   {
      m_count++;
      m_last = record;
      int n = ArraySize(m_messages);
      ArrayResize(m_messages, n + 1);
      m_messages[n] = record.message;
      return true;
   }
   virtual void      SetFormatter(ILogFormatter* formatter) override {}
   virtual void      SetFilter(ILogFilter* filter) override {}
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override {}
   virtual void      Flush() override { m_flushes++; }
   virtual void      Close() override { m_closed = true; }
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) override { return true; }
};

//+------------------------------------------------------------------+
//| Обработчик, который на каждую запись сам пишет в логгер         |
//+------------------------------------------------------------------+
class CRelayHandler : public CCaptureHandler
{
public:
   ILogger*          m_target;

                     CRelayHandler(void) : m_target(NULL) {}

   virtual bool      Handle(const SLogRecord &record) override
   {
      CCaptureHandler::Handle(record);
      if(m_target != NULL)
         m_target.Warn("relayed: " + record.message);
      return true;
   }
};

//+------------------------------------------------------------------+
//| Текст файла из MQL5\Files: UTF-16 (с BOM) или UTF-8              |
//+------------------------------------------------------------------+
bool LtReadText(const string name, string &text)
{
   text = "";
   int h = FileOpen(name, FILE_READ | FILE_BIN | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      return false;
   uchar b[];
   FileReadArray(h, b);
   FileClose(h);
   int n = ArraySize(b);
   if(n >= 2 && b[0] == 0xFF && b[1] == 0xFE)
   {
      ushort w[];
      int chars = (n - 2) / 2;
      ArrayResize(w, chars);
      for(int i = 0; i < chars; i++)
         w[i] = (ushort)(b[2 + 2 * i] | (b[3 + 2 * i] << 8));
      text = ShortArrayToString(w, 0, chars);
   }
   else
   {
      int off = (n >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) ? 3 : 0;
      text = CharArrayToString(b, off, n - off, CP_UTF8);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Файл начинается с метки UTF-16                                   |
//+------------------------------------------------------------------+
bool LtIsUtf16(const string name)
{
   int h = FileOpen(name, FILE_READ | FILE_BIN | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      return false;
   uchar b[];
   FileReadArray(h, b, 0, 2);
   FileClose(h);
   return ArraySize(b) >= 2 && b[0] == 0xFF && b[1] == 0xFE;
}

//+------------------------------------------------------------------+
//| Непустые строки файла; -1 — файл не открылся                    |
//+------------------------------------------------------------------+
int LtReadLines(const string name, string &lines[])
{
   ArrayResize(lines, 0);
   string text;
   if(!LtReadText(name, text))
      return -1;
   StringReplace(text, "\r", "");
   string parts[];
   int n = StringSplit(text, '\n', parts);
   for(int i = 0; i < n; i++)
   {
      if(StringLen(parts[i]) == 0)
         continue;
      int k = ArraySize(lines);
      ArrayResize(lines, k + 1);
      lines[k] = parts[i];
   }
   return ArraySize(lines);
}

//+------------------------------------------------------------------+
//| Число непустых строк во всех файлах по маске                    |
//+------------------------------------------------------------------+
int LtCountLinesByMask(const string mask, int &files)
{
   files = 0;
   int total = 0;
   string name;
   string names[];
   long h = FileFindFirst(mask, name);
   if(h == INVALID_HANDLE)
      return 0;
   do
   {
      int k = ArraySize(names);
      ArrayResize(names, k + 1);
      names[k] = name;
   }
   while(FileFindNext(h, name));
   FileFindClose(h);
   files = ArraySize(names);
   for(int i = 0; i < files; i++)
   {
      string lines[];
      int n = LtReadLines(names[i], lines);
      if(n > 0)
         total += n;
   }
   return total;
}

//+------------------------------------------------------------------+
//| Удалить файлы тестов (все начинаются с lgt_)                    |
//+------------------------------------------------------------------+
void LtCleanup(const string mask = "lgt_*")
{
   string name;
   string names[];
   long h = FileFindFirst(mask, name);
   if(h == INVALID_HANDLE)
      return;
   do
   {
      int k = ArraySize(names);
      ArrayResize(names, k + 1);
      names[k] = name;
   }
   while(FileFindNext(h, name));
   FileFindClose(h);
   for(int i = 0; i < ArraySize(names); i++)
      FileDelete(names[i]);
}

//+------------------------------------------------------------------+
//| Одно целое из базы (закрытой обработчиком); -1 — не прочитано   |
//+------------------------------------------------------------------+
long LtDbLong(const string path, const string sql)
{
   int db = DatabaseOpen(path, DATABASE_OPEN_READONLY);
   if(db == INVALID_HANDLE)
      return -1;
   long value = -1;
   int request = DatabasePrepare(db, sql);
   if(request != INVALID_HANDLE)
   {
      if(DatabaseRead(request))
         DatabaseColumnLong(request, 0, value);
      DatabaseFinalize(request);
   }
   DatabaseClose(db);
   return value;
}

//+------------------------------------------------------------------+
//| Одна строка из базы; "" — не прочитано                          |
//+------------------------------------------------------------------+
string LtDbText(const string path, const string sql)
{
   int db = DatabaseOpen(path, DATABASE_OPEN_READONLY);
   if(db == INVALID_HANDLE)
      return "";
   string value = "";
   int request = DatabasePrepare(db, sql);
   if(request != INVALID_HANDLE)
   {
      if(DatabaseRead(request))
         DatabaseColumnText(request, 0, value);
      DatabaseFinalize(request);
   }
   DatabaseClose(db);
   return value;
}

//+------------------------------------------------------------------+
//| Логгер без обработчиков, пропускает все уровни                  |
//+------------------------------------------------------------------+
CLogger* LtBareLogger(const string name, ENUM_LOG_LEVEL level = LOG_TRACE)
{
   SLoggerConfig cfg;
   cfg.name = name;
   cfg.console_output = false;
   cfg.level = level;
   return CLoggerFactory::CreateLogger(name, cfg);
}
