namespace LogisticsSystem.Core.Domain;

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

/// <summary>
/// Load lifecycle states
/// </summary>
public enum LoadState : uint
{
    Created = 1,
    Assigned = 2,
    InTransit = 3,
    Delivered = 4,
    Completed = 5,
    Cancelled = 9
}

/// <summary>
/// Load operation status for API responses
/// </summary>
public enum LoadStatus
{
    Created,
    CreatedOffline,
    Assigned,
    AssignedOffline,
    InTransit,
    InTransitOffline,
    Delivered,
    DeliveredOffline,
    Completed,
    CompletedOffline,
    Cancelled,
    CancelledOffline
}

/// <summary>
/// Offline buffer operation status
/// </summary>
public enum BufferStatus
{
    Pending,
    Synced,
    Failed,
    Retrying
}