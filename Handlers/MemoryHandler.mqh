//+------------------------------------------------------------------+
//|                                                MemoryHandler.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "..\Core\Interfaces.mqh"

//+------------------------------------------------------------------+
//| Memory handler - keeps the last records as formatted lines      |
//|                                                                  |
//| Кольцевой буфер на capacity строк: новые вытесняют самые старые. |
//| Ничего не пишет на диск. Нужен там, где файл недоступен или      |
//| бесполезен: проход оптимизации на агенте — строки уходят в       |
//| терминал кадром (Tester\TesterLog.mqh).                          |
//+------------------------------------------------------------------+
class CMemoryHandler : public ILogHandler
{
private:
   ILogFormatter*    m_formatter;         // Message formatter
   ILogFilter*       m_filter;            // Message filter
   ENUM_LOG_LEVEL    m_level;             // Minimum level
   bool              m_enabled;           // Is handler enabled

   string            m_lines[];           // Ring buffer
   int               m_capacity;          // Buffer size
   int               m_start;             // Index of the oldest line
   int               m_count;             // Lines in the buffer
   long              m_total;             // Records accepted since creation or Clear()

public:
                     CMemoryHandler(int capacity = 200, ENUM_LOG_LEVEL level = LOG_WARN);
                    ~CMemoryHandler() {}

   // ILogHandler implementation
   virtual bool      Handle(const SLogRecord &record) override;
   virtual void      SetFormatter(ILogFormatter* formatter) override { m_formatter = formatter; }
   virtual void      SetFilter(ILogFilter* filter) override { m_filter = filter; }
   virtual void      SetLevel(ENUM_LOG_LEVEL level) override { m_level = level; }
   virtual void      Flush() override {}
   virtual void      Close() override {}
   virtual bool      IsEnabled(ENUM_LOG_LEVEL level) override { return m_enabled && level >= m_level; }

   // Memory-specific methods
   int               Count() const { return m_count; }                 // lines kept
   int               Capacity() const { return m_capacity; }
   long              Total() const { return m_total; }                 // records accepted
   long              Overwritten() const { return m_total - m_count; } // records pushed out of the buffer
   string            Line(int index) const;                            // 0 - the oldest kept line
   string            Text(string separator = "\n") const;              // all kept lines, oldest first
   void              Clear();
   void              Enable(bool enabled) { m_enabled = enabled; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMemoryHandler::CMemoryHandler(int capacity = 200, ENUM_LOG_LEVEL level = LOG_WARN) :
   m_formatter(NULL),
   m_filter(NULL),
   m_level(level),
   m_enabled(true),
   m_capacity(capacity < 1 ? 1 : capacity),
   m_start(0),
   m_count(0),
   m_total(0)
{
   ArrayResize(m_lines, m_capacity);
}

//+------------------------------------------------------------------+
//| Handle log record                                               |
//+------------------------------------------------------------------+
bool CMemoryHandler::Handle(const SLogRecord &record)
{
   if(!IsEnabled(record.level))
      return false;
   if(m_filter != NULL && !m_filter.ShouldLog(record))
      return false;

   string line = (m_formatter != NULL) ? m_formatter.Format(record) : LogFormatDefault(record);

   if(m_count < m_capacity)
   {
      m_lines[(m_start + m_count) % m_capacity] = line;
      m_count++;
   }
   else
   {
      m_lines[m_start] = line;
      m_start = (m_start + 1) % m_capacity;
   }
   m_total++;
   return true;
}

//+------------------------------------------------------------------+
//| Kept line by index, "" if out of range                          |
//+------------------------------------------------------------------+
string CMemoryHandler::Line(int index) const
{
   if(index < 0 || index >= m_count)
      return "";
   return m_lines[(m_start + index) % m_capacity];
}

//+------------------------------------------------------------------+
//| All kept lines as one text                                      |
//+------------------------------------------------------------------+
string CMemoryHandler::Text(string separator = "\n") const
{
   string text = "";
   for(int i = 0; i < m_count; i++)
   {
      if(i > 0)
         text += separator;
      text += m_lines[(m_start + i) % m_capacity];
   }
   return text;
}

//+------------------------------------------------------------------+
//| Forget everything                                               |
//+------------------------------------------------------------------+
void CMemoryHandler::Clear()
{
   m_start = 0;
   m_count = 0;
   m_total = 0;
}
