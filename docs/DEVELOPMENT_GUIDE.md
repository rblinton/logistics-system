# Logistics System - Development Guide

> **Complete guide for iterative development of the multi-site logistics system with TigerBeetle**

**Created**: October 3, 2025  
**Environment**: Arch Linux with .NET 9 and TigerBeetle 0.16.60  
**Status**: Development Environment Ready ✅

---

## 🎯 **What We've Built**

You now have a complete **foundation** for iterative logistics development with:

- ✅ **Project Structure** - Multi-project .NET solution  
- ✅ **Core ID Generation** - Simple, debuggable site-prefixed IDs
- ✅ **Domain Models** - Complete request/response and entity models
- ✅ **TigerBeetle Integration** - Service interfaces and base implementation
- ✅ **Configuration Management** - Environment-specific settings
- ✅ **Unit Tests** - Validated LogisticsId functionality
- ✅ **Development Ready** - Ready for iterative feature development

---

## 🗂️ **Project Structure**

```
/home/rob/logistics-system/
├── LogisticsSystem.sln          # Solution file
├── docs/
│   ├── DEVELOPMENT_GUIDE.md     # This file
│   └── ...                      # Future architecture docs
├── src/
│   ├── LogisticsSystem.Core/    # Domain models, LogisticsId, shared logic
│   ├── LogisticsSystem.TigerBeetle/ # TigerBeetle integration services  
│   └── LogisticsSystem.Api/     # Web API for logistics operations
└── tests/
    └── LogisticsSystem.Core.Tests/ # Unit tests (12 passing tests)
```

### **Project Responsibilities**

| Project | Purpose | Dependencies |
|---------|---------|--------------|
| **Core** | Domain models, ID generation, shared contracts | None |
| **TigerBeetle** | Accounting integration, offline buffer | Core, tigerbeetle |
| **Api** | REST endpoints, configuration, hosting | Core, TigerBeetle |
| **Tests** | Unit tests, integration tests | Core |

---

## 🚀 **Getting Started - Daily Development**

### **Prerequisites Check**
```bash
# Verify your environment is ready
cd /home/rob/logistics-system

# 1. Solution builds successfully
dotnet build

# 2. All tests pass
dotnet test

# 3. TigerBeetle is running (from previous setup)
docker ps | grep tigerbeetle
```

### **🔄 AI-Driven Development Workflow**

**The system now includes intelligent session management with AI progress tracking:**

#### **1. Start Development Session**
```bash
./dev-start.sh
# ✅ Automatically syncs with GitHub (smart pull)
# ✅ Auto-starts TigerBeetle if needed
# ✅ Verifies build and tests (12 passing)
# ✅ Detects multi-machine transitions
# ✅ Shows current progress and next steps
```

#### **2. Optional Progress Checks During Development**
```bash
./update-progress.sh
# ✅ Generates technical analysis for AI assistant
# ✅ Tracks incremental changes (no duplication)
# ✅ Captures build/test status automatically
# ✅ AI maintains intelligent progress summary
```

#### **3. Run the API (When Needed)**
```bash
dotnet run --project src/LogisticsSystem.Api
# API available at: https://localhost:7158
```

#### **4. End Development Session**
```bash
./dev-stop.sh
# ✅ AI analyzes session accomplishments automatically
# ✅ Commits with custom or auto-generated messages
# ✅ Pushes to GitHub with verification
# ✅ Final build/test validation (12 passing)
# ✅ Optional TigerBeetle shutdown
# ✅ Session summary with duration and progress
```

### **🤖 AI Progress Tracking Features**

- **Zero Manual Entry**: AI tracks progress based on code changes
- **Multi-Machine Continuity**: Progress follows you across development machines
- **Intelligent Analysis**: Detects file types, commit patterns, test results
- **Session Boundaries**: Clean start/stop with comprehensive summaries
- **Error Prevention**: Smart git operations avoid conflicts

---

## 🧪 **Testing Strategy**

### **Current Test Coverage**
- ✅ **LogisticsId** - 12 comprehensive tests covering:
  - ID generation and uniqueness
  - Site code extraction and validation  
  - Timestamp extraction and verification
  - Human-readable formatting
  - Transfer and entity ID generation

### **Running Tests**
```bash
# Run all tests
dotnet test

# Run with detailed output
dotnet test --logger "console;verbosity=detailed"

# Run tests continuously during development
dotnet watch test

# Generate coverage report (after adding coverlet)
dotnet test --collect:"XPlat Code Coverage"
```

### **Adding New Tests**
```bash
# Add test file to LogisticsSystem.Core.Tests
# Follow the pattern: FeatureNameTests.cs

# Example test structure:
# [Fact] - Single test case
# [Theory][InlineData] - Multiple test cases with data
```

---

## 🛠️ **Key Development Components**

### **1. LogisticsId - The Foundation**

Your simple, debuggable ID system:

```csharp
// Generate IDs
var loadId = LogisticsId.GenerateLoadId("SITE_A");
var transferId = LogisticsId.GenerateTransferId("SITE_A", "LOAD_CREATE");

// Debug IDs instantly
Console.WriteLine(LogisticsId.FormatForLogging(loadId));
// Output: "SITE_A@2025-10-03 20:24:03#42"

// Extract components for business logic
var site = LogisticsId.GetSiteCode(loadId);        // "SITE_A"
var timestamp = LogisticsId.GetTimestamp(loadId);  // 2025-10-03 20:24:03
var counter = LogisticsId.GetCounter(loadId);      // 42
```

### **2. Domain Models**

Ready-to-use request/response models:

```csharp
// Create load request
var request = new CreateLoadRequest
{
    SiteCode = "SITE_A",
    LoadNumber = "L001",
    CarrierCode = "XYZ_TRANSPORT",
    ProductCode = "GRAIN",
    EstimatedRevenue = 1500m,
    EstimatedCost = 1200m
};

// Response with offline capability
var result = new LoadCreationResult
{
    LoadId = loadId,
    HumanReference = "SITE_A-L001",
    Status = LoadStatus.Created, // or CreatedOffline
    IsOffline = false
};
```

### **3. TigerBeetle Integration**

Service interfaces ready for implementation:

```csharp
// Main services to implement
public interface ILoadLifecycleService
{
    Task<LoadCreationResult> CreateLoadAsync(CreateLoadRequest request);
    Task<LoadAssignmentResult> AssignLoadAsync(AssignLoadRequest request);
    Task<LoadCompletionResult> CompleteLoadAsync(CompleteLoadRequest request);
}

// Base TigerBeetle service already implemented
public interface ITigerBeetleService
{
    Task<bool> IsHealthyAsync();
    Task<Account[]> LookupAccountsAsync(UInt128[] accountIds);
    // ... more methods
}
```

---

## 📋 **Iterative Development Roadmap**

### **Phase 1: Core Load Operations (Week 1)**
- [ ] Implement `LoadLifecycleService`
- [ ] Create basic load CRUD operations
- [ ] Add load lifecycle state management
- [ ] Test with TigerBeetle database

### **Phase 2: REST API Layer (Week 2)**
- [ ] Implement load management controllers
- [ ] Add API validation and error handling
- [ ] Create health check endpoints
- [ ] Add API documentation (Swagger)

### **Phase 3: Offline Buffer System (Week 3)**
- [ ] Implement SQLite offline buffer
- [ ] Add synchronization service
- [ ] Test offline/online scenarios
- [ ] Add conflict resolution

### **Phase 4: Master Data Management (Week 4)**
- [ ] Implement vendor/carrier/product services
- [ ] Add master data synchronization
- [ ] Create admin endpoints for master data
- [ ] Test cross-site data consistency

### **Phase 5: Site-Specific Features (Week 5)**
- [ ] Site account initialization
- [ ] Site-specific load queuing
- [ ] Inter-site transfer operations
- [ ] Site health monitoring

### **Future Phases**
- Advanced reporting and analytics
- Performance optimization
- Production deployment preparation
- Multi-site testing and validation

---

## 🔧 **Configuration Management**

### **Development Configuration**
Located in `src/LogisticsSystem.Api/appsettings.Development.json`:

```json
{
  "TigerBeetle": {
    "ClusterAddresses": ["127.0.0.1:3000"],
    "ConnectionTimeout": "10s",
    "MaxRetries": 3
  },
  "Site": {
    "SiteCode": "DEV_SITE",
    "SiteName": "Development Site"
  },
  "OfflineBuffer": {
    "BufferDatabasePath": "./dev_buffer.db",
    "SyncIntervalSeconds": 10
  }
}
```

### **Adding New Configuration**
1. Add properties to domain models in `Core/Domain/Models.cs`
2. Update `appsettings.Development.json`
3. Wire up in API startup configuration

---

## 🐛 **Common Development Tasks**

### **Add a New Site Code**
```csharp
// Edit LogisticsId.cs
private static readonly Dictionary<string, byte> SiteCodes = new()
{
    { "CORP", 0x01 },
    { "SITE_A", 0x02 },
    { "SITE_B", 0x03 },
    { "NEW_SITE", 0x06 }, // Add new site
};

// Add test
[Fact]
public void IsValidSiteCode_NewSite_ReturnsTrue()
{
    Assert.True(LogisticsId.IsValidSiteCode("NEW_SITE"));
}
```

### **Add a New Domain Model**
```csharp
// Add to Core/Domain/Models.cs
public record NewFeatureRequest
{
    public required string SiteCode { get; init; }
    public required string FeatureData { get; init; }
    // ... more properties
}

// Add corresponding response model
public record NewFeatureResult
{
    public required UInt128 FeatureId { get; init; }
    public required bool IsOffline { get; init; }
    // ... more properties
}
```

### **Add a New Service Interface**
```csharp
// Add to TigerBeetle/Interfaces/
public interface INewFeatureService
{
    Task<NewFeatureResult> ProcessFeatureAsync(NewFeatureRequest request);
}

// Implement in TigerBeetle/Services/
public class NewFeatureService : INewFeatureService
{
    // Implementation...
}
```

### **Debug ID Issues**
```csharp
// Any ID can be immediately debugged
var problematicId = someUInt128ValueFromLogs;

Console.WriteLine($"ID Breakdown:");
Console.WriteLine($"  Site: {LogisticsId.GetSiteCode(problematicId)}");
Console.WriteLine($"  Created: {LogisticsId.GetTimestamp(problematicId)}");
Console.WriteLine($"  Counter: {LogisticsId.GetCounter(problematicId)}");
Console.WriteLine($"  Formatted: {LogisticsId.FormatForLogging(problematicId)}");
```

---

## 📊 **Development Metrics**

### **Current State**
- ✅ **12 Unit Tests** - All passing
- ✅ **4 .NET Projects** - Clean architecture
- ✅ **Simple ID System** - Debuggable and efficient
- ✅ **TigerBeetle Ready** - Integration layer prepared
- ✅ **Configuration** - Environment-specific settings
- ✅ **Domain Models** - Complete request/response structure

### **Next Milestones**
- 🎯 **Week 1**: Core load operations implemented
- 🎯 **Week 2**: REST API endpoints working
- 🎯 **Week 3**: Offline buffer system operational
- 🎯 **Week 4**: Master data management complete

---

## 🚨 **Troubleshooting**

### **Build Issues**
```bash
# Clean and rebuild
dotnet clean
dotnet build

# Check for missing packages
dotnet restore
```

### **Test Failures**
```bash
# Run specific failing test
dotnet test --filter "TestMethodName"

# Run with verbose output
dotnet test --logger "console;verbosity=detailed"
```

### **TigerBeetle Connection Issues**
```bash
# Check if TigerBeetle is running
docker ps | grep tigerbeetle

# Check TigerBeetle logs
docker logs tigerbeetle

# Restart TigerBeetle if needed
docker restart tigerbeetle
```

### **Configuration Issues**
```bash
# Verify appsettings files exist
ls src/LogisticsSystem.Api/appsettings*.json

# Check configuration binding in Program.cs
```

---

## 📝 **Development Standards**

### **Code Style**
- Use `record` types for immutable data models
- Use `required` properties for essential fields
- Follow C# naming conventions
- Add XML documentation for public APIs

### **Testing Standards**
- One test class per feature (e.g., `LogisticsIdTests`)
- Use descriptive test method names: `Method_Scenario_ExpectedResult`
- Use `[Fact]` for single tests, `[Theory]` for parameterized tests
- Test both happy path and edge cases

### **Git Workflow**
```bash
# Create feature branches
git checkout -b feature/load-lifecycle-service

# Make small, focused commits
git add .
git commit -m "feat: implement LoadLifecycleService.CreateLoadAsync"

# Run tests before pushing
dotnet test
git push origin feature/load-lifecycle-service
```

---

## 🎉 **You're Ready for Iterative Development!**

Your development environment is **completely set up** and ready for productive iteration:

1. **✅ Foundation Built** - All core components implemented
2. **✅ Tests Passing** - Development quality validated  
3. **✅ TigerBeetle Connected** - Database integration ready
4. **✅ Clear Roadmap** - Phase-by-phase development plan
5. **✅ Documentation** - Complete guides and references

### **🊆 Start Your First Iteration with AI-Driven Workflow**

```bash
cd /home/rob/logistics-system

# 1. Start your development session
./dev-start.sh
# ✅ Everything is verified and ready automatically

# 2. Develop your first feature
# Focus on: LoadLifecycleService implementation

# 3. Optional: Check progress anytime
./update-progress.sh

# 4. End your session
./dev-stop.sh
# ✅ AI analyzes and saves all progress automatically
```

You now have everything needed for efficient, iterative development of your logistics system! 🚀

---

## 📚 **Additional Resources**

- **Implementation Design**: `~/tigerbeetle-dotnet/LOGISTICS_IMPLEMENTATION.md`
- **TigerBeetle Setup**: `~/tigerbeetle-dotnet/TIGERBEETLE_SETUP.md`
- **Production Deployment**: `~/tigerbeetle-dotnet/PRODUCTION_DEPLOYMENT.md`
- **TigerBeetle Documentation**: https://docs.tigerbeetle.com
- **.NET Documentation**: https://docs.microsoft.com/dotnet

Happy coding! 🎯