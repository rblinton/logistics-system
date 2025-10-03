# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Quick Commands

### Session Management
```bash
# Start development session (syncs, builds, tests, starts services)
./dev-start.sh

# End development session (commits, pushes, verifies)
./dev-stop.sh

# Generate AI progress report during session
./update-progress.sh
```

### Build & Test
```bash
# Build entire solution
dotnet build

# Run all tests (12 passing)
dotnet test

# Run tests with watch mode during development
dotnet watch test

# Run specific test class
dotnet test --filter "LogisticsIdTests"

# Build with detailed output
dotnet build --verbosity normal
```

### Future API Development
```bash
# API project will be added in future phases
# Currently focusing on core business logic
```

### TigerBeetle Management
```bash
# Check TigerBeetle container status
docker ps | grep tigerbeetle

# Start TigerBeetle manually if needed
docker start tigerbeetle

# Stop TigerBeetle container
docker stop tigerbeetle
```

## Architecture Overview

This is a **hub-and-spoke multi-site logistics system** with offline resilience:

```
Corporate HQ (Hub)          Remote Sites (Spokes)
┌─────────────────┐        ┌─────────────────┐
│ TigerBeetle     │◄──VPN──│ .NET API        │
│ Cluster         │        │ + Offline Buffer │
│ (3 nodes)       │        │ + Reference DB   │
└─────────────────┘        └─────────────────┘
```

### Project Structure
- **LogisticsSystem.Core** - Domain models, LogisticsId system, shared logic
- **LogisticsSystem.TigerBeetle** - Accounting integration, offline buffer
- **LogisticsSystem.Core.Tests** - Unit tests for core functionality

### Data Flow
1. **Site Operations** → Generate loads with site-prefixed IDs
2. **Core Processing** → Apply business rules and validations  
3. **TigerBeetle Integration** → Record double-entry accounting transactions
4. **Offline Buffer** → Queue operations when VPN is down
5. **Synchronization** → Sync with Corporate HQ when connectivity restored

## Core Concepts

### LogisticsId System
The system uses a **site-prefixed, time-ordered ID scheme** for conflict-free multi-site operations:

- **Structure**: `[Site:8][Timestamp:56][Counter:64]` = 128 bits
- **Benefits**: Debuggable, conflict-free, time-ordered
- **Usage**: `LogisticsId.GenerateLoadId("SITE_A")` → extractable site/timestamp/counter

```csharp path=/home/rob/logistics-system/src/LogisticsSystem.Core/LogisticsId.cs start=29
public static UInt128 GenerateLoadId(string siteCode)
{
    var siteId = SiteCodes.TryGetValue(siteCode, out var value) ? value : (byte)0xFF;
    var timestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    var counter = GetNextCounter(siteCode);
    
    // Structure ensures:
    // - Site isolation (top 8 bits prevent cross-site conflicts)
    // - Time ordering (next 56 bits for chronological sorting)
    // - Uniqueness (bottom 64 bits counter per site)
    var high = ((ulong)siteId << 56) | ((ulong)timestampMs & 0x00FFFFFFFFFFFFFF);
    var low = counter;
    
    return new UInt128(high, low);
}
```

### Site Management
- **CORP** (0x01) - Corporate headquarters
- **SITE_A** through **SITE_D** (0x02-0x05) - Remote sites
- Each site has isolated ID space preventing conflicts

### TigerBeetle Integration
- **High-performance accounting database** for financial integrity
- **Double-entry bookkeeping** for all load operations
- **ACID guarantees** for accounting transactions
- **Cluster deployment** at Corporate HQ for reliability

## Development Workflow

### Session-Based Development
The project includes intelligent session management with multi-machine continuity:

1. **Start Session**: `./dev-start.sh` 
   - Smart git sync (handles uncommitted changes)
   - Auto-starts TigerBeetle if needed
   - Verifies build/test status
   - Detects cross-machine transitions

2. **Develop Features**:
   - Follow clean architecture patterns in existing codebase
   - Add tests in `LogisticsSystem.Core.Tests`
   - Use LogisticsId for all entity generation

3. **End Session**: `./dev-stop.sh`
   - Analyzes session progress automatically
   - Commits with smart or custom messages
   - Pushes to GitHub with verification
   - Final build/test validation

### Multi-Machine Development
The system automatically detects and handles development across multiple machines:
- Session context preserved in `.ai_session_context.md`
- Smart git operations prevent conflicts
- Progress tracking continues seamlessly

### Testing Strategy
- **12 comprehensive tests** for LogisticsId functionality
- **Unit tests** for core domain logic
- **Integration tests** for TigerBeetle operations
- **Test coverage** includes ID generation, extraction, and validation

## Key Files

- `src/LogisticsSystem.Core/LogisticsId.cs` - Core ID generation system
- `docs/DEVELOPMENT_GUIDE.md` - Comprehensive development guide
- `docs/LOGISTICS_IMPLEMENTATION.md` - Complete system architecture
- `docs/TIGERBEETLE_SETUP.md` - Database setup instructions
- `LogisticsSystem.sln` - Main solution file
- `dev-start.sh` / `dev-stop.sh` - Session management scripts

## Tech Stack

- **.NET 9.0** - Modern C# with records and minimal APIs
- **TigerBeetle 0.16.60** - High-performance accounting database
- **Docker** - Containerized TigerBeetle deployment
- **xUnit** - Comprehensive testing framework
- **SQLite** - Local reference database and offline buffer