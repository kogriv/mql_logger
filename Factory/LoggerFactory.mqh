//+------------------------------------------------------------------+
//|                                               LoggerFactory.mqh |
//|                                           Copyright 2025, kogriv |
//|                             https://www.mql5.com/ru/users/kogriv |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kogriv"
#property link      "https://www.mql5.com/ru/users/kogriv"
#property version   "1.00"
#property strict

#include "..\Core\Logger.mqh"
#include "..\Handlers\ConsoleHandler.mqh"
#include "..\Handlers\FileHandler.mqh"
#include "..\Handlers\SqliteHandler.mqh"
#include "..\Formatters\SimpleFormatter.mqh"
#include "..\Formatters\DetailedFormatter.mqh"
#include "..\Filters\LevelFilter.mqh"
#include "..\Filters\RegexFilter.mqh"
#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Logger configuration structure                                  |
//+------------------------------------------------------------------+
struct SLoggerConfig
{
   string            name;                // Logger name
   ENUM_LOG_LEVEL    level;               // Minimum level
   bool              enabled;             // Is enabled
   bool              console_output;      // Enable console output
   bool              file_output;         // Enable file output
   bool              database_output;     // Enable database output
   string            log_file;            // Log file path
   string            database_file;       // Database file path
   string            format_pattern;      // Format pattern
   bool              detailed_format;     // Use detailed formatter
   bool              auto_flush;          // Auto flush handlers
   int               flush_interval;      // Flush interval in seconds
   
   // Constructor with defaults
   SLoggerConfig() : name("default"),
                    level(LOG_INFO),
                    enabled(true),
                    console_output(true),
                    file_output(false),
                    database_output(false),
                    log_file(""),
                    database_file(""),
                    format_pattern(""),
                    detailed_format(false),
                    auto_flush(false),
                    flush_interval(60) {}
};

//+------------------------------------------------------------------+
//| Logger factory - creates and manages loggers                   |
//+------------------------------------------------------------------+
class CLoggerFactory
{
private:
   static CArrayObj  s_loggers;           // Registry of created loggers
   static CArrayObj  s_handlers;          // Registry of created handlers
   static CArrayObj  s_formatters;        // Registry of created formatters
   static CArrayObj  s_filters;           // Registry of created filters
   static bool       s_initialized;       // Is factory initialized
   static SLoggerConfig s_default_config; // Default configuration
   
   static void       Initialize();
   static void       Cleanup();
   static CLogger*   FindLogger(string name);
   static void       RegisterLogger(CLogger* logger);
   static void       RegisterHandler(ILogHandler* handler);
   static void       RegisterFormatter(ILogFormatter* formatter);
   static void       RegisterFilter(ILogFilter* filter);

public:
   // Factory methods
   static CLogger*   GetLogger(string name = "default");
   static CLogger*   CreateLogger(string name, const SLoggerConfig &config);
   static CLogger*   CreateLogger(string name);
   
   // Handler creation methods
   static CConsoleHandler*   CreateConsoleHandler(bool use_print = true, bool show_alerts = false);
   static CFileHandler*      CreateFileHandler(string filename, bool append = true, bool auto_flush = false);
   static CSqliteHandler*    CreateSqliteHandler(string database_path, string table_name = "logs");
   
   // Formatter creation methods
   static CSimpleFormatter*  CreateSimpleFormatter(string pattern = "");
   static CDetailedFormatter* CreateDetailedFormatter(string pattern = "", bool multiline = false);
   
   // Filter creation methods
   static CLevelFilter*      CreateLevelFilter(ENUM_LOG_LEVEL min_level = LOG_TRACE);
   static CRegexFilter*      CreateRegexFilter(bool case_sensitive = true);
   
   // Configuration methods
   static void       SetDefaultConfig(const SLoggerConfig &config);
   static SLoggerConfig GetDefaultConfig();
   static void       ConfigureLogger(CLogger* logger, const SLoggerConfig &config);
   
   // Predefined logger configurations
   static CLogger*   CreateConsoleLogger(string name = "console", ENUM_LOG_LEVEL level = LOG_INFO);
   static CLogger*   CreateFileLogger(string name, string filename, ENUM_LOG_LEVEL level = LOG_INFO);
   static CLogger*   CreateDatabaseLogger(string name, string database_path, ENUM_LOG_LEVEL level = LOG_INFO);
   static CLogger*   CreateCompositeLogger(string name, bool console = true, string log_file = "", string db_file = "");
   
   // Management methods
   static void       FlushAll();
   static void       SetGlobalLevel(ENUM_LOG_LEVEL level);
   static void       EnableAll(bool enabled);
   static int        GetLoggerCount();
   static CLogger*   GetLoggerByIndex(int index);
   static void       RemoveLogger(string name);
   static void       RemoveAllLoggers();
   static void       Shutdown();
   
   // Utility methods
   static string     GenerateLogFileName(string base_name = "");
   static string     GenerateDbFileName(string base_name = "");
   static bool       IsValidLoggerName(string name);
};

// Static member initialization
CArrayObj CLoggerFactory::s_loggers;
CArrayObj CLoggerFactory::s_handlers;
CArrayObj CLoggerFactory::s_formatters;
CArrayObj CLoggerFactory::s_filters;
bool CLoggerFactory::s_initialized = false;
SLoggerConfig CLoggerFactory::s_default_config;

//+------------------------------------------------------------------+
//| Initialize factory                                              |
//+------------------------------------------------------------------+
void CLoggerFactory::Initialize()
{
   if(!s_initialized)
   {
      s_loggers.FreeMode(true);     // Auto-delete loggers
      s_handlers.FreeMode(true);    // Auto-delete handlers
      s_formatters.FreeMode(true);  // Auto-delete formatters
      s_filters.FreeMode(true);     // Auto-delete filters
      
      s_initialized = true;
   }
}

//+------------------------------------------------------------------+
//| Cleanup factory resources                                       |
//+------------------------------------------------------------------+
void CLoggerFactory::Cleanup()
{
   if(s_initialized)
   {
      s_loggers.Clear();
      s_handlers.Clear();
      s_formatters.Clear();
      s_filters.Clear();
      
      s_initialized = false;
   }
}

//+------------------------------------------------------------------+
//| Find existing logger by name                                   |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::FindLogger(string name)
{
   for(int i = 0; i < s_loggers.Total(); i++)
   {
      CObject* obj = s_loggers.At(i);
      CLogger* logger = dynamic_cast<CLogger*>(obj);
      if(logger != NULL && StringCompare(logger.Name(), name) == 0)
      {
         return logger;
      }
   }
   return NULL;
}

//+------------------------------------------------------------------+
//| Register logger in factory                                      |
//+------------------------------------------------------------------+
void CLoggerFactory::RegisterLogger(CLogger* logger)
{
   if(logger != NULL)
   {
      s_loggers.Add((CObject*)logger);
   }
}

//+------------------------------------------------------------------+
//| Register handler in factory                                     |
//+------------------------------------------------------------------+
void CLoggerFactory::RegisterHandler(ILogHandler* handler)
{
   if(handler != NULL)
   {
      s_handlers.Add(handler);
   }
}

//+------------------------------------------------------------------+
//| Register formatter in factory                                   |
//+------------------------------------------------------------------+
void CLoggerFactory::RegisterFormatter(ILogFormatter* formatter)
{
   if(formatter != NULL)
   {
      s_formatters.Add(formatter);
   }
}

//+------------------------------------------------------------------+
//| Register filter in factory                                      |
//+------------------------------------------------------------------+
void CLoggerFactory::RegisterFilter(ILogFilter* filter)
{
   if(filter != NULL)
   {
      s_filters.Add(filter);
   }
}

//+------------------------------------------------------------------+
//| Get or create logger                                           |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::GetLogger(string name = "default")
{
   Initialize();
   
   if(!IsValidLoggerName(name))
   {
      name = "default";
   }
   
   // Try to find existing logger
   CLogger* logger = FindLogger(name);
   if(logger != NULL)
   {
      return logger;
   }
   
   // Create new logger with default configuration
   return CreateLogger(name, s_default_config);
}

//+------------------------------------------------------------------+
//| Create logger with configuration                               |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::CreateLogger(string name, const SLoggerConfig &config)
{
   Initialize();
   
   if(!IsValidLoggerName(name))
   {
      PrintFormat("Invalid logger name: %s", name);
      return NULL;
   }
   
   // Check if logger already exists
   if(FindLogger(name) != NULL)
   {
      PrintFormat("Logger already exists: %s", name);
      return FindLogger(name);
   }
   
   // Create new logger
   CLogger* logger = new CLogger(name);
   if(logger == NULL)
   {
      PrintFormat("Failed to create logger: %s", name);
      return NULL;
   }
   
   // Configure logger
   ConfigureLogger(logger, config);
   
   // Register logger
   RegisterLogger(logger);
   
   return logger;
}

//+------------------------------------------------------------------+
//| Create logger with default configuration                       |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::CreateLogger(string name)
{
   return CreateLogger(name, s_default_config);
}

//+------------------------------------------------------------------+
//| Create console handler                                          |
//+------------------------------------------------------------------+
CConsoleHandler* CLoggerFactory::CreateConsoleHandler(bool use_print = true, bool show_alerts = false)
{
   Initialize();
   
   CConsoleHandler* handler = new CConsoleHandler(use_print, show_alerts);
   if(handler != NULL)
   {
      RegisterHandler(handler);
   }
   
   return handler;
}

//+------------------------------------------------------------------+
//| Create file handler                                            |
//+------------------------------------------------------------------+
CFileHandler* CLoggerFactory::CreateFileHandler(string filename, bool append = true, bool auto_flush = false)
{
   Initialize();
   
   if(StringLen(filename) == 0)
   {
      filename = GenerateLogFileName();
   }
   
   CFileHandler* handler = new CFileHandler(filename, append, auto_flush);
   if(handler != NULL)
   {
      RegisterHandler(handler);
   }
   
   return handler;
}

//+------------------------------------------------------------------+
//| Create SQLite handler                                          |
//+------------------------------------------------------------------+
CSqliteHandler* CLoggerFactory::CreateSqliteHandler(string database_path, string table_name = "logs")
{
   Initialize();
   
   if(StringLen(database_path) == 0)
   {
      database_path = GenerateDbFileName();
   }
   
   CSqliteHandler* handler = new CSqliteHandler(database_path, table_name);
   if(handler != NULL)
   {
      RegisterHandler(handler);
   }
   
   return handler;
}

//+------------------------------------------------------------------+
//| Create simple formatter                                         |
//+------------------------------------------------------------------+
CSimpleFormatter* CLoggerFactory::CreateSimpleFormatter(string pattern = "")
{
   Initialize();
   
   CSimpleFormatter* formatter = new CSimpleFormatter(pattern);
   if(formatter != NULL)
   {
      RegisterFormatter(formatter);
   }
   
   return formatter;
}

//+------------------------------------------------------------------+
//| Create detailed formatter                                       |
//+------------------------------------------------------------------+
CDetailedFormatter* CLoggerFactory::CreateDetailedFormatter(string pattern = "", bool multiline = false)
{
   Initialize();
   
   CDetailedFormatter* formatter = new CDetailedFormatter(pattern, multiline);
   if(formatter != NULL)
   {
      RegisterFormatter(formatter);
   }
   
   return formatter;
}

//+------------------------------------------------------------------+
//| Create level filter                                            |
//+------------------------------------------------------------------+
CLevelFilter* CLoggerFactory::CreateLevelFilter(ENUM_LOG_LEVEL min_level = LOG_TRACE)
{
   Initialize();
   
   CLevelFilter* filter = new CLevelFilter(min_level);
   if(filter != NULL)
   {
      RegisterFilter(filter);
   }
   
   return filter;
}

//+------------------------------------------------------------------+
//| Create regex filter                                            |
//+------------------------------------------------------------------+
CRegexFilter* CLoggerFactory::CreateRegexFilter(bool case_sensitive = true)
{
   Initialize();
   
   CRegexFilter* filter = new CRegexFilter(case_sensitive);
   if(filter != NULL)
   {
      RegisterFilter(filter);
   }
   
   return filter;
}

//+------------------------------------------------------------------+
//| Set default configuration                                       |
//+------------------------------------------------------------------+
void CLoggerFactory::SetDefaultConfig(const SLoggerConfig &config)
{
   s_default_config = config;
}

//+------------------------------------------------------------------+
//| Get default configuration                                       |
//+------------------------------------------------------------------+
SLoggerConfig CLoggerFactory::GetDefaultConfig()
{
   return s_default_config;
}

//+------------------------------------------------------------------+
//| Configure logger with settings                                 |
//+------------------------------------------------------------------+
void CLoggerFactory::ConfigureLogger(CLogger* logger, const SLoggerConfig &config)
{
   if(logger == NULL) return;
   
   logger.SetLevel(config.level);
   logger.Enable(config.enabled);
   logger.SetAutoFlushInterval(config.flush_interval);
   
   // Add console handler if requested
   if(config.console_output)
   {
      CConsoleHandler* console_handler = CreateConsoleHandler();
      if(console_handler != NULL)
      {
         if(config.detailed_format)
         {
            CDetailedFormatter* formatter = CreateDetailedFormatter(config.format_pattern);
            console_handler.SetFormatter(formatter);
         }
         else if(StringLen(config.format_pattern) > 0)
         {
            CSimpleFormatter* formatter = CreateSimpleFormatter(config.format_pattern);
            console_handler.SetFormatter(formatter);
         }
         
         logger.AddHandler(console_handler);
      }
   }
   
   // Add file handler if requested
   if(config.file_output)
   {
      string filename = config.log_file;
      if(StringLen(filename) == 0)
      {
         filename = GenerateLogFileName(config.name);
      }
      
      CFileHandler* file_handler = CreateFileHandler(filename, true, config.auto_flush);
      if(file_handler != NULL)
      {
         if(config.detailed_format)
         {
            CDetailedFormatter* formatter = CreateDetailedFormatter(config.format_pattern);
            file_handler.SetFormatter(formatter);
         }
         else if(StringLen(config.format_pattern) > 0)
         {
            CSimpleFormatter* formatter = CreateSimpleFormatter(config.format_pattern);
            file_handler.SetFormatter(formatter);
         }
         
         logger.AddHandler(file_handler);
      }
   }
   
   // Add database handler if requested
   if(config.database_output)
   {
      string db_filename = config.database_file;
      if(StringLen(db_filename) == 0)
      {
         db_filename = GenerateDbFileName(config.name);
      }
      
      CSqliteHandler* db_handler = CreateSqliteHandler(db_filename);
      if(db_handler != NULL)
      {
         logger.AddHandler(db_handler);
      }
   }
}

//+------------------------------------------------------------------+
//| Create console-only logger                                     |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::CreateConsoleLogger(string name = "console", ENUM_LOG_LEVEL level = LOG_INFO)
{
   SLoggerConfig config;
   config.name = name;
   config.level = level;
   config.console_output = true;
   config.file_output = false;
   config.database_output = false;
   
   return CreateLogger(name, config);
}

//+------------------------------------------------------------------+
//| Create file-only logger                                        |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::CreateFileLogger(string name, string filename, ENUM_LOG_LEVEL level = LOG_INFO)
{
   SLoggerConfig config;
   config.name = name;
   config.level = level;
   config.console_output = false;
   config.file_output = true;
   config.database_output = false;
   config.log_file = filename;
   config.detailed_format = true;
   
   return CreateLogger(name, config);
}

//+------------------------------------------------------------------+
//| Create database-only logger                                    |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::CreateDatabaseLogger(string name, string database_path, ENUM_LOG_LEVEL level = LOG_INFO)
{
   SLoggerConfig config;
   config.name = name;
   config.level = level;
   config.console_output = false;
   config.file_output = false;
   config.database_output = true;
   config.database_file = database_path;
   
   return CreateLogger(name, config);
}

//+------------------------------------------------------------------+
//| Create composite logger (multiple outputs)                     |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::CreateCompositeLogger(string name, bool console = true, string log_file = "", string db_file = "")
{
   SLoggerConfig config;
   config.name = name;
   config.level = LOG_INFO;
   config.console_output = console;
   config.file_output = (StringLen(log_file) > 0);
   config.database_output = (StringLen(db_file) > 0);
   config.log_file = log_file;
   config.database_file = db_file;
   config.detailed_format = true;
   
   return CreateLogger(name, config);
}

//+------------------------------------------------------------------+
//| Flush all loggers                                              |
//+------------------------------------------------------------------+
void CLoggerFactory::FlushAll()
{
   for(int i = 0; i < s_loggers.Total(); i++)
   {
      CObject* obj = s_loggers.At(i);
      CLogger* logger = dynamic_cast<CLogger*>(obj);
      if(logger != NULL)
      {
         logger.Flush();
      }
   }
}

//+------------------------------------------------------------------+
//| Set global logging level for all loggers                      |
//+------------------------------------------------------------------+
void CLoggerFactory::SetGlobalLevel(ENUM_LOG_LEVEL level)
{
   for(int i = 0; i < s_loggers.Total(); i++)
   {
      CObject* obj = s_loggers.At(i);
      CLogger* logger = dynamic_cast<CLogger*>(obj);
      if(logger != NULL)
      {
         logger.SetLevel(level);
      }
   }
}

//+------------------------------------------------------------------+
//| Enable/disable all loggers                                     |
//+------------------------------------------------------------------+
void CLoggerFactory::EnableAll(bool enabled)
{
   for(int i = 0; i < s_loggers.Total(); i++)
   {
      CObject* obj = s_loggers.At(i);
      CLogger* logger = dynamic_cast<CLogger*>(obj);
      if(logger != NULL)
      {
         logger.Enable(enabled);
      }
   }
}

//+------------------------------------------------------------------+
//| Get logger count                                               |
//+------------------------------------------------------------------+
int CLoggerFactory::GetLoggerCount()
{
   return s_loggers.Total();
}

//+------------------------------------------------------------------+
//| Get logger by index                                            |
//+------------------------------------------------------------------+
CLogger* CLoggerFactory::GetLoggerByIndex(int index)
{
   if(index >= 0 && index < s_loggers.Total())
   {
      return s_loggers.At(index);
   }
   return NULL;
}

//+------------------------------------------------------------------+
//| Remove logger by name                                          |
//+------------------------------------------------------------------+
void CLoggerFactory::RemoveLogger(string name)
{
   for(int i = 0; i < s_loggers.Total(); i++)
   {
      CObject* obj = s_loggers.At(i);
      CLogger* logger = dynamic_cast<CLogger*>(obj);
      if(logger != NULL && StringCompare(logger.Name(), name) == 0)
      {
         s_loggers.Delete(i);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Remove all loggers                                             |
//+------------------------------------------------------------------+
void CLoggerFactory::RemoveAllLoggers()
{
   s_loggers.Clear();
}

//+------------------------------------------------------------------+
//| Shutdown factory and cleanup all resources                     |
//+------------------------------------------------------------------+
void CLoggerFactory::Shutdown()
{
   FlushAll();
   Cleanup();
}

//+------------------------------------------------------------------+
//| Generate unique log filename                                   |
//+------------------------------------------------------------------+
string CLoggerFactory::GenerateLogFileName(string base_name = "")
{
   if(StringLen(base_name) == 0)
   {
      base_name = "logger";
   }
   
   string date_str = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(date_str, ".", "");
   
   return StringFormat("%s_%s.log", base_name, date_str);
}

//+------------------------------------------------------------------+
//| Generate unique database filename                              |
//+------------------------------------------------------------------+
string CLoggerFactory::GenerateDbFileName(string base_name = "")
{
   if(StringLen(base_name) == 0)
   {
      base_name = "logger";
   }
   
   return StringFormat("%s.db", base_name);
}

//+------------------------------------------------------------------+
//| Validate logger name                                           |
//+------------------------------------------------------------------+
bool CLoggerFactory::IsValidLoggerName(string name)
{
   if(StringLen(name) == 0 || StringLen(name) > 50)
      return false;
   
   // Check for invalid characters
   for(int i = 0; i < StringLen(name); i++)
   {
      ushort ch = StringGetCharacter(name, i);
      if(!((ch >= 'a' && ch <= 'z') || 
           (ch >= 'A' && ch <= 'Z') || 
           (ch >= '0' && ch <= '9') || 
           ch == '_' || ch == '-'))
      {
         return false;
      }
   }
   
   return true;
}
