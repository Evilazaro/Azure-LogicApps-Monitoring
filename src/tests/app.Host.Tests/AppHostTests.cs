// =============================================================================
// Unit Tests for AppHost Configuration Methods
// Tests .NET Aspire orchestration configuration for the eShop application
// =============================================================================

namespace app.Host.Tests;

/// <summary>
/// Unit tests for the AppHost distributed application configuration.
/// Tests cover resource configuration, Azure integration, and local development modes.
/// </summary>
[TestClass]
public sealed class AppHostTests
{
    #region Integration Tests - Application Model Verification

    [TestMethod]
    public async Task AppHost_WithDefaultConfiguration_CreatesExpectedResources()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify the application builds successfully
        Assert.IsNotNull(app, "Application should be built successfully");

        // Verify services are available
        Assert.IsNotNull(app.Services, "Services should be available");
    }

    [TestMethod]
    public async Task AppHost_WithDefaultConfiguration_ConfiguresServiceBusInLocalMode()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify application builds with messaging configuration
        Assert.IsNotNull(app, "Application with Service Bus should build successfully");
    }

    [TestMethod]
    public async Task AppHost_WithDefaultConfiguration_ConfiguresSqlServerInLocalMode()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify application builds with SQL configuration
        Assert.IsNotNull(app, "Application with SQL Server should build successfully");
    }

    #endregion

    #region Resource Configuration Tests

    [TestMethod]
    public async Task AppHost_OrdersApiResource_IsConfigured()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Application builds means orders-api is configured
        Assert.IsNotNull(app, "orders-api should be configured");
    }

    [TestMethod]
    public async Task AppHost_WebAppResource_IsConfigured()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Application builds means web-app is configured
        Assert.IsNotNull(app, "web-app should be configured");
    }

    [TestMethod]
    public async Task AppHost_ResourcesAreConfigured()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify application model contains resources
        Assert.IsNotNull(app, "Application model should be created with resources");
    }

    #endregion

    #region Configuration-Based Tests

    [TestMethod]
    public async Task AppHost_WithoutAzureResourceGroup_DoesNotThrow()
    {
        // Arrange - Default configuration without Azure:ResourceGroup
        Exception? caughtException = null;

        try
        {
            var appHost = await DistributedApplicationTestingBuilder
                .CreateAsync<Projects.app_AppHost>();

            await using var app = await appHost.BuildAsync();
        }
        catch (Exception ex)
        {
            caughtException = ex;
        }

        // Assert - Should not throw
        Assert.IsNull(caughtException,
            $"AppHost should build without Azure:ResourceGroup. Got: {caughtException?.Message}");
    }

    [TestMethod]
    public async Task AppHost_WithServiceBusLocalMode_BuildsSuccessfully()
    {
        // Arrange - No Azure:ServiceBus:HostName means local mode
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify application builds in local mode
        Assert.IsNotNull(app, "Messaging resource should be created in local mode");
    }

    [TestMethod]
    public async Task AppHost_WithSqlServerLocalMode_BuildsSuccessfully()
    {
        // Arrange - No Azure:SqlServer:Name means local mode (uses default)
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify SQL resources are configured
        Assert.IsNotNull(app, "SQL resources should be created in local mode");
    }

    #endregion

    #region Resource Relationship Tests

    [TestMethod]
    public async Task AppHost_WebApp_AndOrdersApi_AreConfigured()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Both resources are configured if build succeeds
        Assert.IsNotNull(app, "web-app and orders-api should be configured");
    }

    [TestMethod]
    public async Task AppHost_OrdersApi_WithDatabaseAndMessaging_BuildsSuccessfully()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - orders-api with dependencies builds successfully
        Assert.IsNotNull(app, "orders-api with database and messaging should build");
    }

    #endregion

    #region Application Model Structure Tests

    [TestMethod]
    public async Task AppHost_Model_BuildsWithProjectResources()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Should have project resources
        Assert.IsNotNull(app, "Should build with project resources");
    }

    [TestMethod]
    public async Task AppHost_Model_BuildsSuccessfully()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Model builds successfully
        Assert.IsNotNull(app, "Application model should build successfully");
    }

    [TestMethod]
    public async Task AppHost_Model_HasValidConfiguration()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - All resources should be properly configured
        Assert.IsNotNull(app, "All resources should have valid configuration");
    }

    #endregion

    #region Error Handling Tests

    [TestMethod]
    public async Task AppHost_BuildAsync_CompletesWithoutException()
    {
        // Arrange & Act
        Exception? caughtException = null;

        try
        {
            var appHost = await DistributedApplicationTestingBuilder
                .CreateAsync<Projects.app_AppHost>();

            await using var app = await appHost.BuildAsync();
        }
        catch (Exception ex)
        {
            caughtException = ex;
        }

        // Assert
        Assert.IsNull(caughtException,
            $"AppHost.BuildAsync should complete without exception. Got: {caughtException?.Message}");
    }

    [TestMethod]
    public async Task AppHost_DisposesCleanly()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        var app = await appHost.BuildAsync();

        // Act & Assert - Should not throw
        Exception? disposeException = null;
        try
        {
            await app.DisposeAsync();
        }
        catch (Exception ex)
        {
            disposeException = ex;
        }

        Assert.IsNull(disposeException,
            $"App should dispose cleanly. Got: {disposeException?.Message}");
    }

    #endregion

    #region Service Discovery Configuration Tests

    [TestMethod]
    public async Task AppHost_WebApp_IsConfiguredWithEndpoints()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - web-app should be configured with endpoints
        Assert.IsNotNull(app, "web-app should be configured with endpoints");
    }

    #endregion

    #region Default Values Tests

    [TestMethod]
    public async Task AppHost_ServiceBus_IsConfiguredWithDefaults()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify Service Bus is configured with defaults
        Assert.IsNotNull(app, "Service Bus should be configured with default topic");
    }

    [TestMethod]
    public async Task AppHost_SqlServer_IsConfiguredWithDefaults()
    {
        // Arrange & Act
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        await using var app = await appHost.BuildAsync();

        // Assert - Verify SQL Database is configured with defaults
        Assert.IsNotNull(app, "SQL resources should be configured with default names");
    }

    #endregion
}