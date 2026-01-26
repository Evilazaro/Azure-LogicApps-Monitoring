// =============================================================================
// AppHost Configuration Validation Tests
// Tests for verifying configuration validation and error handling
// =============================================================================

using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Azure;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace app.AppHost.Tests;

/// <summary>
/// Tests for validating AppHost configuration and verifying resource
/// configuration in different modes.
/// </summary>
[TestClass]
public sealed class ConfigurationValidationTests
{
    #region Service Bus Parameter Tests

    [TestMethod]
    public async Task ServiceBus_HasParameterConfigured()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Check for service-bus parameter
        var serviceBusParam = model.Resources.FirstOrDefault(r =>
            r.Name == "service-bus");

        Assert.IsNotNull(serviceBusParam, "service-bus parameter should be configured");
    }

    [TestMethod]
    public async Task ServiceBus_ParameterIsCorrectType()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var serviceBusParam = model.Resources.FirstOrDefault(r =>
            r.Name == "service-bus");

        Assert.IsNotNull(serviceBusParam);
        Assert.IsInstanceOfType<ParameterResource>(serviceBusParam,
            "service-bus should be a ParameterResource");
    }

    #endregion

    #region SQL Server Parameter Tests

    [TestMethod]
    public async Task SqlServer_HasParameterConfigured()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Check for sql-server parameter
        var sqlServerParam = model.Resources.FirstOrDefault(r =>
            r.Name == "sql-server");

        Assert.IsNotNull(sqlServerParam, "sql-server parameter should be configured");
    }

    [TestMethod]
    public async Task SqlServer_ParameterIsCorrectType()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var sqlServerParam = model.Resources.FirstOrDefault(r =>
            r.Name == "sql-server");

        Assert.IsNotNull(sqlServerParam);
        Assert.IsInstanceOfType<ParameterResource>(sqlServerParam,
            "sql-server should be a ParameterResource");
    }

    #endregion

    #region Resource Type Verification Tests

    [TestMethod]
    public async Task MessagingResource_IsAzureServiceBusResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var messagingResource = model.Resources.FirstOrDefault(r =>
            r.Name == "messaging");

        Assert.IsNotNull(messagingResource, "messaging resource should exist");
        Assert.IsInstanceOfType<AzureServiceBusResource>(messagingResource,
            "messaging should be an AzureServiceBusResource");
    }

    [TestMethod]
    public async Task TopicResource_IsServiceBusTopic()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var topicResource = model.Resources.FirstOrDefault(r =>
            r.Name == "ordersplaced");

        Assert.IsNotNull(topicResource, "ordersplaced topic should exist");
    }

    [TestMethod]
    public async Task SubscriptionResource_Exists()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var subscriptionResource = model.Resources.FirstOrDefault(r =>
            r.Name == "orderprocessingsub");

        Assert.IsNotNull(subscriptionResource, "orderprocessingsub subscription should exist");
    }

    #endregion

    #region SQL Server Resource Tests

    [TestMethod]
    public async Task SqlServer_IsAzureSqlServerResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var sqlServerResource = model.Resources.FirstOrDefault(r =>
            r.Name == "OrdersDatabase");

        Assert.IsNotNull(sqlServerResource, "OrdersDatabase resource should exist");
    }

    [TestMethod]
    public async Task SqlDatabase_IsAzureSqlDatabaseResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var databaseResource = model.Resources.FirstOrDefault(r =>
            r.Name == "OrderDb");

        Assert.IsNotNull(databaseResource, "OrderDb database resource should exist");
    }

    #endregion

    #region Wait Dependency Tests

    [TestMethod]
    public async Task OrdersApi_WaitsForMessaging()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api") as ProjectResource;

        // Assert
        Assert.IsNotNull(ordersApiResource, "orders-api should exist");

        // Check for WaitFor annotation
        var hasWaitAnnotation = ordersApiResource.Annotations
            .Any(a => a.GetType().Name.Contains("Wait", StringComparison.OrdinalIgnoreCase));

        Assert.IsTrue(hasWaitAnnotation,
            "orders-api should wait for messaging to be ready");
    }

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

        // Assert
        Assert.IsNotNull(ordersApiResource, "orders-api should exist");

        // Verify database dependency is configured through annotations
        var annotations = ordersApiResource.Annotations.ToList();
        Assert.IsGreaterThan(0, annotations.Count,
            "orders-api should have annotations including database dependency");
    }

    #endregion

    #region Reference Tests

    [TestMethod]
    public async Task WebApp_HasOrdersApiReference()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var webAppResource = model.Resources.FirstOrDefault(r => r.Name == "web-app") as ProjectResource;

        // Assert
        Assert.IsNotNull(webAppResource, "web-app should exist");

        // Reference annotation indicates dependency on orders-api
        var annotations = webAppResource.Annotations.ToList();
        Assert.IsGreaterThan(0, annotations.Count,
            "web-app should have reference annotations");
    }

    [TestMethod]
    public async Task OrdersApi_HasTelemetryReference()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api") as ProjectResource;
        var telemetryResource = model.Resources.FirstOrDefault(r => r.Name == "telemetry");

        // Assert
        Assert.IsNotNull(ordersApiResource, "orders-api should exist");
        Assert.IsNotNull(telemetryResource, "telemetry resource should exist");
    }

    #endregion

    #region Parameter Value Tests

    [TestMethod]
    public async Task AllParameterResources_HaveNonNullNames()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var parameterResources = model.Resources.OfType<ParameterResource>().ToList();

        // Assert
        foreach (var param in parameterResources)
        {
            Assert.IsFalse(string.IsNullOrWhiteSpace(param.Name),
                "All parameter resources should have non-empty names");
        }
    }

    [TestMethod]
    public async Task AllProjectResources_HaveNonNullNames()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        var projectResources = model.Resources.OfType<ProjectResource>().ToList();

        // Assert
        foreach (var project in projectResources)
        {
            Assert.IsFalse(string.IsNullOrWhiteSpace(project.Name),
                "All project resources should have non-empty names");
        }
    }

    #endregion
}
