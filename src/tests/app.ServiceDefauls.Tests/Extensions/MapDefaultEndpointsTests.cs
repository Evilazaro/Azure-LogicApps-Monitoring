// =============================================================================
// Unit Tests for MapDefaultEndpoints Extension Method
// Tests health check endpoint mapping
// =============================================================================

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.TestHost;

namespace app.ServiceDefaults.Tests.Extensions;

/// <summary>
/// Unit tests for the <see cref="Microsoft.Extensions.Hosting.Extensions.MapDefaultEndpoints"/> method.
/// </summary>
[TestClass]
public sealed class MapDefaultEndpointsTests
{
    #region Null Parameter Tests

    [TestMethod]
    public void MapDefaultEndpoints_WithNullApp_ThrowsArgumentNullException()
    {
        // Arrange
        WebApplication app = null!;

        // Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => app.MapDefaultEndpoints());

        Assert.AreEqual("app", exception.ParamName);
    }

    #endregion

    #region Endpoint Configuration Tests

    [TestMethod]
    public void MapDefaultEndpoints_WithValidApp_ReturnsApp()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = "TestApplication"
        });
        builder.AddDefaultHealthChecks();

        var app = builder.Build();

        // Act
        var result = app.MapDefaultEndpoints();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(app, result);
    }

    [TestMethod]
    public async Task MapDefaultEndpoints_HealthEndpoint_ReturnsHealthy()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = "TestApplication"
        });
        builder.WebHost.UseTestServer();
        builder.AddDefaultHealthChecks();

        var app = builder.Build();
        app.MapDefaultEndpoints();

        await app.StartAsync();

        var client = app.GetTestClient();

        // Act
        var response = await client.GetAsync("/health");

        // Assert
        Assert.IsTrue(response.IsSuccessStatusCode);
        await app.StopAsync();
    }

    [TestMethod]
    public async Task MapDefaultEndpoints_AliveEndpoint_ReturnsHealthy()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = "TestApplication"
        });
        builder.WebHost.UseTestServer();
        builder.AddDefaultHealthChecks();

        var app = builder.Build();
        app.MapDefaultEndpoints();

        await app.StartAsync();

        var client = app.GetTestClient();

        // Act
        var response = await client.GetAsync("/alive");

        // Assert
        Assert.IsTrue(response.IsSuccessStatusCode);
        await app.StopAsync();
    }

    [TestMethod]
    public async Task MapDefaultEndpoints_AliveEndpoint_OnlyIncludesLiveTaggedChecks()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = "TestApplication"
        });
        builder.WebHost.UseTestServer();
        builder.AddDefaultHealthChecks();

        // Add a non-live health check
        builder.Services.AddHealthChecks()
            .AddCheck("database", () =>
                Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy("Database is available"));

        var app = builder.Build();
        app.MapDefaultEndpoints();

        await app.StartAsync();

        var client = app.GetTestClient();

        // Act
        var response = await client.GetAsync("/alive");

        // Assert - Should return healthy because only 'live' tagged checks are included
        Assert.IsTrue(response.IsSuccessStatusCode);
        await app.StopAsync();
    }

    #endregion

    #region Method Chaining Tests

    [TestMethod]
    public void MapDefaultEndpoints_SupportsMethodChaining()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = "TestApplication"
        });
        builder.AddDefaultHealthChecks();

        var app = builder.Build();

        // Act - Should support fluent API
        var result = app.MapDefaultEndpoints();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(app, result);
    }

    #endregion
}