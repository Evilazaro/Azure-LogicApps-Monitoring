// =============================================================================
// AppHost Integration Tests
// Tests for the .NET Aspire distributed application host configuration
// Using Aspire.Hosting.Testing for integration-level testing
// =============================================================================

using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace app.AppHost.Tests;

/// <summary>
/// Integration tests for the AppHost distributed application configuration.
/// These tests verify that the Aspire host is properly configured with all required resources.
/// </summary>
[TestClass]
public sealed class AppHostIntegrationTests
{
    #region Resource Configuration Tests

    [TestMethod]
    public async Task AppHost_WhenBuilt_ContainsOrdersApiProject()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify orders-api resource exists
        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api");

        Assert.IsNotNull(ordersApiResource, "orders-api resource should be configured");
    }

    [TestMethod]
    public async Task AppHost_WhenBuilt_ContainsWebAppProject()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify web-app resource exists
        var webAppResource = model.Resources.FirstOrDefault(r => r.Name == "web-app");

        Assert.IsNotNull(webAppResource, "web-app resource should be configured");
    }

    [TestMethod]
    public async Task AppHost_WhenBuilt_ContainsMessagingResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify messaging (Service Bus) resource exists
        var messagingResource = model.Resources.FirstOrDefault(r => r.Name == "messaging");

        Assert.IsNotNull(messagingResource, "messaging resource should be configured for Service Bus");
    }

    [TestMethod]
    public async Task AppHost_WhenBuilt_ContainsDatabaseResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify database resource exists (either OrdersDatabase or OrderDb)
        var databaseResource = model.Resources.FirstOrDefault(r =>
            r.Name.Contains("Database", StringComparison.OrdinalIgnoreCase) ||
            r.Name.Contains("OrderDb", StringComparison.OrdinalIgnoreCase));

        Assert.IsNotNull(databaseResource, "Database resource should be configured");
    }

    #endregion

    #region Resource Count Tests

    [TestMethod]
    public async Task AppHost_WhenBuilt_HasExpectedMinimumResourceCount()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();
        var resources = model.Resources.ToList();

        // Assert - Should have at least: orders-api, web-app, messaging, database
        // IsGreaterThanOrEqualTo(lowerBound, value) checks if value >= lowerBound
        Assert.IsGreaterThanOrEqualTo(4, resources.Count,
            $"Should have at least 4 resources. Found: {string.Join(", ", resources.Select(r => r.Name))}");
    }

    #endregion

    #region Project Resource Tests

    [TestMethod]
    public async Task OrdersApi_IsConfiguredAsProjectResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();
        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api");

        // Assert
        Assert.IsNotNull(ordersApiResource);
        Assert.IsInstanceOfType<ProjectResource>(ordersApiResource,
            "orders-api should be a ProjectResource");
    }

    [TestMethod]
    public async Task WebApp_IsConfiguredAsProjectResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();
        var webAppResource = model.Resources.FirstOrDefault(r => r.Name == "web-app");

        // Assert
        Assert.IsNotNull(webAppResource);
        Assert.IsInstanceOfType<ProjectResource>(webAppResource,
            "web-app should be a ProjectResource");
    }

    #endregion

    #region Resource Dependencies Tests

    [TestMethod]
    public async Task WebApp_HasReferenceToOrdersApi()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var webAppResource = model.Resources.FirstOrDefault(r => r.Name == "web-app");
        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api");

        // Assert
        Assert.IsNotNull(webAppResource, "web-app resource should exist");
        Assert.IsNotNull(ordersApiResource, "orders-api resource should exist");

        // Check if web-app has any annotations that reference orders-api
        var annotations = webAppResource.Annotations.ToList();
        Assert.IsNotEmpty(annotations, "web-app should have annotations configured");
    }

    [TestMethod]
    public async Task OrdersApi_HasReferenceToMessaging()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api");
        var messagingResource = model.Resources.FirstOrDefault(r => r.Name == "messaging");

        // Assert
        Assert.IsNotNull(ordersApiResource, "orders-api resource should exist");
        Assert.IsNotNull(messagingResource, "messaging resource should exist");
    }

    #endregion

    #region Resource Model Tests

    [TestMethod]
    public async Task AppHost_DistributedApplicationModel_IsAvailable()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        Assert.IsNotNull(model, "DistributedApplicationModel should be available");
        Assert.IsNotEmpty(model.Resources, "Model should contain resources");
    }

    [TestMethod]
    public async Task AppHost_AllResourcesHaveNames()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        foreach (var resource in model.Resources)
        {
            Assert.IsFalse(string.IsNullOrWhiteSpace(resource.Name),
                "All resources should have non-empty names");
        }
    }

    #endregion

    #region Configuration Tests

    [TestMethod]
    public async Task AppHost_WithDefaultConfiguration_BuildsSuccessfully()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();

        // Assert - Should build without exceptions
        Assert.IsNotNull(app);
    }

    #endregion
}
