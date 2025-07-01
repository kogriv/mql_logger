//+------------------------------------------------------------------+
//|                                                  LevelFilter.mqh |
//|                                  Professional MQL5 Logger System |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Professional MQL5 Logger System"
#property link      ""
#property version   "1.00"
#property strict

#include "../Core/Interfaces.mqh"

//+------------------------------------------------------------------+
//| Level filter - filters messages by log level                   |
//+------------------------------------------------------------------+
class CLevelFilter : public ILogFilter
{
private:
   ENUM_LOG_LEVEL    m_min_level;        // Minimum level to allow
   ENUM_LOG_LEVEL    m_max_level;        // Maximum level to allow
   bool              m_enabled;          // Is filter enabled
   bool              m_use_range;        // Use level range instead of minimum
   bool              m_exclude_levels[6]; // Exclude specific levels
   
public:
                     CLevelFilter(ENUM_LOG_LEVEL min_level = LOG_TRACE, 
                                 ENUM_LOG_LEVEL max_level = LOG_FATAL);
                    ~CLevelFilter();
   
   // ILogFilter implementation
   virtual bool      ShouldLog(const SLogRecord &record) override;
   
   // Level filter specific methods
   void              SetMinLevel(ENUM_LOG_LEVEL level) { m_min_level = level; }
   ENUM_LOG_LEVEL    GetMinLevel() const { return m_min_level; }
   void              SetMaxLevel(ENUM_LOG_LEVEL level) { m_max_level = level; }
   ENUM_LOG_LEVEL    GetMaxLevel() const { return m_max_level; }
   void              SetLevelRange(ENUM_LOG_LEVEL min_level, ENUM_LOG_LEVEL max_level);
   void              SetUseRange(bool use_range) { m_use_range = use_range; }
   bool              GetUseRange() const { return m_use_range; }
   void              Enable(bool enabled) { m_enabled = enabled; }
   bool              IsEnabled() const { return m_enabled; }
   
   // Level exclusion methods
   void              ExcludeLevel(ENUM_LOG_LEVEL level);
   void              IncludeLevel(ENUM_LOG_LEVEL level);
   void              ClearExclusions();
   bool              IsLevelExcluded(ENUM_LOG_LEVEL level) const;
   
   // Convenience methods
   void              SetOnlyErrors();      // Only ERROR and FATAL
   void              SetOnlyWarningsAndErrors(); // WARN, ERROR, FATAL
   void              SetInfoAndAbove();    // INFO, WARN, ERROR, FATAL
   void              SetDebugAndAbove();   // DEBUG, INFO, WARN, ERROR, FATAL
   void              SetAllLevels();       // All levels
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLevelFilter::CLevelFilter(ENUM_LOG_LEVEL min_level = LOG_TRACE, 
                          ENUM_LOG_LEVEL max_level = LOG_FATAL) :
   m_min_level(min_level),
   m_max_level(max_level),
   m_enabled(true),
   m_use_range(false)
{
   ClearExclusions();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLevelFilter::~CLevelFilter()
{
}

//+------------------------------------------------------------------+
//| Check if record should be logged                               |
//+------------------------------------------------------------------+
bool CLevelFilter::ShouldLog(const SLogRecord &record)
{
   if(!m_enabled)
      return true;
   
   // Check if level is excluded
   if(IsLevelExcluded(record.level))
      return false;
   
   // Check level range
   if(m_use_range)
   {
      return (record.level >= m_min_level && record.level <= m_max_level);
   }
   else
   {
      return (record.level >= m_min_level);
   }
}

//+------------------------------------------------------------------+
//| Set level range                                                 |
//+------------------------------------------------------------------+
void CLevelFilter::SetLevelRange(ENUM_LOG_LEVEL min_level, ENUM_LOG_LEVEL max_level)
{
   m_min_level = min_level;
   m_max_level = max_level;
   m_use_range = true;
}

//+------------------------------------------------------------------+
//| Exclude specific level                                          |
//+------------------------------------------------------------------+
void CLevelFilter::ExcludeLevel(ENUM_LOG_LEVEL level)
{
   if(level >= LOG_TRACE && level <= LOG_FATAL)
   {
      m_exclude_levels[level] = true;
   }
}

//+------------------------------------------------------------------+
//| Include specific level (remove from exclusions)               |
//+------------------------------------------------------------------+
void CLevelFilter::IncludeLevel(ENUM_LOG_LEVEL level)
{
   if(level >= LOG_TRACE && level <= LOG_FATAL)
   {
      m_exclude_levels[level] = false;
   }
}

//+------------------------------------------------------------------+
//| Clear all level exclusions                                     |
//+------------------------------------------------------------------+
void CLevelFilter::ClearExclusions()
{
   for(int i = 0; i < 6; i++)
   {
      m_exclude_levels[i] = false;
   }
}

//+------------------------------------------------------------------+
//| Check if level is excluded                                      |
//+------------------------------------------------------------------+
bool CLevelFilter::IsLevelExcluded(ENUM_LOG_LEVEL level) const
{
   if(level >= LOG_TRACE && level <= LOG_FATAL)
   {
      return m_exclude_levels[level];
   }
   return false;
}

//+------------------------------------------------------------------+
//| Set filter to only show errors                                 |
//+------------------------------------------------------------------+
void CLevelFilter::SetOnlyErrors()
{
   m_min_level = LOG_ERROR;
   m_max_level = LOG_FATAL;
   m_use_range = true;
   ClearExclusions();
}

//+------------------------------------------------------------------+
//| Set filter to show warnings and errors                         |
//+------------------------------------------------------------------+
void CLevelFilter::SetOnlyWarningsAndErrors()
{
   m_min_level = LOG_WARN;
   m_max_level = LOG_FATAL;
   m_use_range = true;
   ClearExclusions();
}

//+------------------------------------------------------------------+
//| Set filter to show info and above                              |
//+------------------------------------------------------------------+
void CLevelFilter::SetInfoAndAbove()
{
   m_min_level = LOG_INFO;
   m_use_range = false;
   ClearExclusions();
}

//+------------------------------------------------------------------+
//| Set filter to show debug and above                             |
//+------------------------------------------------------------------+
void CLevelFilter::SetDebugAndAbove()
{
   m_min_level = LOG_DEBUG;
   m_use_range = false;
   ClearExclusions();
}

//+------------------------------------------------------------------+
//| Set filter to show all levels                                  |
//+------------------------------------------------------------------+
void CLevelFilter::SetAllLevels()
{
   m_min_level = LOG_TRACE;
   m_use_range = false;
   ClearExclusions();
}
