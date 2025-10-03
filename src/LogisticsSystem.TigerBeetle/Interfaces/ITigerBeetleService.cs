using LogisticsSystem.Core.Domain;
using TigerBeetle;

namespace LogisticsSystem.TigerBeetle.Interfaces;

/// <summary>
/// Main interface for TigerBeetle operations
/// </summary>
public interface ITigerBeetleService
{
    Task<bool> IsHealthyAsync();
    Task<Account[]> LookupAccountsAsync(UInt128[] accountIds);
    Task<Transfer[]> LookupTransfersAsync(UInt128[] transferIds);
}

/// <summary>
/// Service for managing load lifecycle with TigerBeetle accounting
/// </summary>
public interface ILoadLifecycleService
{
    Task<LoadCreationResult> CreateLoadAsync(CreateLoadRequest request);
    Task<LoadAssignmentResult> AssignLoadAsync(AssignLoadRequest request);
    Task<LoadCompletionResult> CompleteLoadAsync(CompleteLoadRequest request);
}

/// <summary>
/// Service for managing master entities (vendors, carriers, products)
/// </summary>
public interface IMasterEntityService
{
    Task<UInt128> CreateVendorAccountAsync(string vendorCode, string vendorName);
    Task<UInt128> CreateCarrierAccountAsync(string carrierCode, string carrierName);
    Task<UInt128> CreateProductAccountAsync(string productCode, string productName);
}

/// <summary>
/// Service for managing site accounts and operations
/// </summary>
public interface ISiteAccountService
{
    Task InitializeSiteAccountsAsync(string siteCode, string siteName);
    Task<UInt128> GetSiteOperationsAccountId(string siteCode);
    Task<UInt128> GetSiteRevenueAccountId(string siteCode);
    Task<UInt128> GetSiteCashAccountId(string siteCode);
}

/// <summary>
/// Service for managing offline operations buffer
/// </summary>
public interface IOfflineBufferService
{
    Task BufferAccountCreationAsync(Account account);
    Task BufferTransfersAsync(Transfer[] transfers);
    Task<int> GetPendingOperationCountAsync();
    Task SynchronizeBufferedOperationsAsync();
}

/// <summary>
/// Service for mapping human-readable references to TigerBeetle IDs
/// </summary>
public interface ILoadReferenceService
{
    Task StoreLoadReferenceAsync(UInt128 tigerBeetleId, string siteCode, string loadNumber);
    Task<UInt128> GetTigerBeetleIdAsync(string siteCode, string loadNumber);
    Task<LoadReference> GetLoadReferenceAsync(UInt128 tigerBeetleId);
    Task<int> GetRecentLoadCountAsync(TimeSpan timeSpan);
}

/// <summary>
/// Exception thrown when TigerBeetle is not accessible
/// </summary>
public class TigerBeetleConnectionException : Exception
{
    public TigerBeetleConnectionException(string message) : base(message) { }
    public TigerBeetleConnectionException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>
/// Exception thrown when TigerBeetle operations fail
/// </summary>
public class TigerBeetleOperationException : Exception
{
    public TigerBeetleOperationException(string message) : base(message) { }
    public TigerBeetleOperationException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>
/// Exception thrown during offline synchronization
/// </summary>
public class TigerBeetleSyncException : Exception
{
    public TigerBeetleSyncException(string message) : base(message) { }
    public TigerBeetleSyncException(string message, Exception innerException) : base(message, innerException) { }
}