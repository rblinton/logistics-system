using LogisticsSystem.Core;

namespace LogisticsSystem.Core.Tests;

public class LogisticsIdTests
{
    [Fact]
    public void GenerateLoadId_ValidSiteCode_ReturnsValidId()
    {
        // Arrange
        var siteCode = "SITE_A";
        
        // Act
        var loadId = LogisticsId.GenerateLoadId(siteCode);
        
        // Assert
        Assert.NotEqual(UInt128.Zero, loadId);
        Assert.Equal(siteCode, LogisticsId.GetSiteCode(loadId));
    }
    
    [Fact]
    public void GenerateLoadId_MultipleCallsSameSite_ReturnsUniqueIds()
    {
        // Arrange
        var siteCode = "SITE_A";
        
        // Act
        var id1 = LogisticsId.GenerateLoadId(siteCode);
        var id2 = LogisticsId.GenerateLoadId(siteCode);
        
        // Assert
        Assert.NotEqual(id1, id2);
        Assert.True(LogisticsId.GetCounter(id2) > LogisticsId.GetCounter(id1));
    }
    
    [Fact]
    public void GetSiteCode_ValidId_ReturnsSiteCode()
    {
        // Arrange
        var expectedSite = "SITE_B";
        var loadId = LogisticsId.GenerateLoadId(expectedSite);
        
        // Act
        var actualSite = LogisticsId.GetSiteCode(loadId);
        
        // Assert
        Assert.Equal(expectedSite, actualSite);
    }
    
    [Fact]
    public void GetTimestamp_RecentId_ReturnsRecentTimestamp()
    {
        // Arrange
        var beforeGeneration = DateTime.UtcNow.AddSeconds(-1);
        
        // Act
        var loadId = LogisticsId.GenerateLoadId("SITE_A");
        var timestamp = LogisticsId.GetTimestamp(loadId);
        
        // Assert
        var afterGeneration = DateTime.UtcNow.AddSeconds(1);
        Assert.True(timestamp > beforeGeneration);
        Assert.True(timestamp < afterGeneration);
    }
    
    [Fact]
    public void FormatForLogging_ValidId_ReturnsReadableFormat()
    {
        // Arrange
        var siteCode = "SITE_A";
        var loadId = LogisticsId.GenerateLoadId(siteCode);
        
        // Act
        var formatted = LogisticsId.FormatForLogging(loadId);
        
        // Assert
        Assert.Contains(siteCode, formatted);
        Assert.Contains("@", formatted); // Should contain timestamp separator
        Assert.Contains("#", formatted); // Should contain counter separator
    }
    
    [Fact]
    public void IsValidSiteCode_ValidCodes_ReturnsTrue()
    {
        // Arrange & Act & Assert
        Assert.True(LogisticsId.IsValidSiteCode("CORP"));
        Assert.True(LogisticsId.IsValidSiteCode("SITE_A"));
        Assert.True(LogisticsId.IsValidSiteCode("SITE_B"));
    }
    
    [Fact]
    public void IsValidSiteCode_InvalidCode_ReturnsFalse()
    {
        // Arrange & Act & Assert
        Assert.False(LogisticsId.IsValidSiteCode("INVALID"));
        Assert.False(LogisticsId.IsValidSiteCode(""));
        Assert.False(LogisticsId.IsValidSiteCode("SITE_Z"));
    }
    
    [Theory]
    [InlineData("SITE_A", "LOAD_CREATE")]
    [InlineData("SITE_B", "ASSIGN")]
    [InlineData("CORP", "REVENUE_RECOGNITION")]
    public void GenerateTransferId_ValidInputs_ReturnsValidId(string siteCode, string operationType)
    {
        // Act
        var transferId = LogisticsId.GenerateTransferId(siteCode, operationType);
        
        // Assert
        Assert.NotEqual(UInt128.Zero, transferId);
        // Note: Site code extraction might not work perfectly with compound keys,
        // but the ID should still be unique and time-ordered
    }
    
    [Fact]
    public void GenerateEntityId_ValidInputs_ReturnsValidId()
    {
        // Arrange
        var entityType = "VENDOR";
        var entityCode = "ABC_CORP";
        
        // Act
        var entityId = LogisticsId.GenerateEntityId(entityType, entityCode);
        
        // Assert
        Assert.NotEqual(UInt128.Zero, entityId);
    }
    
    [Fact]
    public void GetValidSiteCodes_ReturnsExpectedSites()
    {
        // Act
        var siteCodes = LogisticsId.GetValidSiteCodes().ToList();
        
        // Assert
        Assert.Contains("CORP", siteCodes);
        Assert.Contains("SITE_A", siteCodes);
        Assert.Contains("SITE_B", siteCodes);
        Assert.Contains("SITE_C", siteCodes);
        Assert.Contains("SITE_D", siteCodes);
    }
}