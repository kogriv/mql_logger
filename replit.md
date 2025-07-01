# Professional MQL5 Logger System

## Overview
This project is a complete, professional logging system for MQL5 (MetaQuotes Language 5) designed for MetaTrader 5 trading platform. The logger features a modular architecture with multiple handlers, advanced filtering capabilities, and comprehensive formatting options. It addresses the unique challenges of MQL5's pseudo-multithreading environment where multiple event handlers may compete for shared resources.

## System Architecture
The system follows a simple singleton pattern with thread-safety mechanisms adapted for MQL5's execution model:

### Core Design Principles
- **Pseudo-thread safety**: While MQL5 doesn't have true multithreading, it handles asynchronous events that can create race conditions
- **Simple locking mechanism**: Uses a basic flag-based locking system suitable for MQL5's constraints
- **Resource protection**: Focuses on protecting shared resources like global variables and file I/O operations

### Architecture Components
```
MQL5 Event System
├── OnTick() Events
├── OnTimer() Events  
├── OnTrade() Events
└── OnChart() Events
          ↓
    CThreadSafeLogger
    ├── Lock Management
    ├── Message Queue
    └── File Output
```

## Key Components

### 1. CThreadSafeLogger Class
- **Purpose**: Provides thread-safe logging functionality for MQL5 applications
- **Implementation**: Uses a static boolean lock to prevent concurrent access
- **Target Use Cases**: 
  - Global variable logging across multiple Expert Advisors (EAs)
  - File I/O operations
  - Shared resource access logging

### 2. Locking Mechanism
- **Problem Addressed**: Race conditions in MQL5's pseudo-multithreaded environment
- **Solution**: Simple flag-based locking system using static boolean
- **Rationale**: MQL5's sequential event processing allows for lightweight synchronization

## Data Flow

1. **Event Trigger**: MQL5 event (OnTick, OnTimer, etc.) triggers logging request
2. **Lock Check**: Logger checks if lock is available
3. **Resource Access**: If unlocked, logger acquires lock and processes message
4. **Output**: Message is written to designated output (file, console, etc.)
5. **Lock Release**: Lock is released for next logging operation

## External Dependencies

### MQL5 Runtime
- **Dependency**: MetaTrader 5 platform
- **Purpose**: Provides execution environment and event system
- **Integration**: Direct compilation to MQL5 bytecode

### File System Access
- **Dependency**: MetaTrader 5 file system permissions
- **Purpose**: Log file creation and writing
- **Constraints**: Limited to MetaTrader's sandbox directory structure

## Deployment Strategy

### Development Environment
- **Platform**: MetaTrader 5 with MetaEditor IDE
- **Language**: MQL5
- **Compilation**: Direct compilation to .ex5 executable

### Production Deployment
- **Target**: MetaTrader 5 Expert Advisors, Indicators, or Scripts
- **Integration**: Include logger as part of larger trading applications
- **Distribution**: Through MetaTrader Market or direct file sharing

## User Preferences

Preferred communication style: Simple, everyday language.

## Changelog

Changelog:
- July 01, 2025. Initial setup