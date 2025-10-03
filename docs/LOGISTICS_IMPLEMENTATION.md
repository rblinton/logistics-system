# TigerBeetle Logistics Implementation Design

> **Complete design specification for multi-site logistics operations using TigerBeetle accounting database**

**Document Version**: 1.0  
**Created**: October 3, 2025  
**Last Updated**: October 3, 2025  
**Status**: Draft - Design Phase  

---

## 📋 **Table of Contents**

1. [Business Requirements](#business-requirements)
2. [Architecture Overview](#architecture-overview)
3. [ID Strategy & UUIDv7 Implementation](#id-strategy--uuidv7-implementation)
4. [Data Model Design](#data-model-design)
5. [Account Structure](#account-structure)
6. [Load Lifecycle Implementation](#load-lifecycle-implementation)
7. [Offline Site Synchronization](#offline-site-synchronization)
8. [Network & Security Architecture](#network--security-architecture)
9. [Implementation Services](#implementation-services)
10. [Database Schema](#database-schema)
11. [Configuration Management](#configuration-management)
12. [Monitoring & Operations](#monitoring--operations)
13. [Testing Strategy](#testing-strategy)
14. [Deployment Plan](#deployment-plan)
15. [Future Considerations](#future-considerations)

---

## 🎯 **Business Requirements**

### **Core Operations**
- **Load Management**: Create, assign, track, and complete loads per site
- **Entity Synchronization**: Keep Vendors, Trucking Companies, Products in sync
- **Site Distribution**: Each site handles 30-100 loads per day
- **Offline Resilience**: Sites must operate when VPN is down
- **Financial Integrity**: All transactions must maintain double-entry bookkeeping

### **Network Environment**
- Corporate HQ with reliable infrastructure
- Remote sites connected via VPN
- Occasional site shutdowns requiring catch-up synchronization
- Site-specific load assignment and processing

### **Key Entities**
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Sites     │  │   Vendors   │  │  Carriers   │  │  Products   │
│ - CORP      │  │ - ABC Corp  │  │ - XYZ Truck │  │ - GRAIN     │
│ - SITE_A    │  │ - DEF Ltd   │  │ - QRS Trans │  │ - STEEL     │
│ - SITE_B    │  │ - GHI Inc   │  │ - MNO Haul  │  │ - LUMBER    │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
```

---

## 🏗️ **Architecture Overview**

### **Hub-and-Spoke Topology**

```
Corporate HQ (Hub):                     Remote Sites (Spokes):
┌─────────────────────┐                ┌─────────────────────┐
│ TigerBeetle Cluster │                │ Site A              │
│ ├─ Replica 0 (Primary)◄─────VPN─────►│ ├─ .NET App         │
│ ├─ Replica 1        │                │ ├─ Offline Buffer   │
│ ├─ Replica 2        │                │ ├─ Reference DB     │
│                     │                │ └─ Load Queue       │
│ Authoritative Data: │                └─────────────────────┐
│ ├─ Master Entities  │                ┌─────────────────────┐
│ ├─ Financial Records│◄─────VPN─────►│ Site B              │
│ ├─ Load Registry    │                │ ├─ .NET App         │
│ └─ Cross-Site Ops   │                │ ├─ Offline Buffer   │
└─────────────────────┘                │ ├─ Reference DB     │
                                      │ └─ Load Queue       │
                                      └─────────────────────┘
```

### **Design Principles**
- **Single Source of Truth**: All authoritative data at Corporate HQ
- **Eventual Consistency**: Remote sites sync when connectivity allows
- **Offline First**: Sites operate independently during outages
- **Conflict-Free Design**: Site-specific ID spaces prevent conflicts
- **Financial Integrity**: ACID guarantees for all accounting operations

---

## 🆔 **ID Strategy - Simple & Debuggable Approach**

### **Recommended ID Strategy: Site-Prefixed Time-Ordered IDs**

**Rationale**: For logistics operations with 30-100 loads per site per day, we need IDs that are simple, debuggable, and conflict-free rather than globally unique UUIDs.

**Benefits**:
- ✅ **Simple to implement** - No complex byte conversions
- ✅ **Easy to debug** - Can extract site, timestamp, and counter from ID
- ✅ **Conflict-free** - Site isolation prevents cross-site collisions
- ✅ **Time-ordered** - Natural sorting by creation time
- ✅ **Offline-safe** - Each site has its own ID space

```csharp
using System.Collections.Concurrent;

/// <summary>
/// Simple, predictable ID generation for logistics operations
/// Structure: [Site:8][Timestamp:56][Counter:64] = 128 bits
/// </summary>
public static class LogisticsId
{
    private static readonly Dictionary<string, byte> SiteCodes = new()
    {
        { "CORP", 0x01 },
        { "SITE_A", 0x02 },
        { "SITE_B", 0x03 },
        { "SITE_C", 0x04 },
        { "SITE_D", 0x05 }
        // Expandable to 255 sites
    };
    
    // Thread-safe counter per site for uniqueness
    private static readonly ConcurrentDictionary<string, long> _counters = new();
    
    /// <summary>
    /// Generate a time-ordered, site-specific load ID
    /// </summary>
    /// <param name="siteCode">Site identifier (e.g., "SITE_A")</param>
    /// <returns>UInt128 with embedded site, timestamp, and counter</returns>
    public static UInt128 GenerateLoadId(string siteCode)
    {
        var siteId = SiteCodes.GetValueOrDefault(siteCode, 0xFF);
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
    
    /// <summary>
    /// Generate transfer ID for operations (assignments, completions, etc.)
    /// </summary>
    public static UInt128 GenerateTransferId(string siteCode, string operationType)
    {
        // Use same pattern but different counter space
        return GenerateLoadId($"{siteCode}_{operationType}");
    }
    
    /// <summary>
    /// Generate account ID for entities (vendors, carriers, products)
    /// </summary>
    public static UInt128 GenerateEntityId(string entityType, string entityCode)
    {
        // Entities get corporate site prefix since they're centrally managed
        return GenerateLoadId($"ENTITY_{entityType}_{entityCode}");
    }
    
    /// <summary>
    /// Extract site code from ID - perfect for debugging and logging!
    /// </summary>
    public static string GetSiteCode(UInt128 id)
    {
        var siteId = (byte)(id >> 120); // Extract top 8 bits
        return SiteCodes.FirstOrDefault(kvp => kvp.Value == siteId).Key ?? "UNKNOWN";
    }
    
    /// <summary>
    /// Extract creation timestamp from ID - great for troubleshooting
    /// </summary>
    public static DateTime GetTimestamp(UInt128 id)
    {
        var high = (ulong)(id >> 64);
        var timestampMs = high & 0x00FFFFFFFFFFFFFF; // Extract 56-bit timestamp
        return DateTimeOffset.FromUnixTimeMilliseconds((long)timestampMs).DateTime;
    }
    
    /// <summary>
    /// Get counter value from ID - useful for debugging sequence issues
    /// </summary>
    public static ulong GetCounter(UInt128 id)
    {
        return (ulong)id; // Bottom 64 bits
    }
    
    /// <summary>
    /// Format ID for human-readable logging
    /// </summary>
    public static string FormatForLogging(UInt128 id)
    {
        return $"{GetSiteCode(id)}@{GetTimestamp(id):yyyy-MM-dd HH:mm:ss}#{GetCounter(id)}";
    }
    
    private static ulong GetNextCounter(string siteCode)
    {
        return (ulong)_counters.AddOrUpdate(siteCode, 1, (_, current) => current + 1);
    }
}
```

### **Usage Examples**

```csharp
// Generate IDs
var loadId = LogisticsId.GenerateLoadId("SITE_A");
var transferId = LogisticsId.GenerateTransferId("SITE_A", "LOAD_CREATE");
var vendorId = LogisticsId.GenerateEntityId("VENDOR", "ABC_CORP");

// Debug any ID immediately
Console.WriteLine($"Load ID breakdown:");
Console.WriteLine($"  Site: {LogisticsId.GetSiteCode(loadId)}");      // "SITE_A"
Console.WriteLine($"  Created: {LogisticsId.GetTimestamp(loadId)}");   // "2025-10-03 19:59:53"
Console.WriteLine($"  Counter: {LogisticsId.GetCounter(loadId)}");     // 42
Console.WriteLine($"  Formatted: {LogisticsId.FormatForLogging(loadId)}"); // "SITE_A@2025-10-03 19:59:53#42"

// IDs are naturally time-ordered for queries
var ids = new[] { id1, id2, id3 };
var sortedIds = ids.OrderBy(id => id).ToArray(); // Chronologically ordered!
```

### **Why This Approach is Perfect for Logistics**

| Requirement | Simple Site-Prefixed | Complex UUIDv7 | Winner |
|-------------|----------------------|----------------|---------|
| **Debuggability** | Can extract site, time, counter | Opaque binary data | 🏆 **Simple** |
| **Implementation** | ~50 lines, no dependencies | 100+ lines, byte conversion | 🏆 **Simple** |
| **Offline Safety** | Site isolation prevents conflicts | Global uniqueness (overkill) | 🏆 **Simple** |
| **Performance** | Direct bit operations | UUID generation + conversion | 🏆 **Simple** |
| **Business Alignment** | Embedded site context | Generic UUID format | 🏆 **Simple** |
| **Troubleshooting** | Human-readable breakdown | Requires conversion tools | 🏆 **Simple** |

**Example: Debugging Production Issue**
```csharp
// Simple approach - immediately understand what this ID represents
var problematicId = UInt128.Parse("some_value_from_logs");
Console.WriteLine(LogisticsId.FormatForLogging(problematicId));
// Output: "SITE_A@2025-10-03 14:23:17#1534"
// You immediately know: Site A, created this afternoon, sequence 1534

// Complex approach - need tools and documentation to decode
// UUID has no business context embedded
```

---

## 📊 **Data Model Design**

### **Ledger Structure**

```csharp
/// <summary>
/// Logical grouping of accounts by business domain
/// </summary>
public enum LogisticsLedger : uint
{
    // Entity Master Data
    Sites = 1,              // Site operations and balances
    Vendors = 2,            // Vendor accounts and payables
    Carriers = 3,           // Trucking company accounts
    Products = 4,           // Product/commodity tracking
    
    // Operational Tracking
    Loads = 10,             // Individual load lifecycle
    LoadRevenue = 11,       // Revenue recognition per load
    LoadExpenses = 12,      // Expense tracking per load
    LoadOperations = 13,    // Operational state transitions
    
    // Financial Accounting
    AccountsReceivable = 20, // Customer invoices and payments
    AccountsPayable = 21,    // Vendor bills and payments
    CashAccounts = 22,       // Bank accounts and cash flow
    RevenueAccounts = 23,    // Revenue recognition
    ExpenseAccounts = 24,    // Expense recognition
    
    // Site-Specific Operations
    SiteInventory = 30,      // Inventory at each site
    SiteEquipment = 31,      // Equipment and assets per site
    SiteOperatingExpenses = 32, // Site-specific operational costs
    
    // Inter-Company Transactions
    InterSiteTransfers = 40, // Transfers between sites
    CorporateAllocations = 41, // Corporate cost allocations
}
```

### **Account Code Structure**

```csharp
/// <summary>
/// Specific account types within each ledger
/// </summary>
public enum AccountCode : uint
{
    // Site Account Types (Ledger: Sites)
    SiteOperations = 1000,
    SiteRevenue = 1001,
    SiteExpenses = 1002,
    SiteCash = 1003,
    SiteInventoryAsset = 1004,
    
    // Load Account Types (Ledger: Loads)
    LoadCreated = 2000,        // Load in created state
    LoadAssigned = 2001,       // Load assigned to carrier
    LoadInTransit = 2002,      // Load in transit
    LoadDelivered = 2003,      // Load delivered
    LoadCompleted = 2004,      // Load financially closed
    LoadCancelled = 2005,      // Load cancelled
    
    // Revenue Account Types (Ledger: LoadRevenue)
    BaseFreight = 3000,        // Base freight charges
    FuelSurcharge = 3001,      // Fuel surcharge
    AccessorialCharges = 3002,  // Additional charges (detention, etc.)
    
    // Expense Account Types (Ledger: LoadExpenses)
    CarrierPayment = 4000,     // Payment to carrier
    FuelCosts = 4001,          // Fuel expenses
    OperatingExpenses = 4002,   // Other operational expenses
    
    // Entity Account Types
    VendorPayable = 5000,      // Amount owed to vendor
    CarrierPayable = 5001,     // Amount owed to carrier
    CustomerReceivable = 5002,  // Amount owed by customer
    
    // Cash Account Types
    OperatingCash = 6000,      // Main operating cash account
    PayrollCash = 6001,        // Payroll cash account
    TaxReserveCash = 6002,     // Tax reserve account
}
```

---

## 🗃️ **Account Structure**

### **Master Entity Accounts**

```csharp
/// <summary>
/// Creates master data accounts for vendors, carriers, products
/// </summary>
public class MasterEntityService
{
    public async Task<UInt128> CreateVendorAccountAsync(string vendorCode, string vendorName)
    {
        var vendorId = LogisticsId.GenerateEntityId("VENDOR", vendorCode);
        var metadata = EntityMetadata.PackVendorMetadata(vendorCode, vendorName);
        
        var vendorAccount = new Account
        {
            Id = vendorId,
            Ledger = (uint)LogisticsLedger.Vendors,
            Code = (uint)AccountCode.VendorPayable,
            UserData128 = metadata.userData128,
            UserData64 = metadata.userData64,
            UserData32 = metadata.userData32,
            Flags = AccountFlags.None
        };
        
        var result = await _tigerBeetle.CreateAccountsAsync(new[] { vendorAccount });
        if (result.Length > 0)
            throw new LogisticsException($"Failed to create vendor {vendorCode}: {result[0].Result}");
            
        return vendorId;
    }
    
    public async Task<UInt128> CreateCarrierAccountAsync(string carrierCode, string carrierName)
    {
        var carrierId = LogisticsId.GenerateEntityId("CARRIER", carrierCode);
        var metadata = EntityMetadata.PackCarrierMetadata(carrierCode, carrierName);
        
        var carrierAccount = new Account
        {
            Id = carrierId,
            Ledger = (uint)LogisticsLedger.Carriers,
            Code = (uint)AccountCode.CarrierPayable,
            UserData128 = metadata.userData128,
            UserData64 = metadata.userData64,
            UserData32 = metadata.userData32,
            Flags = AccountFlags.None
        };
        
        var result = await _tigerBeetle.CreateAccountsAsync(new[] { carrierAccount });
        if (result.Length > 0)
            throw new LogisticsException($"Failed to create carrier {carrierCode}: {result[0].Result}");
            
        return carrierId;
    }
}
```

### **Site-Specific Accounts**

```csharp
/// <summary>
/// Creates operational accounts for each site
/// </summary>
public class SiteAccountService
{
    public async Task InitializeSiteAccountsAsync(string siteCode, string siteName)
    {
        var accounts = new List<Account>();
        
        // Site Operations Account
        accounts.Add(new Account
        {
            Id = LogisticsId.GenerateEntityId("SITE_OPS", siteCode),
            Ledger = (uint)LogisticsLedger.Sites,
            Code = (uint)AccountCode.SiteOperations,
            UserData128 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "OPERATIONS").userData128,
            UserData64 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "OPERATIONS").userData64,
            UserData32 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "OPERATIONS").userData32
        });
        
        // Site Revenue Account
        accounts.Add(new Account
        {
            Id = LogisticsId.GenerateEntityId("SITE_REV", siteCode),
            Ledger = (uint)LogisticsLedger.Sites,
            Code = (uint)AccountCode.SiteRevenue,
            UserData128 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "REVENUE").userData128,
            UserData64 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "REVENUE").userData64,
            UserData32 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "REVENUE").userData32
        });
        
        // Site Cash Account
        accounts.Add(new Account
        {
            Id = LogisticsId.GenerateEntityId("SITE_CASH", siteCode),
            Ledger = (uint)LogisticsLedger.CashAccounts,
            Code = (uint)AccountCode.OperatingCash,
            UserData128 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "CASH").userData128,
            UserData64 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "CASH").userData64,
            UserData32 = EntityMetadata.PackSiteMetadata(siteCode, siteName, "CASH").userData32
        });
        
        var result = await _tigerBeetle.CreateAccountsAsync(accounts.ToArray());
        
        if (result.Length > 0)
        {
            var errors = string.Join(", ", result.Select(e => e.Result));
            throw new LogisticsException($"Failed to initialize site {siteCode}: {errors}");
        }
    }
}
```

---

## 🚚 **Load Lifecycle Implementation**

### **Load State Machine**

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   CREATED   │───►│   ASSIGNED  │───►│ IN_TRANSIT  │───►│  DELIVERED  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                                       │
       │                  │                                       ▼
       │                  │                              ┌─────────────┐
       │                  │                              │  COMPLETED  │
       │                  │                              └─────────────┘
       │                  ▼
       │           ┌─────────────┐
       └──────────►│  CANCELLED  │
                   └─────────────┘
```

### **Load Creation Service**

```csharp
/// <summary>
/// Manages the complete load lifecycle with TigerBeetle accounting
/// </summary>
public class LoadLifecycleService
{
    private readonly ITigerBeetleClient _tigerBeetle;
    private readonly ILoadReferenceService _referenceService;
    private readonly IOfflineBufferService _offlineBuffer;
    
    /// <summary>
    /// Creates a new load and establishes its accounting foundation
    /// </summary>
    public async Task<LoadCreationResult> CreateLoadAsync(CreateLoadRequest request)
    {
        var loadId = LogisticsId.GenerateLoadId(request.SiteCode);
        var humanRef = $"{request.SiteCode}-{request.LoadNumber}";
        
        // Pack load metadata into TigerBeetle UserData fields
        var metadata = LoadMetadata.PackLoadMetadata(
            request.SiteCode,
            request.LoadNumber,
            request.CarrierCode,
            request.ProductCode,
            request.EstimatedRevenue,
            request.EstimatedCost
        );
        
        var transfers = new List<Transfer>();
        
        // 1. Create load account
        var loadAccount = new Account
        {
            Id = loadId,
            Ledger = (uint)LogisticsLedger.Loads,
            Code = (uint)AccountCode.LoadCreated,
            UserData128 = metadata.userData128,
            UserData64 = metadata.userData64,
            UserData32 = metadata.userData32
        };
        
        // 2. Initial accounting entry: Site Operations -> Load
        transfers.Add(new Transfer
        {
            Id = LogisticsId.GenerateTransferId(request.SiteCode, "LOAD_CREATE"),
            DebitAccountId = await GetSiteOperationsAccountId(request.SiteCode),
            CreditAccountId = loadId,
            Amount = (ulong)(request.EstimatedRevenue * 100), // Convert to cents
            Ledger = (uint)LogisticsLedger.Loads,
            Code = (uint)AccountCode.LoadCreated,
            UserData128 = loadId, // Reference back to load
            UserData64 = (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            UserData32 = (uint)LoadState.Created
        });
        
        try
        {
            // Try to execute immediately (online mode)
            var accountResult = await _tigerBeetle.CreateAccountsAsync(new[] { loadAccount });
            if (accountResult.Length > 0)
                throw new TigerBeetleException($"Account creation failed: {accountResult[0].Result}");
            
            var transferResult = await _tigerBeetle.CreateTransfersAsync(transfers.ToArray());
            if (transferResult.Length > 0)
                throw new TigerBeetleException($"Transfer creation failed: {transferResult[0].Result}");
            
            // Store reference mapping
            await _referenceService.StoreLoadReferenceAsync(loadId, request.SiteCode, request.LoadNumber);
            
            return new LoadCreationResult
            {
                LoadId = loadId,
                HumanReference = humanRef,
                Status = LoadStatus.Created,
                IsOffline = false
            };
        }
        catch (TigerBeetleConnectionException)
        {
            // Offline mode - buffer for later sync
            await _offlineBuffer.BufferAccountCreationAsync(loadAccount);
            await _offlineBuffer.BufferTransfersAsync(transfers.ToArray());
            await _referenceService.StoreLoadReferenceAsync(loadId, request.SiteCode, request.LoadNumber);
            
            return new LoadCreationResult
            {
                LoadId = loadId,
                HumanReference = humanRef,
                Status = LoadStatus.CreatedOffline,
                IsOffline = true
            };
        }
    }
    
    /// <summary>
    /// Assigns load to a carrier with financial implications
    /// </summary>
    public async Task<LoadAssignmentResult> AssignLoadAsync(AssignLoadRequest request)
    {
        var loadId = await _referenceService.GetTigerBeetleIdAsync(request.SiteCode, request.LoadNumber);
        var carrierId = await GetCarrierAccountId(request.CarrierCode);
        
        var transfers = new List<Transfer>();
        
        // 1. State transition: Created -> Assigned
        transfers.Add(new Transfer
        {
            Id = LogisticsId.GenerateTransferId(request.SiteCode, "LOAD_ASSIGN"),
            DebitAccountId = loadId,
            CreditAccountId = loadId, // Self-transfer for state change
            Amount = 1, // Nominal amount for state tracking
            Ledger = (uint)LogisticsLedger.LoadOperations,
            Code = (uint)AccountCode.LoadAssigned,
            UserData128 = carrierId, // Reference to assigned carrier
            UserData64 = (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            UserData32 = (uint)LoadState.Assigned
        });
        
        // 2. Establish carrier liability
        transfers.Add(new Transfer
        {
            Id = LogisticsId.GenerateTransferId(request.SiteCode, "CARRIER_LIABILITY"),
            DebitAccountId = loadId,
            CreditAccountId = carrierId,
            Amount = (ulong)(request.CarrierRate * 100), // Carrier payment obligation
            Ledger = (uint)LogisticsLedger.LoadExpenses,
            Code = (uint)AccountCode.CarrierPayment,
            UserData128 = loadId,
            UserData64 = (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            UserData32 = (uint)LoadState.Assigned
        });
        
        try
        {
            var result = await _tigerBeetle.CreateTransfersAsync(transfers.ToArray());
            if (result.Length > 0)
                throw new TigerBeetleException($"Assignment failed: {result[0].Result}");
            
            return new LoadAssignmentResult
            {
                LoadId = loadId,
                CarrierId = carrierId,
                Status = LoadStatus.Assigned,
                IsOffline = false
            };
        }
        catch (TigerBeetleConnectionException)
        {
            await _offlineBuffer.BufferTransfersAsync(transfers.ToArray());
            
            return new LoadAssignmentResult
            {
                LoadId = loadId,
                CarrierId = carrierId,
                Status = LoadStatus.AssignedOffline,
                IsOffline = true
            };
        }
    }
    
    /// <summary>
    /// Completes load and recognizes revenue
    /// </summary>
    public async Task<LoadCompletionResult> CompleteLoadAsync(CompleteLoadRequest request)
    {
        var loadId = await _referenceService.GetTigerBeetleIdAsync(request.SiteCode, request.LoadNumber);
        var siteRevenueAccountId = await GetSiteRevenueAccountId(request.SiteCode);
        
        var transfers = new List<Transfer>();
        
        // 1. Revenue recognition
        transfers.Add(new Transfer
        {
            Id = LogisticsId.GenerateTransferId(request.SiteCode, "REVENUE_RECOGNITION"),
            DebitAccountId = siteRevenueAccountId,
            CreditAccountId = loadId,
            Amount = (ulong)(request.ActualRevenue * 100),
            Ledger = (uint)LogisticsLedger.LoadRevenue,
            Code = (uint)AccountCode.BaseFreight,
            UserData128 = loadId,
            UserData64 = (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            UserData32 = (uint)LoadState.Completed
        });
        
        // 2. State transition to completed
        transfers.Add(new Transfer
        {
            Id = LogisticsId.GenerateTransferId(request.SiteCode, "LOAD_COMPLETE"),
            DebitAccountId = loadId,
            CreditAccountId = loadId, // Self-transfer for state change
            Amount = 1,
            Ledger = (uint)LogisticsLedger.LoadOperations,
            Code = (uint)AccountCode.LoadCompleted,
            UserData128 = 0,
            UserData64 = (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            UserData32 = (uint)LoadState.Completed
        });
        
        try
        {
            var result = await _tigerBeetle.CreateTransfersAsync(transfers.ToArray());
            if (result.Length > 0)
                throw new TigerBeetleException($"Completion failed: {result[0].Result}");
            
            return new LoadCompletionResult
            {
                LoadId = loadId,
                ActualRevenue = request.ActualRevenue,
                Status = LoadStatus.Completed,
                IsOffline = false
            };
        }
        catch (TigerBeetleConnectionException)
        {
            await _offlineBuffer.BufferTransfersAsync(transfers.ToArray());
            
            return new LoadCompletionResult
            {
                LoadId = loadId,
                ActualRevenue = request.ActualRevenue,
                Status = LoadStatus.CompletedOffline,
                IsOffline = true
            };
        }
    }
}
```

---

## 📡 **Offline Site Synchronization**

### **Offline Buffer Service**

```csharp
/// <summary>
/// Handles offline buffering and synchronization of TigerBeetle operations
/// </summary>
public class OfflineBufferService : IOfflineBufferService
{
    private readonly ILogger<OfflineBufferService> _logger;
    private readonly ITigerBeetleClient _tigerBeetle;
    private readonly ISqliteBufferRepository _bufferRepo;
    
    /// <summary>
    /// Buffers account creation for offline sync
    /// </summary>
    public async Task BufferAccountCreationAsync(Account account)
    {
        var buffer = new BufferedOperation
        {
            Id = Guid.NewGuid(),
            OperationType = "CREATE_ACCOUNT",
            TigerBeetleId = account.Id,
            SiteCode = ExtractSiteCode(account),
            Data = JsonSerializer.Serialize(account),
            CreatedAt = DateTime.UtcNow,
            Status = BufferStatus.Pending
        };
        
        await _bufferRepo.StoreAsync(buffer);
        _logger.LogInformation("Buffered account creation: {AccountId}", account.Id);
    }
    
    /// <summary>
    /// Buffers transfers for offline sync
    /// </summary>
    public async Task BufferTransfersAsync(Transfer[] transfers)
    {
        var buffers = transfers.Select(transfer => new BufferedOperation
        {
            Id = Guid.NewGuid(),
            OperationType = "CREATE_TRANSFER",
            TigerBeetleId = transfer.Id,
            SiteCode = ExtractSiteCode(transfer),
            Data = JsonSerializer.Serialize(transfer),
            CreatedAt = DateTime.UtcNow,
            Status = BufferStatus.Pending
        });
        
        await _bufferRepo.StoreBatchAsync(buffers);
        _logger.LogInformation("Buffered {Count} transfers", transfers.Length);
    }
    
    /// <summary>
    /// Synchronizes buffered operations when connectivity is restored
    /// </summary>
    public async Task SynchronizeBufferedOperationsAsync()
    {
        if (!await _tigerBeetle.IsHealthyAsync())
        {
            _logger.LogWarning("TigerBeetle not healthy, skipping sync");
            return;
        }
        
        var pendingOps = await _bufferRepo.GetPendingOperationsAsync();
        
        foreach (var op in pendingOps)
        {
            try
            {
                switch (op.OperationType)
                {
                    case "CREATE_ACCOUNT":
                        var account = JsonSerializer.Deserialize<Account>(op.Data);
                        await SyncAccountAsync(op, account);
                        break;
                        
                    case "CREATE_TRANSFER":
                        var transfer = JsonSerializer.Deserialize<Transfer>(op.Data);
                        await SyncTransferAsync(op, transfer);
                        break;
                        
                    default:
                        _logger.LogWarning("Unknown operation type: {Type}", op.OperationType);
                        break;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to sync operation {OpId}", op.Id);
                await _bufferRepo.MarkFailedAsync(op.Id, ex.Message);
            }
        }
    }
    
    private async Task SyncAccountAsync(BufferedOperation op, Account account)
    {
        var result = await _tigerBeetle.CreateAccountsAsync(new[] { account });
        
        if (result.Length == 0)
        {
            await _bufferRepo.MarkSyncedAsync(op.Id);
            _logger.LogInformation("Synced account creation: {AccountId}", account.Id);
        }
        else if (result[0].Result == CreateAccountResult.exists)
        {
            // Account already exists - mark as synced
            await _bufferRepo.MarkSyncedAsync(op.Id);
            _logger.LogInformation("Account already exists: {AccountId}", account.Id);
        }
        else
        {
            throw new TigerBeetleSyncException($"Account sync failed: {result[0].Result}");
        }
    }
    
    private async Task SyncTransferAsync(BufferedOperation op, Transfer transfer)
    {
        var result = await _tigerBeetle.CreateTransfersAsync(new[] { transfer });
        
        if (result.Length == 0)
        {
            await _bufferRepo.MarkSyncedAsync(op.Id);
            _logger.LogInformation("Synced transfer: {TransferId}", transfer.Id);
        }
        else if (result[0].Result == CreateTransferResult.exists)
        {
            // Transfer already exists - mark as synced
            await _bufferRepo.MarkSyncedAsync(op.Id);
            _logger.LogInformation("Transfer already exists: {TransferId}", transfer.Id);
        }
        else
        {
            throw new TigerBeetleSyncException($"Transfer sync failed: {result[0].Result}");
        }
    }
}
```

### **Conflict Resolution Strategy**

```csharp
/// <summary>
/// Handles conflicts during offline synchronization
/// </summary>
public class ConflictResolutionService
{
    /// <summary>
    /// Resolves conflicts when buffered operations fail during sync
    /// </summary>
    public async Task<ConflictResolution> ResolveConflictAsync(
        BufferedOperation operation, 
        TigerBeetleException error)
    {
        switch (error.ErrorCode)
        {
            case "exists":
                // Operation already exists - safe to ignore
                return new ConflictResolution
                {
                    Action = ConflictAction.Ignore,
                    Reason = "Operation already applied"
                };
                
            case "accounts_must_be_unique":
                // Account ID collision - need to investigate
                return await HandleAccountCollisionAsync(operation);
                
            case "exceeds_credits":
                // Insufficient balance - need business logic resolution
                return await HandleInsufficientBalanceAsync(operation);
                
            default:
                // Unknown error - needs manual intervention
                return new ConflictResolution
                {
                    Action = ConflictAction.Manual,
                    Reason = $"Unknown error: {error.Message}"
                };
        }
    }
    
    private async Task<ConflictResolution> HandleAccountCollisionAsync(BufferedOperation operation)
    {
        // Check if account with same business key already exists
        var account = JsonSerializer.Deserialize<Account>(operation.Data);
        var existing = await FindAccountByMetadataAsync(account.UserData128, account.UserData64);
        
        if (existing != null)
        {
            return new ConflictResolution
            {
                Action = ConflictAction.Ignore,
                Reason = "Equivalent account already exists"
            };
        }
        
        // Generate new ID and retry
        var newAccount = account with { Id = LogisticsId.GenerateLoadId(operation.SiteCode) };
        
        return new ConflictResolution
        {
            Action = ConflictAction.Retry,
            ModifiedOperation = JsonSerializer.Serialize(newAccount),
            Reason = "Generated new unique ID"
        };
    }
}
```

---

## 🌐 **Network & Security Architecture**

### **VPN Configuration**

```yaml
# Corporate TigerBeetle Cluster
version: '3.8'
services:
  tigerbeetle-corp-0:
    image: ghcr.io/tigerbeetle/tigerbeetle:0.16.60
    container_name: tigerbeetle-corp-primary
    restart: unless-stopped
    privileged: true
    ports:
      - "10.1.0.10:3000:3000"  # Bind to VPN interface only
    volumes:
      - /corp-production/data/replica0:/data
      - /corp-production/logs:/logs
    environment:
      - TB_LOG_LEVEL=info
    networks:
      - tigerbeetle-cluster
    command: >
      start --addresses=10.1.0.10:3000,10.1.0.11:3001,10.1.0.12:3002 
      /data/cluster_0.tigerbeetle
    
  tigerbeetle-corp-1:
    image: ghcr.io/tigerbeetle/tigerbeetle:0.16.60
    container_name: tigerbeetle-corp-secondary1
    restart: unless-stopped
    privileged: true
    ports:
      - "10.1.0.11:3001:3001"
    volumes:
      - /corp-production/data/replica1:/data
      - /corp-production/logs:/logs
    networks:
      - tigerbeetle-cluster
    command: >
      start --addresses=10.1.0.10:3000,10.1.0.11:3001,10.1.0.12:3002 
      /data/cluster_1.tigerbeetle
    
  tigerbeetle-corp-2:
    image: ghcr.io/tigerbeetle/tigerbeetle:0.16.60
    container_name: tigerbeetle-corp-secondary2
    restart: unless-stopped
    privileged: true
    ports:
      - "10.1.0.12:3002:3002"
    volumes:
      - /corp-production/data/replica2:/data
      - /corp-production/logs:/logs
    networks:
      - tigerbeetle-cluster
    command: >
      start --addresses=10.1.0.10:3000,10.1.0.11:3001,10.1.0.12:3002 
      /data/cluster_2.tigerbeetle

networks:
  tigerbeetle-cluster:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### **Site Application Configuration**

```json
{
  "TigerBeetle": {
    "ClusterAddresses": [
      "10.1.0.10:3000",
      "10.1.0.11:3001",
      "10.1.0.12:3002"
    ],
    "ConnectionTimeout": "30s",
    "MaxRetries": 5,
    "RetryBackoffMs": 1000,
    "HealthCheckIntervalSeconds": 30
  },
  "Site": {
    "SiteCode": "SITE_A",
    "SiteName": "Distribution Center A",
    "TimeZone": "America/New_York",
    "Region": "Northeast"
  },
  "OfflineBuffer": {
    "MaxBufferSize": 10000,
    "SyncIntervalSeconds": 60,
    "BufferDatabasePath": "/app/data/offline_buffer.db",
    "RetryAttempts": 3,
    "RetryBackoffSeconds": 300
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "TigerBeetle": "Information",
      "OfflineBuffer": "Debug"
    }
  }
}
```

---

## 🛠️ **Implementation Services**

### **Load Reference Service**

```csharp
/// <summary>
/// Maps human-readable load references to TigerBeetle UInt128 IDs
/// </summary>
public class LoadReferenceService : ILoadReferenceService
{
    private readonly IDbConnection _db;
    
    public async Task StoreLoadReferenceAsync(UInt128 tigerBeetleId, string siteCode, string loadNumber)
    {
        var sql = @"
            INSERT INTO load_references (
                tigerbeetle_id, site_code, load_number, created_at
            ) VALUES (
                @TigerBeetleId, @SiteCode, @LoadNumber, @CreatedAt
            )
            ON CONFLICT (site_code, load_number) 
            DO UPDATE SET tigerbeetle_id = @TigerBeetleId";
        
        await _db.ExecuteAsync(sql, new
        {
            TigerBeetleId = TigerBeetleIdToBytes(tigerBeetleId),
            SiteCode = siteCode,
            LoadNumber = loadNumber,
            CreatedAt = DateTime.UtcNow
        });
    }
    
    public async Task<UInt128> GetTigerBeetleIdAsync(string siteCode, string loadNumber)
    {
        var sql = @"
            SELECT tigerbeetle_id 
            FROM load_references 
            WHERE site_code = @SiteCode AND load_number = @LoadNumber";
        
        var bytes = await _db.QuerySingleOrDefaultAsync<byte[]>(sql, new
        {
            SiteCode = siteCode,
            LoadNumber = loadNumber
        });
        
        if (bytes == null)
            throw new LoadNotFoundException($"Load {siteCode}-{loadNumber} not found");
        
        return BytesToTigerBeetleId(bytes);
    }
    
    public async Task<LoadReference> GetLoadReferenceAsync(UInt128 tigerBeetleId)
    {
        var sql = @"
            SELECT site_code, load_number, created_at
            FROM load_references 
            WHERE tigerbeetle_id = @TigerBeetleId";
        
        var result = await _db.QuerySingleOrDefaultAsync<LoadReference>(sql, new
        {
            TigerBeetleId = TigerBeetleIdToBytes(tigerBeetleId)
        });
        
        if (result == null)
            throw new LoadNotFoundException($"TigerBeetle ID {tigerBeetleId} not found");
        
        return result;
    }
    
    private static byte[] TigerBeetleIdToBytes(UInt128 id)
    {
        var bytes = new byte[16];
        BinaryPrimitives.WriteUInt64BigEndian(bytes.AsSpan(0, 8), (ulong)(id >> 64));
        BinaryPrimitives.WriteUInt64BigEndian(bytes.AsSpan(8, 8), (ulong)id);
        return bytes;
    }
    
    private static UInt128 BytesToTigerBeetleId(byte[] bytes)
    {
        var high = BinaryPrimitives.ReadUInt64BigEndian(bytes.AsSpan(0, 8));
        var low = BinaryPrimitives.ReadUInt64BigEndian(bytes.AsSpan(8, 8));
        return new UInt128(high, low);
    }
}
```

### **Metadata Packing Services**

```csharp
/// <summary>
/// Utilities for packing business data into TigerBeetle UserData fields
/// </summary>
public static class LoadMetadata
{
    /// <summary>
    /// Packs load information into TigerBeetle UserData fields
    /// </summary>
    public static (UInt128 userData128, ulong userData64, uint userData32) PackLoadMetadata(
        string siteCode,
        string loadNumber,
        string carrierCode,
        string productCode,
        decimal estimatedRevenue,
        decimal estimatedCost)
    {
        // UserData128: Site + Load Number (as hashes for uniqueness)
        var siteHash = (ulong)siteCode.GetHashCode();
        var loadHash = (ulong)loadNumber.GetHashCode();
        var userData128 = new UInt128(siteHash, loadHash);
        
        // UserData64: Carrier + Product (as hashes) + Revenue (scaled)
        var carrierHash = (uint)carrierCode.GetHashCode();
        var productHash = (uint)productCode.GetHashCode();
        var userData64 = ((ulong)carrierHash << 32) | (ulong)productHash;
        
        // UserData32: Estimated Revenue (in cents, limited to $42M max)
        var revenueCents = Math.Min((uint)(estimatedRevenue * 100), uint.MaxValue);
        var userData32 = revenueCents;
        
        return (userData128, userData64, userData32);
    }
    
    /// <summary>
    /// Unpacks load metadata from TigerBeetle UserData fields
    /// </summary>
    public static LoadMetadataInfo UnpackLoadMetadata(UInt128 userData128, ulong userData64, uint userData32)
    {
        // Extract hashes (note: these are one-way, need reference table for reverse lookup)
        var siteHash = (ulong)(userData128 >> 64);
        var loadHash = (ulong)userData128;
        var carrierHash = (uint)(userData64 >> 32);
        var productHash = (uint)userData64;
        var revenueCents = userData32;
        
        return new LoadMetadataInfo
        {
            SiteHash = siteHash,
            LoadHash = loadHash,
            CarrierHash = carrierHash,
            ProductHash = productHash,
            EstimatedRevenue = revenueCents / 100m
        };
    }
}

public static class EntityMetadata
{
    public static (UInt128 userData128, ulong userData64, uint userData32) PackVendorMetadata(
        string vendorCode, 
        string vendorName)
    {
        var vendorCodeHash = (ulong)vendorCode.GetHashCode();
        var vendorNameHash = (ulong)vendorName.GetHashCode();
        var userData128 = new UInt128(vendorCodeHash, vendorNameHash);
        
        var createdAt = (uint)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var userData64 = ((ulong)vendorCode.Length << 32) | (ulong)vendorName.Length;
        var userData32 = createdAt;
        
        return (userData128, userData64, userData32);
    }
    
    public static (UInt128 userData128, ulong userData64, uint userData32) PackSiteMetadata(
        string siteCode, 
        string siteName, 
        string accountType)
    {
        var siteCodeHash = (ulong)siteCode.GetHashCode();
        var siteNameHash = (ulong)siteName.GetHashCode();
        var userData128 = new UInt128(siteCodeHash, siteNameHash);
        
        var accountTypeHash = (uint)accountType.GetHashCode();
        var createdAt = (uint)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var userData64 = ((ulong)accountTypeHash << 32) | (ulong)createdAt;
        
        var siteEnum = GetSiteEnumValue(siteCode);
        var userData32 = siteEnum;
        
        return (userData128, userData64, userData32);
    }
    
    private static uint GetSiteEnumValue(string siteCode) => siteCode switch
    {
        "CORP" => 1,
        "SITE_A" => 2,
        "SITE_B" => 3,
        "SITE_C" => 4,
        "SITE_D" => 5,
        _ => 999
    };
}
```

---

## 🗄️ **Database Schema**

### **Reference Database Schema (SQLite/PostgreSQL)**

```sql
-- SQLite schema for load references and offline buffering
-- This runs at each site alongside the .NET application

-- Load reference mapping
CREATE TABLE load_references (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tigerbeetle_id BLOB NOT NULL UNIQUE,
    site_code TEXT NOT NULL,
    load_number TEXT NOT NULL,
    carrier_code TEXT,
    product_code TEXT,
    estimated_revenue DECIMAL(10,2),
    estimated_cost DECIMAL(10,2),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(site_code, load_number)
);

-- Indexes for performance
CREATE INDEX idx_load_references_site_code ON load_references(site_code);
CREATE INDEX idx_load_references_load_number ON load_references(load_number);
CREATE INDEX idx_load_references_created_at ON load_references(created_at);

-- Entity reference mapping
CREATE TABLE entity_references (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tigerbeetle_id BLOB NOT NULL UNIQUE,
    entity_type TEXT NOT NULL, -- 'VENDOR', 'CARRIER', 'PRODUCT', 'SITE'
    entity_code TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(entity_type, entity_code)
);

CREATE INDEX idx_entity_references_type_code ON entity_references(entity_type, entity_code);

-- Offline operation buffer
CREATE TABLE buffered_operations (
    id TEXT PRIMARY KEY, -- UUID
    operation_type TEXT NOT NULL, -- 'CREATE_ACCOUNT', 'CREATE_TRANSFER'
    tigerbeetle_id BLOB NOT NULL,
    site_code TEXT NOT NULL,
    operation_data TEXT NOT NULL, -- JSON serialized Account or Transfer
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'PENDING', -- 'PENDING', 'SYNCED', 'FAILED'
    sync_attempts INTEGER DEFAULT 0,
    last_sync_attempt DATETIME,
    error_message TEXT
);

CREATE INDEX idx_buffered_operations_status ON buffered_operations(status);
CREATE INDEX idx_buffered_operations_site_code ON buffered_operations(site_code);
CREATE INDEX idx_buffered_operations_created_at ON buffered_operations(created_at);

-- Master data cache (synced from corporate)
CREATE TABLE master_vendors (
    vendor_code TEXT PRIMARY KEY,
    vendor_name TEXT NOT NULL,
    tigerbeetle_id BLOB NOT NULL UNIQUE,
    last_sync DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE master_carriers (
    carrier_code TEXT PRIMARY KEY,
    carrier_name TEXT NOT NULL,
    tigerbeetle_id BLOB NOT NULL UNIQUE,
    last_sync DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE master_products (
    product_code TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    product_description TEXT,
    tigerbeetle_id BLOB NOT NULL UNIQUE,
    last_sync DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Load state tracking
CREATE TABLE load_states (
    load_id TEXT PRIMARY KEY, -- Site-LoadNumber format
    tigerbeetle_id BLOB NOT NULL UNIQUE,
    site_code TEXT NOT NULL,
    load_number TEXT NOT NULL,
    current_state TEXT NOT NULL, -- 'CREATED', 'ASSIGNED', 'IN_TRANSIT', etc.
    carrier_code TEXT,
    product_code TEXT,
    estimated_revenue DECIMAL(10,2),
    actual_revenue DECIMAL(10,2),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_load_states_site_code ON load_states(site_code);
CREATE INDEX idx_load_states_current_state ON load_states(current_state);
CREATE INDEX idx_load_states_created_at ON load_states(created_at);

-- Sync status tracking
CREATE TABLE sync_status (
    sync_type TEXT PRIMARY KEY, -- 'VENDORS', 'CARRIERS', 'PRODUCTS', 'OPERATIONS'
    last_successful_sync DATETIME,
    last_sync_attempt DATETIME,
    sync_status TEXT, -- 'SUCCESS', 'FAILED', 'IN_PROGRESS'
    records_synced INTEGER DEFAULT 0,
    error_message TEXT
);

-- Initialize sync status
INSERT OR REPLACE INTO sync_status (sync_type, sync_status) VALUES 
('VENDORS', 'NEVER'),
('CARRIERS', 'NEVER'), 
('PRODUCTS', 'NEVER'),
('OPERATIONS', 'NEVER');
```

---

## ⚙️ **Configuration Management**

### **Site Configuration Service**

```csharp
/// <summary>
/// Manages site-specific configuration and validation
/// </summary>
public class SiteConfigurationService : ISiteConfiguration
{
    private readonly IConfiguration _config;
    private readonly ILogger<SiteConfigurationService> _logger;
    
    public string SiteCode => _config["Site:SiteCode"] 
        ?? throw new InvalidOperationException("Site:SiteCode not configured");
    
    public string SiteName => _config["Site:SiteName"] 
        ?? throw new InvalidOperationException("Site:SiteName not configured");
    
    public TimeZoneInfo SiteTimeZone => TimeZoneInfo.FindSystemTimeZoneById(
        _config["Site:TimeZone"] ?? "UTC");
    
    public TigerBeetleConfiguration TigerBeetleConfig => new()
    {
        ClusterAddresses = _config.GetSection("TigerBeetle:ClusterAddresses")
            .Get<string[]>() ?? throw new InvalidOperationException("TigerBeetle addresses not configured"),
        ConnectionTimeout = TimeSpan.Parse(_config["TigerBeetle:ConnectionTimeout"] ?? "30s"),
        MaxRetries = _config.GetValue<int>("TigerBeetle:MaxRetries", 5),
        RetryBackoffMs = _config.GetValue<int>("TigerBeetle:RetryBackoffMs", 1000),
        HealthCheckInterval = TimeSpan.FromSeconds(
            _config.GetValue<int>("TigerBeetle:HealthCheckIntervalSeconds", 30))
    };
    
    public OfflineBufferConfiguration OfflineBufferConfig => new()
    {
        MaxBufferSize = _config.GetValue<int>("OfflineBuffer:MaxBufferSize", 10000),
        SyncInterval = TimeSpan.FromSeconds(
            _config.GetValue<int>("OfflineBuffer:SyncIntervalSeconds", 60)),
        BufferDatabasePath = _config["OfflineBuffer:BufferDatabasePath"] 
            ?? "/app/data/offline_buffer.db",
        RetryAttempts = _config.GetValue<int>("OfflineBuffer:RetryAttempts", 3),
        RetryBackoff = TimeSpan.FromSeconds(
            _config.GetValue<int>("OfflineBuffer:RetryBackoffSeconds", 300))
    };
    
    /// <summary>
    /// Validates configuration on startup
    /// </summary>
    public void ValidateConfiguration()
    {
        var errors = new List<string>();
        
        // Validate site configuration
        if (string.IsNullOrEmpty(SiteCode))
            errors.Add("Site code is required");
        
        if (SiteCode.Length > 10)
            errors.Add("Site code must be 10 characters or less");
        
        // Validate TigerBeetle configuration
        if (TigerBeetleConfig.ClusterAddresses.Length == 0)
            errors.Add("At least one TigerBeetle cluster address is required");
        
        foreach (var address in TigerBeetleConfig.ClusterAddresses)
        {
            if (!Uri.TryCreate($"tcp://{address}", UriKind.Absolute, out _))
                errors.Add($"Invalid TigerBeetle address: {address}");
        }
        
        // Validate offline buffer configuration
        var bufferDir = Path.GetDirectoryName(OfflineBufferConfig.BufferDatabasePath);
        if (!string.IsNullOrEmpty(bufferDir) && !Directory.Exists(bufferDir))
        {
            try
            {
                Directory.CreateDirectory(bufferDir);
            }
            catch (Exception ex)
            {
                errors.Add($"Cannot create buffer directory: {ex.Message}");
            }
        }
        
        if (errors.Any())
        {
            var message = "Configuration validation failed:\n" + string.Join("\n", errors);
            throw new InvalidOperationException(message);
        }
        
        _logger.LogInformation("Configuration validated successfully for site {SiteCode}", SiteCode);
    }
}
```

### **Environment-Specific Configurations**

```json
// appsettings.Development.json
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
    "SyncIntervalSeconds": 10,
    "BufferDatabasePath": "./dev_buffer.db"
  }
}
```

```json
// appsettings.Production.json
{
  "TigerBeetle": {
    "ClusterAddresses": [
      "10.1.0.10:3000",
      "10.1.0.11:3001", 
      "10.1.0.12:3002"
    ],
    "ConnectionTimeout": "30s",
    "MaxRetries": 5,
    "RetryBackoffMs": 2000,
    "HealthCheckIntervalSeconds": 60
  },
  "Site": {
    "SiteCode": "SITE_A",
    "SiteName": "Distribution Center Alpha",
    "TimeZone": "America/New_York",
    "Region": "Northeast"
  },
  "OfflineBuffer": {
    "MaxBufferSize": 50000,
    "SyncIntervalSeconds": 300,
    "BufferDatabasePath": "/app/data/production_buffer.db",
    "RetryAttempts": 5,
    "RetryBackoffSeconds": 600
  },
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "TigerBeetle": "Information",
      "LoadLifecycle": "Information",
      "OfflineBuffer": "Information"
    }
  }
}
```

---

## 📊 **Monitoring & Operations**

### **Health Check Implementation**

```csharp
/// <summary>
/// Comprehensive health checks for the logistics system
/// </summary>
public class LogisticsHealthCheck : IHealthCheck
{
    private readonly ITigerBeetleClient _tigerBeetle;
    private readonly IOfflineBufferService _offlineBuffer;
    private readonly ILoadReferenceService _referenceService;
    private readonly ILogger<LogisticsHealthCheck> _logger;
    
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var data = new Dictionary<string, object>();
        var isHealthy = true;
        var messages = new List<string>();
        
        // Check TigerBeetle connectivity
        try
        {
            var testAccountId = UInt128.MaxValue; // Non-existent account
            await _tigerBeetle.LookupAccountsAsync(new[] { testAccountId });
            
            data["tigerbeetle_status"] = "connected";
            messages.Add("TigerBeetle cluster is responsive");
        }
        catch (TigerBeetleConnectionException)
        {
            data["tigerbeetle_status"] = "disconnected";
            messages.Add("TigerBeetle cluster is not accessible - operating in offline mode");
            // Not necessarily unhealthy if we have offline capability
        }
        catch (Exception ex)
        {
            data["tigerbeetle_status"] = "error";
            messages.Add($"TigerBeetle error: {ex.Message}");
            isHealthy = false;
        }
        
        // Check offline buffer status
        try
        {
            var pendingCount = await _offlineBuffer.GetPendingOperationCountAsync();
            data["offline_buffer_pending"] = pendingCount;
            
            if (pendingCount > 1000)
            {
                messages.Add($"High number of pending operations: {pendingCount}");
                isHealthy = false;
            }
            else if (pendingCount > 0)
            {
                messages.Add($"Pending operations: {pendingCount}");
            }
        }
        catch (Exception ex)
        {
            data["offline_buffer_status"] = "error";
            messages.Add($"Offline buffer error: {ex.Message}");
            isHealthy = false;
        }
        
        // Check reference database
        try
        {
            var recentLoads = await _referenceService.GetRecentLoadCountAsync(TimeSpan.FromDays(1));
            data["loads_last_24h"] = recentLoads;
            messages.Add($"Processed {recentLoads} loads in last 24 hours");
        }
        catch (Exception ex)
        {
            data["reference_db_status"] = "error";
            messages.Add($"Reference database error: {ex.Message}");
            isHealthy = false;
        }
        
        var status = isHealthy ? HealthStatus.Healthy : HealthStatus.Unhealthy;
        var description = string.Join("; ", messages);
        
        return new HealthCheckResult(status, description, null, data);
    }
}
```

### **Metrics and Observability**

```csharp
/// <summary>
/// Custom metrics for logistics operations
/// </summary>
public class LogisticsMetrics
{
    private readonly IMetrics _metrics;
    
    public void RecordLoadCreated(string siteCode, bool wasOffline)
    {
        _metrics.CreateCounter("loads_created_total", "Total loads created")
            .WithTag("site", siteCode)
            .WithTag("mode", wasOffline ? "offline" : "online")
            .Increment();
    }
    
    public void RecordLoadCompleted(string siteCode, decimal revenue)
    {
        _metrics.CreateCounter("loads_completed_total", "Total loads completed")
            .WithTag("site", siteCode)
            .Increment();
        
        _metrics.CreateHistogram("load_revenue_dollars", "Load revenue distribution")
            .WithTag("site", siteCode)
            .Record((double)revenue);
    }
    
    public void RecordOfflineBufferSize(int pendingOperations)
    {
        _metrics.CreateGauge("offline_buffer_pending", "Pending offline operations")
            .Set(pendingOperations);
    }
    
    public void RecordSyncDuration(string operationType, TimeSpan duration, bool success)
    {
        _metrics.CreateHistogram("sync_duration_seconds", "Offline sync operation duration")
            .WithTag("operation", operationType)
            .WithTag("success", success.ToString().ToLower())
            .Record(duration.TotalSeconds);
    }
}
```

---

## 🧪 **Testing Strategy**

### **Unit Tests**

```csharp
[TestClass]
public class LoadLifecycleServiceTests
{
    private Mock<ITigerBeetleClient> _tigerBeetleMock;
    private Mock<ILoadReferenceService> _referenceServiceMock;
    private Mock<IOfflineBufferService> _offlineBufferMock;
    private LoadLifecycleService _service;
    
    [TestInitialize]
    public void Setup()
    {
        _tigerBeetleMock = new Mock<ITigerBeetleClient>();
        _referenceServiceMock = new Mock<ILoadReferenceService>();
        _offlineBufferMock = new Mock<IOfflineBufferService>();
        
        _service = new LoadLifecycleService(
            _tigerBeetleMock.Object,
            _referenceServiceMock.Object,
            _offlineBufferMock.Object);
    }
    
    [TestMethod]
    public async Task CreateLoadAsync_OnlineMode_CreatesAccountAndTransfer()
    {
        // Arrange
        var request = new CreateLoadRequest
        {
            SiteCode = "SITE_A",
            LoadNumber = "L001",
            CarrierCode = "XYZ",
            EstimatedRevenue = 1500m
        };
        
        _tigerBeetleMock.Setup(t => t.CreateAccountsAsync(It.IsAny<Account[]>()))
            .ReturnsAsync(Array.Empty<CreateAccountError>());
        
        _tigerBeetleMock.Setup(t => t.CreateTransfersAsync(It.IsAny<Transfer[]>()))
            .ReturnsAsync(Array.Empty<CreateTransferError>());
        
        // Act
        var result = await _service.CreateLoadAsync(request);
        
        // Assert
        Assert.IsFalse(result.IsOffline);
        Assert.AreEqual(LoadStatus.Created, result.Status);
        Assert.AreEqual("SITE_A-L001", result.HumanReference);
        
        _tigerBeetleMock.Verify(t => t.CreateAccountsAsync(It.IsAny<Account[]>()), Times.Once);
        _tigerBeetleMock.Verify(t => t.CreateTransfersAsync(It.IsAny<Transfer[]>()), Times.Once);
        _referenceServiceMock.Verify(r => r.StoreLoadReferenceAsync(
            It.IsAny<UInt128>(), "SITE_A", "L001"), Times.Once);
    }
    
    [TestMethod]
    public async Task CreateLoadAsync_OfflineMode_BuffersOperations()
    {
        // Arrange
        var request = new CreateLoadRequest
        {
            SiteCode = "SITE_A",
            LoadNumber = "L002",
            CarrierCode = "XYZ",
            EstimatedRevenue = 1500m
        };
        
        _tigerBeetleMock.Setup(t => t.CreateAccountsAsync(It.IsAny<Account[]>()))
            .ThrowsAsync(new TigerBeetleConnectionException("Connection failed"));
        
        // Act
        var result = await _service.CreateLoadAsync(request);
        
        // Assert
        Assert.IsTrue(result.IsOffline);
        Assert.AreEqual(LoadStatus.CreatedOffline, result.Status);
        
        _offlineBufferMock.Verify(o => o.BufferAccountCreationAsync(It.IsAny<Account>()), Times.Once);
        _offlineBufferMock.Verify(o => o.BufferTransfersAsync(It.IsAny<Transfer[]>()), Times.Once);
    }
}
```

### **Integration Tests**

```csharp
[TestClass]
public class LogisticsIntegrationTests
{
    private TestServer _server;
    private HttpClient _client;
    private ITigerBeetleClient _tigerBeetle;
    
    [TestInitialize]
    public async Task Setup()
    {
        // Start test TigerBeetle cluster
        await StartTestTigerBeetleCluster();
        
        // Create test web application
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddLogisticsServices(builder.Configuration);
        
        _server = new TestServer(builder);
        _client = _server.CreateClient();
    }
    
    [TestMethod]
    public async Task EndToEndLoadLifecycle_CreatesAndCompletesLoad()
    {
        // Create load
        var createRequest = new CreateLoadRequest
        {
            SiteCode = "TEST_SITE",
            LoadNumber = "INT001",
            CarrierCode = "TEST_CARRIER",
            ProductCode = "TEST_PRODUCT",
            EstimatedRevenue = 2000m
        };
        
        var createResponse = await _client.PostAsJsonAsync("/api/loads", createRequest);
        createResponse.EnsureSuccessStatusCode();
        
        var createResult = await createResponse.Content.ReadFromJsonAsync<LoadCreationResult>();
        
        // Assign load
        var assignRequest = new AssignLoadRequest
        {
            SiteCode = "TEST_SITE",
            LoadNumber = "INT001",
            CarrierCode = "TEST_CARRIER",
            CarrierRate = 1800m
        };
        
        var assignResponse = await _client.PostAsJsonAsync("/api/loads/assign", assignRequest);
        assignResponse.EnsureSuccessStatusCode();
        
        // Complete load
        var completeRequest = new CompleteLoadRequest
        {
            SiteCode = "TEST_SITE",
            LoadNumber = "INT001",
            ActualRevenue = 2100m
        };
        
        var completeResponse = await _client.PostAsJsonAsync("/api/loads/complete", completeRequest);
        completeResponse.EnsureSuccessStatusCode();
        
        // Verify final state
        var loadAccount = await _tigerBeetle.LookupAccountsAsync(new[] { createResult.LoadId });
        Assert.AreEqual(1, loadAccount.Length);
        
        // Verify accounting integrity
        var siteRevenueAccount = await GetSiteRevenueAccount("TEST_SITE");
        Assert.AreEqual(210000UL, siteRevenueAccount.CreditsPosted); // $2100 in cents
    }
}
```

---

## 🚀 **Deployment Plan**

### **Phase 1: Infrastructure Setup (Weeks 1-2)**

```bash
# Week 1: Corporate Infrastructure
1. Deploy TigerBeetle 3-node cluster at corporate
2. Set up monitoring stack (Prometheus + Grafana)
3. Configure backup procedures
4. Establish VPN connectivity to test site

# Week 2: Initial Data Setup
1. Create master entity accounts (vendors, carriers, products)
2. Initialize site accounts for corporate and test site
3. Load test data for validation
4. Set up reference databases
```

### **Phase 2: Pilot Site Deployment (Weeks 3-4)**

```bash
# Week 3: Site A Preparation
1. Deploy .NET application to Site A
2. Configure offline buffer database
3. Test connectivity to corporate TigerBeetle cluster
4. Initialize site-specific accounts

# Week 4: Pilot Operations
1. Create and process test loads end-to-end
2. Test offline scenarios with VPN disconnection
3. Validate synchronization when connectivity restored
4. Performance testing with expected load volume
```

### **Phase 3: Multi-Site Rollout (Weeks 5-8)**

```bash
# Week 5-6: Site B & C Deployment
1. Deploy to Site B and Site C in parallel
2. Test inter-site operations and data consistency
3. Monitor cross-site transaction patterns
4. Fine-tune sync intervals and buffer sizes

# Week 7-8: Remaining Sites + Optimization
1. Deploy to remaining sites
2. Optimize based on real-world usage patterns
3. Implement custom reporting and dashboards
4. Train operations staff on new system
```

### **Deployment Checklist per Site**

```markdown
## Site Deployment Checklist

### Pre-Deployment
- [ ] VPN connectivity established and tested
- [ ] Hardware/VM provisioned with required specs
- [ ] Docker installed and configured
- [ ] Site-specific configuration files prepared
- [ ] Network security rules configured

### Application Deployment
- [ ] .NET application container deployed
- [ ] Reference database initialized
- [ ] Offline buffer database created
- [ ] Health check endpoints responding
- [ ] Logging configured and working

### TigerBeetle Integration
- [ ] Connectivity to corporate cluster verified
- [ ] Site accounts created in TigerBeetle
- [ ] Test load creation and completion successful
- [ ] Offline buffer functionality tested
- [ ] Synchronization after outage verified

### Operations Validation
- [ ] Create test load and assign to carrier
- [ ] Complete load and verify revenue recognition
- [ ] Test offline operation during VPN outage
- [ ] Verify data consistency after reconnection
- [ ] Performance testing with expected volume

### Monitoring & Support
- [ ] Monitoring dashboards configured
- [ ] Alerting rules configured
- [ ] Backup procedures tested
- [ ] Operations team trained
- [ ] Support procedures documented
```

---

## 🔮 **Future Considerations**

### **Scalability Enhancements**

```markdown
## Potential Future Improvements

### Performance Optimizations
- **Connection Pooling**: Implement TigerBeetle connection pooling for high-volume sites
- **Batch Processing**: Group related operations for more efficient TigerBeetle usage
- **Read Replicas**: Consider read-only replicas for reporting and analytics
- **Caching Layer**: Add Redis for frequently accessed master data

### Business Logic Extensions
- **Multi-Currency Support**: Extend for international operations
- **Complex Revenue Recognition**: Handle more sophisticated billing scenarios  
- **Equipment Tracking**: Add equipment/asset management capabilities
- **Customer Billing**: Integrate with customer invoicing and collections

### Technology Upgrades
- **Event Sourcing**: Consider event-driven architecture for audit trails
- **GraphQL API**: Add GraphQL for more flexible client integrations
- **Real-time Updates**: Implement SignalR for live status updates
- **Mobile Applications**: Develop mobile apps for field operations

### Operational Improvements
- **Automated Reconciliation**: Daily reconciliation between systems
- **ML/AI Integration**: Predictive analytics for load optimization
- **Integration Expansion**: Connect to ERP, CRM, and other business systems
- **Advanced Reporting**: Business intelligence and analytics platform
```

### **Technical Debt Management**

```markdown
## Technical Debt Considerations

### Code Quality
- Regular refactoring of services as business logic evolves
- Maintain comprehensive test coverage as system grows
- Regular dependency updates and security patches

### Architecture Evolution
- Monitor performance characteristics as transaction volume grows
- Plan for potential TigerBeetle cluster expansion
- Consider service decomposition if monolith becomes unwieldy

### Data Management
- Plan for data archival and retention policies
- Consider partitioning strategies for large datasets
- Maintain backup and disaster recovery procedures
```

---

## 📝 **Document Change Log**

| Version | Date | Changes | Author |
|---------|------|---------|---------|
| 1.0 | Oct 3, 2025 | Initial design document creation | System Architect |
| | | | |
| | | | |

---

## 📞 **Support and Maintenance**

### **Key Contacts**
- **Technical Lead**: [Name] - [Email]
- **Operations Manager**: [Name] - [Email]  
- **Database Administrator**: [Name] - [Email]

### **Documentation References**
- TigerBeetle Official Documentation: https://docs.tigerbeetle.com
- .NET Client Reference: https://github.com/tigerbeetle/tigerbeetle/tree/main/src/clients/dotnet
- Internal Architecture Documentation: [Link to internal docs]

---

*This implementation design provides a complete blueprint for deploying TigerBeetle in a multi-site logistics environment with offline resilience and financial integrity.*