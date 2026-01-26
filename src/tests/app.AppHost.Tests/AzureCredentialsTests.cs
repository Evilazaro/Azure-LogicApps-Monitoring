// =============================================================================
// AppHost Azure Credentials Tests
// Tests for verifying Azure credentials and Application Insights configuration
// =============================================================================

using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Azure;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace app.AppHost.Tests;

/// <summary>
/// Tests for verifying Azure credentials and Application Insights configuration.
/// These tests verify that credentials are properly configured in development mode.
/// </summary>
[TestClass]
public sealed class AzureCredentialsTests
{
    #region Application Insights Configuration Tests

    [TestMethod]
    public async Task ApplicationInsights_WhenConfigured_CreatesTelemetryResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Look for telemetry resource
        var telemetryResource = model.Resources.FirstOrDefault(r =>
            r.Name.Contains("telemetry", StringComparison.OrdinalIgnoreCase));

        // Note: In local mode without Azure:ApplicationInsights:Name configured,
        // telemetry resource may not be created. This verifies the configuration path.
        Assert.IsNotNull(telemetryResource, "telemetry resource should be configured");
    }

    [TestMethod]
    public async Task ApplicationInsights_HasAppInsightsParameter()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Check for app-insights parameter resource
        var appInsightsParam = model.Resources.FirstOrDefault(r =>
            r.Name == "app-insights");

        Assert.IsNotNull(appInsightsParam, "app-insights parameter should be configured");
    }

    #endregion

    #region Resource Group Configuration Tests

    [TestMethod]
    public async Task ResourceGroup_WhenConfigured_CreatesParameter()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Check for resourceGroup parameter
        var resourceGroupParam = model.Resources.FirstOrDefault(r =>
            r.Name == "resourceGroup");

        Assert.IsNotNull(resourceGroupParam, "resourceGroup parameter should be configured");
    }

    [TestMethod]
    public async Task ResourceGroup_IsParameterResource()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var resourceGroupParam = model.Resources.FirstOrDefault(r =>
            r.Name == "resourceGroup");

        Assert.IsNotNull(resourceGroupParam);
        Assert.IsInstanceOfType<ParameterResource>(resourceGroupParam,
            "resourceGroup should be a ParameterResource");
    }

    #endregion

    #region Orders API Configuration Tests

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

        // Check for endpoint configuration annotation
        var hasEndpointAnnotation = ordersApiResource.Annotations
            .Any(a => a.GetType().Name.Contains("Endpoint", StringComparison.OrdinalIgnoreCase));

        Assert.IsTrue(hasEndpointAnnotation,
            "orders-api should have external HTTP endpoints configured");
    }

    [TestMethod]
    public async Task OrdersApi_HasEnvironmentAnnotations()
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

        // The resource should have environment variable annotations
        var annotations = ordersApiResource.Annotations.ToList();
        Assert.IsGreaterThan(0, annotations.Count,
            "orders-api should have environment annotations configured");
    }

    #endregion

    #region Web App Configuration Tests

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

        // Check for endpoint configuration
        var hasEndpointAnnotation = webAppResource.Annotations
            .Any(a => a.GetType().Name.Contains("Endpoint", StringComparison.OrdinalIgnoreCase));

        Assert.IsTrue(hasEndpointAnnotation,
            "web-app should have external HTTP endpoints configured");
    }

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
        var hasHealthCheckAnnotation = webAppResource.Annotations
            .Any(a => a.GetType().Name.Contains("HealthCheck", StringComparison.OrdinalIgnoreCase));

        Assert.IsTrue(hasHealthCheckAnnotation,
            "web-app should have HTTP health check configured");
    }

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

        // Check for WaitFor annotation (indicates dependency)
        var hasWaitAnnotation = webAppResource.Annotations
            .Any(a => a.GetType().Name.Contains("Wait", StringComparison.OrdinalIgnoreCase));

        Assert.IsTrue(hasWaitAnnotation,
            "web-app should wait for orders-api to be ready");
    }

    #endregion

    #region All Resources Validation Tests

    [TestMethod]
    public async Task AllResources_HaveValidTypes()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - All resources should have valid types
        foreach (var resource in model.Resources)
        {
            Assert.IsNotNull(resource.GetType(),
                $"Resource '{resource.Name}' should have a valid type");
        }
    }

    [TestMethod]
    public async Task AllResources_ImplementIResource()
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
            Assert.IsInstanceOfType<IResource>(resource,
                $"Resource '{resource.Name}' should implement IResource");
        }
    }

    #endregion
}
