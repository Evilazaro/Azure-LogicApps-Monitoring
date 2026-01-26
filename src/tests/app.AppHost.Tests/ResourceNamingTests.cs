// =============================================================================
// AppHost Resource Naming Tests
// Tests for verifying resource naming conventions and consistency
// =============================================================================

using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace app.AppHost.Tests;

/// <summary>
/// Tests for verifying resource naming conventions in the AppHost.
/// </summary>
[TestClass]
public sealed class ResourceNamingTests
{
    #region Project Resource Naming Tests

    [TestMethod]
    public async Task OrdersApi_HasCorrectResourceName()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api");
        Assert.IsNotNull(ordersApiResource, "Resource should be named 'orders-api'");
    }

    [TestMethod]
    public async Task WebApp_HasCorrectResourceName()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var webAppResource = model.Resources.FirstOrDefault(r => r.Name == "web-app");
        Assert.IsNotNull(webAppResource, "Resource should be named 'web-app'");
    }

    #endregion

    #region Infrastructure Resource Naming Tests

    [TestMethod]
    public async Task ServiceBus_HasCorrectResourceName()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var messagingResource = model.Resources.FirstOrDefault(r => r.Name == "messaging");
        Assert.IsNotNull(messagingResource, "Service Bus resource should be named 'messaging'");
    }

    [TestMethod]
    public async Task SqlServer_HasDatabaseResourceConfigured()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - In local mode, database is named OrderDb
        var databaseResource = model.Resources.FirstOrDefault(r =>
            r.Name.Contains("OrderDb", StringComparison.OrdinalIgnoreCase) ||
            r.Name.Contains("Database", StringComparison.OrdinalIgnoreCase));

        Assert.IsNotNull(databaseResource, "SQL Database resource should be configured");
    }

    #endregion

    #region Resource Name Convention Tests

    [TestMethod]
    public async Task AllResourceNames_AreLowerCaseWithDashes()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Get project resources (which should follow kebab-case naming)
        var projectResources = model.Resources.OfType<ProjectResource>().ToList();

        // Assert
        foreach (var resource in projectResources)
        {
            Assert.DoesNotContain(' ', resource.Name,
                $"Resource name '{resource.Name}' should not contain spaces");
            Assert.AreEqual(resource.Name.ToLowerInvariant(), resource.Name,
                $"Project resource name '{resource.Name}' should be lowercase");
        }
    }

    [TestMethod]
    public async Task ResourceNames_AreUnique()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var resourceNames = model.Resources.Select(r => r.Name).ToList();
        var uniqueNames = resourceNames.Distinct().ToList();

        // Assert
        Assert.HasCount(resourceNames.Count, uniqueNames,
            $"All resource names should be unique. Found duplicates: {string.Join(", ", resourceNames.GroupBy(n => n).Where(g => g.Count() > 1).Select(g => g.Key))}");
    }

    #endregion
}
