using LogisticsSystem.Core.Domain;
using LogisticsSystem.TigerBeetle.Interfaces;
using Microsoft.Extensions.Logging;
using TigerBeetle;

namespace LogisticsSystem.TigerBeetle.Services;

public class TigerBeetleService : ITigerBeetleService, IDisposable
{
    private readonly Client _client;
    private readonly ILogger<TigerBeetleService> _logger;
    private bool _disposed = false;

    public TigerBeetleService(TigerBeetleConfiguration config, ILogger<TigerBeetleService> logger)
    {
        _logger = logger;
        
        try
        {
            // Create TigerBeetle client with cluster addresses
            _client = new Client(0, config.ClusterAddresses);
            _logger.LogInformation("TigerBeetle client initialized with addresses: {Addresses}", 
                string.Join(", ", config.ClusterAddresses));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize TigerBeetle client");
            throw new TigerBeetleConnectionException("Failed to initialize TigerBeetle client", ex);
        }
    }

    public async Task<bool> IsHealthyAsync()
    {
        try
        {
            // Test connectivity with a non-existent account lookup
            var testAccountId = UInt128.MaxValue;
            await LookupAccountsAsync([testAccountId]);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "TigerBeetle health check failed");
            return false;
        }
    }

    public async Task<Account[]> LookupAccountsAsync(UInt128[] accountIds)
    {
        try
        {
            return await Task.Run(() => _client.LookupAccounts(accountIds));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to lookup accounts: {AccountIds}", string.Join(", ", accountIds));
            throw new TigerBeetleConnectionException("Failed to lookup accounts", ex);
        }
    }

    public async Task<Transfer[]> LookupTransfersAsync(UInt128[] transferIds)
    {
        try
        {
            return await Task.Run(() => _client.LookupTransfers(transferIds));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to lookup transfers: {TransferIds}", string.Join(", ", transferIds));
            throw new TigerBeetleConnectionException("Failed to lookup transfers", ex);
        }
    }

    public async Task<Account[]> CreateAccountsAsync(Account[] accounts)
    {
        try
        {
            var errors = await Task.Run(() => _client.CreateAccounts(accounts));
            if (errors.Length > 0)
            {
                var errorMsg = $"Account creation errors: {string.Join(", ", errors.Select(e => e.Result))}";
                throw new TigerBeetleOperationException(errorMsg);
            }
            return accounts; // Return created accounts on success
        }
        catch (Exception ex) when (ex is not TigerBeetleOperationException)
        {
            _logger.LogError(ex, "Failed to create accounts");
            throw new TigerBeetleOperationException("Failed to create accounts", ex);
        }
    }

    public async Task<Transfer[]> CreateTransfersAsync(Transfer[] transfers)
    {
        try
        {
            var errors = await Task.Run(() => _client.CreateTransfers(transfers));
            if (errors.Length > 0)
            {
                var errorMsg = $"Transfer creation errors: {string.Join(", ", errors.Select(e => e.Result))}";
                throw new TigerBeetleOperationException(errorMsg);
            }
            return transfers; // Return created transfers on success
        }
        catch (Exception ex) when (ex is not TigerBeetleOperationException)
        {
            _logger.LogError(ex, "Failed to create transfers");
            throw new TigerBeetleOperationException("Failed to create transfers", ex);
        }
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            _client?.Dispose();
            _disposed = true;
            _logger.LogInformation("TigerBeetle client disposed");
        }
    }
}