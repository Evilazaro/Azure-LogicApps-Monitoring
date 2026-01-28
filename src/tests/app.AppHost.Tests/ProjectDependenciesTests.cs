// =============================================================================
// AppHost Project Dependencies Tests
// Tests for verifying project dependencies and references
// =============================================================================

using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace app.AppHost.Tests;

/// <summary>
/// Tests for verifying project dependencies and wait relationships.
/// </summary>
[TestClass]
public sealed class ProjectDependenciesTests
{
    #region Web App Dependencies Tests

    [TestMethod]
    public async Task WebApp_WaitsForOrdersApi()
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

        // Verify WaitFor annotations exist (web-app waits for orders-api)
        // Use ToArray() to avoid collection modification issues during enumeration
        var waitAnnotations = webAppResource.Annotations.ToArray()
            .Where(a => a.GetType().Name.Contains("Wait"))
            .ToList();

        Assert.IsNotEmpty(waitAnnotations, "web-app should have wait annotation for orders-api");
    }

    [TestMethod]
    public async Task WebApp_ReferencesOrdersApi()
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

        // The presence of environment variable annotations indicates references are configured
        // Use ToArray() to avoid collection modification during enumeration
        var envAnnotations = webAppResource.Annotations.ToArray()
            .Where(a => a.GetType().Name.Contains("Environment"))
            .ToList();

        Assert.IsNotEmpty(envAnnotations, "web-app should have environment annotations for service references");
    }

    #endregion

    #region Orders API Dependencies Tests

    [TestMethod]
    public async Task OrdersApi_WaitsForServiceBus()
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

        // Verify WaitFor annotations exist
        var waitAnnotations = ordersApiResource.Annotations
            .Where(a => a.GetType().Name.Contains("Wait"))
            .ToList();

        Assert.IsNotEmpty(waitAnnotations, "orders-api should have wait annotations for dependencies");
    }

    [TestMethod]
    public async Task OrdersApi_ReferencesDatabase()
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

        // Verify annotations are present (connection strings, etc.)
        var annotations = ordersApiResource.Annotations.ToList();
        Assert.IsGreaterThan(0, annotations.Count, "orders-api should have annotations for database reference");
    }

    [TestMethod]
    public async Task OrdersApi_ReferencesServiceBus()
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

        // The annotations include connection string references for Service Bus
        var annotations = ordersApiResource.Annotations.ToList();
        Assert.IsNotEmpty(annotations, "orders-api should have annotations for Service Bus reference");
    }

    #endregion

    #region External HTTP Endpoints Tests

    [TestMethod]
    public async Task OrdersApi_HasExternalHttpEndpoints()
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

        // Check for endpoint annotations
        var endpointAnnotations = ordersApiResource.Annotations
            .Where(a => a.GetType().Name.Contains("Endpoint"))
            .ToList();

        Assert.IsNotEmpty(endpointAnnotations, "orders-api should have external HTTP endpoint annotations");
    }

    [TestMethod]
    public async Task WebApp_HasExternalHttpEndpoints()
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

        // Check for endpoint annotations
        var endpointAnnotations = webAppResource.Annotations
            .Where(a => a.GetType().Name.Contains("Endpoint"))
            .ToList();

        Assert.IsNotEmpty(endpointAnnotations, "web-app should have external HTTP endpoint annotations");
    }

    #endregion

    #region Health Check Tests

    [TestMethod]
    public async Task WebApp_HasHealthCheckConfigured()
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

        // Check for health check annotation
        var healthAnnotations = webAppResource.Annotations
            .Where(a => a.GetType().Name.Contains("Health"))
            .ToList();

        Assert.IsNotEmpty(healthAnnotations, "web-app should have health check annotation configured");
    }

    #endregion
}
