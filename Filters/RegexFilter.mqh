//+------------------------------------------------------------------+
//|                                                   RegexFilter.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

#include "..\Core\Interfaces.mqh"

//+------------------------------------------------------------------+
//| Regex filter - filters messages by content patterns            |
//+------------------------------------------------------------------+
class CRegexFilter : public ILogFilter
{
private:
   string            m_include_patterns[];  // Patterns to include
   string            m_exclude_patterns[];  // Patterns to exclude
   bool              m_enabled;             // Is filter enabled
   bool              m_case_sensitive;      // Case sensitive matching
   bool              m_match_logger_name;   // Apply patterns to logger names too
   bool              m_match_message_only;  // Apply patterns only to message content
   
   bool              MatchesPattern(string text, string pattern, bool case_sensitive);
   bool              MatchesAnyPattern(string text, const string &patterns[], bool case_sensitive);
   string            PrepareText(string text, bool case_sensitive);

public:
                     CRegexFilter(bool case_sensitive = true);
                    ~CRegexFilter();
   
   // ILogFilter implementation
   virtual bool      ShouldLog(const SLogRecord &record) override;
   
   // Regex filter specific methods
   void              AddIncludePattern(string pattern);
   void              AddExcludePattern(string pattern);
   void              RemoveIncludePattern(string pattern);
   void              RemoveExcludePattern(string pattern);
   void              ClearIncludePatterns();
   void              ClearExcludePatterns();
   void              ClearAllPatterns();
   
   int               GetIncludePatternCount() const;
   int               GetExcludePatternCount() const;
   string            GetIncludePattern(int index) const;
   string            GetExcludePattern(int index) const;
   
   void              SetCaseSensitive(bool case_sensitive) { m_case_sensitive = case_sensitive; }
   bool              GetCaseSensitive() const { return m_case_sensitive; }
   void              SetMatchLoggerName(bool match_logger) { m_match_logger_name = match_logger; }
   bool              GetMatchLoggerName() const { return m_match_logger_name; }
   void              SetMatchMessageOnly(bool message_only) { m_match_message_only = message_only; }
   bool              GetMatchMessageOnly() const { return m_match_message_only; }
   void              Enable(bool enabled) { m_enabled = enabled; }
   bool              IsEnabled() const { return m_enabled; }
   
   // Convenience methods
   void              SetIncludeOnly(string pattern);
   void              SetExcludeOnly(string pattern);
   void              AddTradePatterns();      // Patterns for trade-related messages
   void              AddErrorPatterns();      // Patterns for error messages
   void              AddDebugPatterns();      // Patterns for debug messages
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRegexFilter::CRegexFilter(bool case_sensitive = true) :
   m_enabled(true),
   m_case_sensitive(case_sensitive),
   m_match_logger_name(false),
   m_match_message_only(true)
{
   ArrayResize(m_include_patterns, 0);
   ArrayResize(m_exclude_patterns, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRegexFilter::~CRegexFilter()
{
}

//+------------------------------------------------------------------+
//| Check if record should be logged                               |
//+------------------------------------------------------------------+
bool CRegexFilter::ShouldLog(const SLogRecord &record)
{
   if(!m_enabled)
      return true;
   
   // If no patterns are set, allow all messages
   if(ArraySize(m_include_patterns) == 0 && ArraySize(m_exclude_patterns) == 0)
      return true;
   
   // Prepare text to match against
   string match_text = "";
   
   if(m_match_message_only)
   {
      match_text = record.message;
   }
   else
   {
      match_text = record.message;
      if(m_match_logger_name && StringLen(record.logger_name) > 0)
      {
         match_text += " " + record.logger_name;
      }
      
      // Optionally include source information
      if(StringLen(record.source_file) > 0)
      {
         match_text += " " + record.source_file + " " + record.function_name;
      }
   }
   
   // Check exclude patterns first (they take precedence)
   if(ArraySize(m_exclude_patterns) > 0)
   {
      if(MatchesAnyPattern(match_text, m_exclude_patterns, m_case_sensitive))
      {
         return false; // Exclude this message
      }
   }
   
   // Check include patterns
   if(ArraySize(m_include_patterns) > 0)
   {
      return MatchesAnyPattern(match_text, m_include_patterns, m_case_sensitive);
   }
   
   // If we have exclude patterns but no include patterns, and message wasn't excluded, include it
   return true;
}

//+------------------------------------------------------------------+
//| Add include pattern                                             |
//+------------------------------------------------------------------+
void CRegexFilter::AddIncludePattern(string pattern)
{
   if(StringLen(pattern) > 0)
   {
      int size = ArraySize(m_include_patterns);
      ArrayResize(m_include_patterns, size + 1);
      m_include_patterns[size] = pattern;
   }
}

//+------------------------------------------------------------------+
//| Add exclude pattern                                             |
//+------------------------------------------------------------------+
void CRegexFilter::AddExcludePattern(string pattern)
{
   if(StringLen(pattern) > 0)
   {
      int size = ArraySize(m_exclude_patterns);
      ArrayResize(m_exclude_patterns, size + 1);
      m_exclude_patterns[size] = pattern;
   }
}

//+------------------------------------------------------------------+
//| Remove include pattern                                          |
//+------------------------------------------------------------------+
void CRegexFilter::RemoveIncludePattern(string pattern)
{
   for(int i = 0; i < ArraySize(m_include_patterns); i++)
   {
      if(m_include_patterns[i] == pattern)
      {
         // Shift remaining elements
         for(int j = i; j < ArraySize(m_include_patterns) - 1; j++)
         {
            m_include_patterns[j] = m_include_patterns[j + 1];
         }
         ArrayResize(m_include_patterns, ArraySize(m_include_patterns) - 1);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Remove exclude pattern                                          |
//+------------------------------------------------------------------+
void CRegexFilter::RemoveExcludePattern(string pattern)
{
   for(int i = 0; i < ArraySize(m_exclude_patterns); i++)
   {
      if(m_exclude_patterns[i] == pattern)
      {
         // Shift remaining elements
         for(int j = i; j < ArraySize(m_exclude_patterns) - 1; j++)
         {
            m_exclude_patterns[j] = m_exclude_patterns[j + 1];
         }
         ArrayResize(m_exclude_patterns, ArraySize(m_exclude_patterns) - 1);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Clear include patterns                                          |
//+------------------------------------------------------------------+
void CRegexFilter::ClearIncludePatterns()
{
   ArrayResize(m_include_patterns, 0);
}

//+------------------------------------------------------------------+
//| Clear exclude patterns                                          |
//+------------------------------------------------------------------+
void CRegexFilter::ClearExcludePatterns()
{
   ArrayResize(m_exclude_patterns, 0);
}

//+------------------------------------------------------------------+
//| Clear all patterns                                              |
//+------------------------------------------------------------------+
void CRegexFilter::ClearAllPatterns()
{
   ClearIncludePatterns();
   ClearExcludePatterns();
}

//+------------------------------------------------------------------+
//| Get include pattern count                                       |
//+------------------------------------------------------------------+
int CRegexFilter::GetIncludePatternCount() const
{
   return ArraySize(m_include_patterns);
}

//+------------------------------------------------------------------+
//| Get exclude pattern count                                       |
//+------------------------------------------------------------------+
int CRegexFilter::GetExcludePatternCount() const
{
   return ArraySize(m_exclude_patterns);
}

//+------------------------------------------------------------------+
//| Get include pattern by index                                   |
//+------------------------------------------------------------------+
string CRegexFilter::GetIncludePattern(int index) const
{
   if(index >= 0 && index < ArraySize(m_include_patterns))
   {
      return m_include_patterns[index];
   }
   return "";
}

//+------------------------------------------------------------------+
//| Get exclude pattern by index                                   |
//+------------------------------------------------------------------+
string CRegexFilter::GetExcludePattern(int index) const
{
   if(index >= 0 && index < ArraySize(m_exclude_patterns))
   {
      return m_exclude_patterns[index];
   }
   return "";
}

//+------------------------------------------------------------------+
//| Set include only pattern (clears all and adds one)            |
//+------------------------------------------------------------------+
void CRegexFilter::SetIncludeOnly(string pattern)
{
   ClearAllPatterns();
   AddIncludePattern(pattern);
}

//+------------------------------------------------------------------+
//| Set exclude only pattern (clears all and adds one)            |
//+------------------------------------------------------------------+
void CRegexFilter::SetExcludeOnly(string pattern)
{
   ClearAllPatterns();
   AddExcludePattern(pattern);
}

//+------------------------------------------------------------------+
//| Add common trade-related patterns                              |
//+------------------------------------------------------------------+
void CRegexFilter::AddTradePatterns()
{
   AddIncludePattern("trade");
   AddIncludePattern("order");
   AddIncludePattern("buy");
   AddIncludePattern("sell");
   AddIncludePattern("open");
   AddIncludePattern("close");
   AddIncludePattern("profit");
   AddIncludePattern("loss");
}

//+------------------------------------------------------------------+
//| Add common error patterns                                       |
//+------------------------------------------------------------------+
void CRegexFilter::AddErrorPatterns()
{
   AddIncludePattern("error");
   AddIncludePattern("failed");
   AddIncludePattern("exception");
   AddIncludePattern("invalid");
   AddIncludePattern("timeout");
}

//+------------------------------------------------------------------+
//| Add common debug patterns                                       |
//+------------------------------------------------------------------+
void CRegexFilter::AddDebugPatterns()
{
   AddIncludePattern("debug");
   AddIncludePattern("trace");
   AddIncludePattern("entry");
   AddIncludePattern("exit");
   AddIncludePattern("value");
}

//+------------------------------------------------------------------+
//| Check if text matches pattern (simple pattern matching)       |
//+------------------------------------------------------------------+
bool CRegexFilter::MatchesPattern(string text, string pattern, bool case_sensitive)
{
   string search_text = PrepareText(text, case_sensitive);
   string search_pattern = PrepareText(pattern, case_sensitive);
   
   // Simple pattern matching - check if pattern is contained in text
   // For full regex support, this would need to be extended with proper regex engine
   return StringFind(search_text, search_pattern) >= 0;
}

//+------------------------------------------------------------------+
//| Check if text matches any pattern in array                     |
//+------------------------------------------------------------------+
bool CRegexFilter::MatchesAnyPattern(string text, const string &patterns[], bool case_sensitive)
{
   for(int i = 0; i < ArraySize(patterns); i++)
   {
      if(MatchesPattern(text, patterns[i], case_sensitive))
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Prepare text for matching (case conversion if needed)          |
//+------------------------------------------------------------------+
string CRegexFilter::PrepareText(string text, bool case_sensitive)
{
   if(case_sensitive)
   {
      return text;
   }
   else
   {
      string result = text;
      StringToLower(result);  // Исправлено: StringLower -> StringToLower
      return result;
   }
}
