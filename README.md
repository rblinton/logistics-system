# Logistics System

> **Multi-site logistics operations with TigerBeetle accounting database**

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](#)
[![Tests](https://img.shields.io/badge/tests-12%20passing-brightgreen)](#)
[![.NET Version](https://img.shields.io/badge/.NET-9.0-blue)](#)
[![TigerBeetle](https://img.shields.io/badge/TigerBeetle-0.16.60-orange)](#)

A high-performance logistics system designed for multi-site operations with offline resilience and real-time financial integrity.

## 🚀 **Quick Start**

```bash
# 1. Clone and build
cd /home/rob/logistics-system
dotnet build

# 2. Run tests (should show 12 passing)
dotnet test

# 3. Start TigerBeetle (if not already running)
docker start tigerbeetle

# 4. Run the API
cd src/LogisticsSystem.Api
dotnet run
# API available at: https://localhost:7158
```

## ✨ **Features**

- 🆔 **Simple ID System** - Site-prefixed, time-ordered, debuggable IDs
- 🏢 **Multi-Site Support** - Corporate HQ + remote sites with offline capability
- 🐅 **TigerBeetle Integration** - High-performance accounting database
- 📦 **Load Lifecycle** - Complete load management from creation to completion
- 🔄 **Offline Resilience** - Automatic sync when connectivity restored
- 🧪 **Test Coverage** - Comprehensive unit tests for core functionality

## 🏗️ **Architecture**

```
Corporate HQ (Hub)          Remote Sites (Spokes)
┌─────────────────┐        ┌─────────────────┐
│ TigerBeetle     │◄──VPN──│ .NET API        │
│ Cluster (3 nodes)│        │ + Offline Buffer │
│                 │        │ + Reference DB   │
└─────────────────┘        └─────────────────┘
```

## 🛠️ **Tech Stack**

- **.NET 9.0** - Modern C# with records and minimal APIs
- **TigerBeetle 0.16.60** - High-performance accounting database
- **Docker** - Containerized TigerBeetle deployment
- **xUnit** - Comprehensive testing framework
- **SQLite** - Local reference database and offline buffer

## 📊 **Project Structure**

| Project | Purpose |
|---------|---------|
| **LogisticsSystem.Core** | Domain models, ID generation, shared logic |
| **LogisticsSystem.TigerBeetle** | Accounting integration, offline buffer |
| **LogisticsSystem.Api** | REST API, configuration, health checks |
| **LogisticsSystem.Core.Tests** | Unit tests (12 passing) |

## 🧪 **Testing**

```bash
# Run all tests
dotnet test

# Run with watch mode
dotnet watch test

# Run specific test class
dotnet test --filter "LogisticsIdTests"
```

## 🆔 **ID System Example**

```csharp
// Generate debuggable IDs
var loadId = LogisticsId.GenerateLoadId("SITE_A");

// Instant debugging capability
Console.WriteLine(LogisticsId.FormatForLogging(loadId));
// Output: "SITE_A@2025-10-03 20:24:03#42"

// Extract components
var site = LogisticsId.GetSiteCode(loadId);     // "SITE_A"
var timestamp = LogisticsId.GetTimestamp(loadId); // 2025-10-03 20:24:03
var counter = LogisticsId.GetCounter(loadId);   // 42
```

## 📋 **Development Roadmap**

- [x] **Foundation** - Project structure, ID system, domain models
- [x] **TigerBeetle Integration** - Service interfaces and base implementation
- [x] **Configuration** - Environment-specific settings
- [x] **Testing** - Core functionality validated
- [ ] **Load Lifecycle** - Complete CRUD operations
- [ ] **REST API** - Web endpoints and validation
- [ ] **Offline Buffer** - SQLite-based synchronization
- [ ] **Master Data** - Vendor/carrier/product management

## 📚 **Documentation**

- 📁 **[Documentation Hub](docs/README.md)** - Complete navigation guide for all docs
- 📖 **[Development Guide](docs/DEVELOPMENT_GUIDE.md)** - Complete development setup and workflow
- 🏗️ **[Implementation Design](docs/LOGISTICS_IMPLEMENTATION.md)** - Detailed architecture and domain models
- 🐅 **[TigerBeetle Setup](docs/TIGERBEETLE_SETUP.md)** - Database configuration and installation
- 🚀 **[Production Deployment](docs/PRODUCTION_DEPLOYMENT.md)** - Production deployment strategies

## 🤝 **Development**

Ready for iterative development! See the [Development Guide](docs/DEVELOPMENT_GUIDE.md) for:

- Daily development workflow
- Testing strategies
- Common development tasks
- Troubleshooting guide
- Phase-by-phase roadmap

## 📊 **Current Status**

- ✅ **12 Unit Tests** passing
- ✅ **4 .NET Projects** with clean architecture
- ✅ **TigerBeetle Integration** ready
- ✅ **Simple ID System** implemented and tested
- ✅ **Configuration Management** environment-ready
- ✅ **Development Environment** fully functional

---

**Next Step**: Implement your first feature using the [Development Guide](docs/DEVELOPMENT_GUIDE.md)! 🎯