using System.Collections.Concurrent;

namespace LogisticsSystem.Core;

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
    
    /// <summary>
    /// Check if site code is valid
    /// </summary>
    public static bool IsValidSiteCode(string siteCode)
    {
        return SiteCodes.ContainsKey(siteCode);
    }
    
    /// <summary>
    /// Get all valid site codes
    /// </summary>
    public static IEnumerable<string> GetValidSiteCodes()
    {
        return SiteCodes.Keys;
    }
    
    private static ulong GetNextCounter(string siteCode)
    {
        return (ulong)_counters.AddOrUpdate(siteCode, 1, (_, current) => current + 1);
    }
}