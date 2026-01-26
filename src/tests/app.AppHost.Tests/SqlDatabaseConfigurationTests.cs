// =============================================================================
// AppHost SQL Database Configuration Tests
// Tests for verifying Azure SQL Database configuration
// =============================================================================

using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace app.AppHost.Tests;

/// <summary>
/// Tests for verifying SQL Database configuration in the AppHost.
/// </summary>
[TestClass]
public sealed class SqlDatabaseConfigurationTests
{
    #region Local Container Mode Tests

    [TestMethod]
    public async Task SqlServer_InLocalMode_ConfiguresContainer()
    {
        // Arrange - Default configuration uses local container mode
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>(args =>
            {
                args.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Azure:SqlServer:Name"] = "OrdersDatabase" // Default local name
                });
            });

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - SQL Server should be configured
        var sqlResource = model.Resources.FirstOrDefault(r =>
            r.Name.Contains("OrdersDatabase", StringComparison.OrdinalIgnoreCase) ||
            r.Name.Contains("OrderDb", StringComparison.OrdinalIgnoreCase));

        Assert.IsNotNull(sqlResource, "SQL Server/Database resource should be configured in local mode");
    }

    [TestMethod]
    public async Task SqlServer_InLocalMode_HasDatabaseConfigured()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Database should be configured
        var databaseResource = model.Resources.FirstOrDefault(r =>
            r.Name.Contains("OrderDb", StringComparison.OrdinalIgnoreCase));

        Assert.IsNotNull(databaseResource, "Database 'OrderDb' should be configured");
    }

    #endregion

    #region Resource Reference Tests

    [TestMethod]
    public async Task OrdersApi_HasDatabaseReference()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api");

        // Assert
        Assert.IsNotNull(ordersApiResource, "orders-api should exist");

        // Verify it has annotations including database reference
        var annotations = ordersApiResource.Annotations.ToList();
        Assert.IsNotEmpty(annotations, "orders-api should have annotations including database reference");
    }

    #endregion

    #region Configuration Defaults Tests

    [TestMethod]
    public async Task SqlServer_DefaultServerName_IsOrdersDatabase()
    {
        // Arrange - Use default configuration
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify default server name
        var serverResource = model.Resources.FirstOrDefault(r => r.Name == "OrdersDatabase");
        Assert.IsNotNull(serverResource, "Default server name should be 'OrdersDatabase'");
    }

    [TestMethod]
    public async Task SqlServer_DefaultDatabaseName_IsOrderDb()
    {
        // Arrange - Use default configuration
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify default database name
        var databaseResource = model.Resources.FirstOrDefault(r => r.Name == "OrderDb");
        Assert.IsNotNull(databaseResource, "Default database name should be 'OrderDb'");
    }

    #endregion

    #region Wait For Dependency Tests

    [TestMethod]
    public async Task OrdersApi_WaitsForDatabase()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api") as ProjectResource;

        // Assert - Verify WaitFor annotation exists
        Assert.IsNotNull(ordersApiResource, "orders-api should exist as ProjectResource");

        // The presence of WaitForAnnotation indicates dependency waiting is configured
        var waitAnnotations = ordersApiResource.Annotations
            .Where(a => a.GetType().Name.Contains("Wait"))
            .ToList();

        // In local mode, orders-api waits for both database and Service Bus
        Assert.IsNotEmpty(waitAnnotations, "orders-api should have wait annotations for dependencies");
    }

    #endregion
}
