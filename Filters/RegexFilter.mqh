//+------------------------------------------------------------------+
//|                                                  RegexFilter.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"

#include "SubstringFilter.mqh"

//+------------------------------------------------------------------+
//| Устарело: прежнее имя CSubstringFilter. Регулярных выражений    |
//| фильтр никогда не понимал — он ищет подстроку. Оставлено, чтобы  |
//| собирался старый код; в новом — CSubstringFilter.                |
//+------------------------------------------------------------------+
class CRegexFilter : public CSubstringFilter
{
public:
                     CRegexFilter(bool case_sensitive = true) : CSubstringFilter(case_sensitive) {}
};
