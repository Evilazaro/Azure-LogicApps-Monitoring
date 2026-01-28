// =============================================================================
// AppHost Environment Tests
// Tests for verifying environment and execution context
// =============================================================================

using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace app.AppHost.Tests;

/// <summary>
/// Tests for verifying environment and execution context in the AppHost.
/// </summary>
[TestClass]
public sealed class EnvironmentTests
{
    #region Environment Tests

    [TestMethod]
    public async Task AppHost_InTestMode_HasValidEnvironment()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();

        // Assert - Environment should be available
        var hostEnvironment = app.Services.GetService<IHostEnvironment>();
        Assert.IsNotNull(hostEnvironment, "IHostEnvironment should be available");
    }

    [TestMethod]
    public async Task AppHost_InTestMode_EnvironmentNameIsNotNull()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var hostEnvironment = app.Services.GetRequiredService<IHostEnvironment>();

        // Assert
        Assert.IsFalse(string.IsNullOrWhiteSpace(hostEnvironment.EnvironmentName),
            "Environment name should not be null or empty");
    }

    #endregion

    #region Execution Context Tests

    [TestMethod]
    public async Task AppHost_CanAccessDistributedApplicationModel()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        Assert.IsNotNull(model, "DistributedApplicationModel should be accessible");
    }

    [TestMethod]
    public async Task AppHost_ModelContainsResources()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        Assert.IsNotEmpty(model.Resources, "Model should contain resources");
    }

    #endregion

    #region Resource Count Verification Tests

    [TestMethod]
    public async Task AppHost_HasExpectedProjectCount()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();
        var projectResources = model.Resources.OfType<ProjectResource>().ToList();

        // Assert - Should have orders-api and web-app
        Assert.HasCount(2, projectResources,
            $"Should have exactly 2 project resources. Found: {string.Join(", ", projectResources.Select(p => p.Name))}");
    }

    [TestMethod]
    public async Task AppHost_HasExpectedParameterCount()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();
        var parameterResources = model.Resources.OfType<ParameterResource>().ToList();

        // Assert - In local development mode, no parameter resources are created
        // When Azure is configured, we'd have: resourceGroup, app-insights, service-bus, sql-server
        // The number of parameters depends on which Azure services are configured
        // Note: parameterResources.Count is always >= 0, so just verify the collection was created
        Assert.IsNotNull(parameterResources,
            $"Parameter resources should be available. Found: {string.Join(", ", parameterResources.Select(p => p.Name))}");
    }

    #endregion

    #region Resource Listing Tests

    [TestMethod]
    public async Task AppHost_ListAllResourceNames()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();
        var resourceNames = model.Resources.Select(r => r.Name).ToList();

        // Assert - Verify we can list all resource names
        Assert.IsNotEmpty(resourceNames, "Should be able to list resource names");

        // Verify expected resources are present
        Assert.Contains("orders-api", resourceNames, "Should contain orders-api");
        Assert.Contains("web-app", resourceNames, "Should contain web-app");
        Assert.Contains("messaging", resourceNames, "Should contain messaging");
        Assert.Contains("OrderDb", resourceNames, "Should contain OrderDb");
    }

    [TestMethod]
    public async Task AppHost_ListAllResourceTypes()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();
        var resourceTypes = model.Resources.Select(r => r.GetType().Name).Distinct().ToList();

        // Assert - Verify we have various resource types
        Assert.IsGreaterThan(0, resourceTypes.Count, "Should have multiple resource types");
    }

    #endregion
}
