namespace LogisticsSystem.Core.Domain;

// ========== Request Models ==========

public record CreateLoadRequest
{
    public required string SiteCode { get; init; }
    public required string LoadNumber { get; init; }
    public required string CarrierCode { get; init; }
    public required string ProductCode { get; init; }
    public required decimal EstimatedRevenue { get; init; }
    public required decimal EstimatedCost { get; init; }
    public string? CustomerReference { get; init; }
    public string? Notes { get; init; }
}

public record AssignLoadRequest
{
    public required string SiteCode { get; init; }
    public required string LoadNumber { get; init; }
    public required string CarrierCode { get; init; }
    public required decimal CarrierRate { get; init; }
    public DateTime? PickupDate { get; init; }
    public DateTime? DeliveryDate { get; init; }
}

public record CompleteLoadRequest
{
    public required string SiteCode { get; init; }
    public required string LoadNumber { get; init; }
    public required decimal ActualRevenue { get; init; }
    public decimal? ActualCost { get; init; }
    public DateTime? CompletedAt { get; init; }
    public string? CompletionNotes { get; init; }
}

// ========== Response Models ==========

public record LoadCreationResult
{
    public required UInt128 LoadId { get; init; }
    public required string HumanReference { get; init; }
    public required LoadStatus Status { get; init; }
    public required bool IsOffline { get; init; }
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
}

public record LoadAssignmentResult
{
    public required UInt128 LoadId { get; init; }
    public required UInt128 CarrierId { get; init; }
    public required LoadStatus Status { get; init; }
    public required bool IsOffline { get; init; }
    public DateTime AssignedAt { get; init; } = DateTime.UtcNow;
}

public record LoadCompletionResult
{
    public required UInt128 LoadId { get; init; }
    public required decimal ActualRevenue { get; init; }
    public required LoadStatus Status { get; init; }
    public required bool IsOffline { get; init; }
    public DateTime CompletedAt { get; init; } = DateTime.UtcNow;
}

// ========== Entity Models ==========

public record LoadReference
{
    public required string SiteCode { get; init; }
    public required string LoadNumber { get; init; }
    public required UInt128 TigerBeetleId { get; init; }
    public string? CarrierCode { get; init; }
    public string? ProductCode { get; init; }
    public decimal? EstimatedRevenue { get; init; }
    public decimal? ActualRevenue { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime? UpdatedAt { get; init; }
}

public record VendorEntity
{
    public required string VendorCode { get; init; }
    public required string VendorName { get; init; }
    public required UInt128 TigerBeetleId { get; init; }
    public string? ContactInfo { get; init; }
    public DateTime CreatedAt { get; init; }
}

public record CarrierEntity
{
    public required string CarrierCode { get; init; }
    public required string CarrierName { get; init; }
    public required UInt128 TigerBeetleId { get; init; }
    public string? ContactInfo { get; init; }
    public DateTime CreatedAt { get; init; }
}

public record ProductEntity
{
    public required string ProductCode { get; init; }
    public required string ProductName { get; init; }
    public required UInt128 TigerBeetleId { get; init; }
    public string? Description { get; init; }
    public DateTime CreatedAt { get; init; }
}

// ========== Offline Buffer Models ==========

public record BufferedOperation
{
    public required Guid Id { get; init; }
    public required string OperationType { get; init; } // 'CREATE_ACCOUNT', 'CREATE_TRANSFER'
    public required UInt128 TigerBeetleId { get; init; }
    public required string SiteCode { get; init; }
    public required string Data { get; init; } // JSON serialized Account or Transfer
    public required DateTime CreatedAt { get; init; }
    public required BufferStatus Status { get; init; }
    public int SyncAttempts { get; init; }
    public DateTime? LastSyncAttempt { get; init; }
    public string? ErrorMessage { get; init; }
}

// ========== Configuration Models ==========

public record TigerBeetleConfiguration
{
    public required string[] ClusterAddresses { get; init; }
    public TimeSpan ConnectionTimeout { get; init; } = TimeSpan.FromSeconds(30);
    public int MaxRetries { get; init; } = 5;
    public int RetryBackoffMs { get; init; } = 1000;
    public TimeSpan HealthCheckInterval { get; init; } = TimeSpan.FromSeconds(30);
}

public record OfflineBufferConfiguration
{
    public int MaxBufferSize { get; init; } = 10000;
    public TimeSpan SyncInterval { get; init; } = TimeSpan.FromSeconds(60);
    public required string BufferDatabasePath { get; init; }
    public int RetryAttempts { get; init; } = 3;
    public TimeSpan RetryBackoff { get; init; } = TimeSpan.FromSeconds(300);
}

public record SiteConfiguration
{
    public required string SiteCode { get; init; }
    public required string SiteName { get; init; }
    public string? TimeZone { get; init; }
    public string? Region { get; init; }
}

// ========== Metadata Helpers ==========

public record LoadMetadataInfo
{
    public ulong SiteHash { get; init; }
    public ulong LoadHash { get; init; }
    public uint CarrierHash { get; init; }
    public uint ProductHash { get; init; }
    public decimal EstimatedRevenue { get; init; }
}

// ========== Health Check Models ==========

public record SystemHealthInfo
{
    public required string SiteCode { get; init; }
    public required bool TigerBeetleConnected { get; init; }
    public required int OfflineBufferPending { get; init; }
    public required int LoadsLast24Hours { get; init; }
    public required DateTime LastChecked { get; init; }
    public string? ErrorMessage { get; init; }
}