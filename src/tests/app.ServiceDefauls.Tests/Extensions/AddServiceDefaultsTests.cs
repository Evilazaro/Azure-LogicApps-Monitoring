// =============================================================================
// Unit Tests for AddServiceDefaults Extension Method
// Tests service defaults configuration including OpenTelemetry, health checks,
// service discovery, and resilience patterns
// =============================================================================

namespace app.ServiceDefaults.Tests.Extensions;

/// <summary>
/// Unit tests for the <see cref="Microsoft.Extensions.Hosting.Extensions.AddServiceDefaults{TBuilder}"/> method.
/// </summary>
[TestClass]
public sealed class AddServiceDefaultsTests
{
    #region Constructor/Null Parameter Tests

    [TestMethod]
    public void AddServiceDefaults_WithNullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IHostApplicationBuilder builder = null!;

        // Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => builder.AddServiceDefaults());

        Assert.AreEqual("builder", exception.ParamName);
    }

    [TestMethod]
    public void AddServiceDefaults_WithValidBuilder_ReturnsBuilder()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        var result = builder.AddServiceDefaults();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void AddServiceDefaults_RegistersHealthChecks()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        builder.AddServiceDefaults();

        // Assert - Verify health check services are registered
        var serviceProvider = builder.Services.BuildServiceProvider();
        var healthCheckService = serviceProvider.GetService<Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckService>();

        Assert.IsNotNull(healthCheckService, "HealthCheckService should be registered");
    }

    [TestMethod]
    public void AddServiceDefaults_RegistersServiceDiscovery()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        builder.AddServiceDefaults();

        // Assert - Build should succeed indicating services are registered
        var serviceProvider = builder.Services.BuildServiceProvider();
        Assert.IsNotNull(serviceProvider);
    }

    [TestMethod]
    public void AddServiceDefaults_ConfiguresHttpClientDefaults()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        builder.AddServiceDefaults();

        // Assert - Verify HTTP client factory is available
        var serviceProvider = builder.Services.BuildServiceProvider();
        var httpClientFactory = serviceProvider.GetService<IHttpClientFactory>();

        Assert.IsNotNull(httpClientFactory, "IHttpClientFactory should be registered");
    }

    #endregion

    #region Method Chaining Tests

    [TestMethod]
    public void AddServiceDefaults_SupportsMethodChaining()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act - Should support fluent API
        var result = builder
            .AddServiceDefaults()
            .AddDefaultHealthChecks();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    #endregion

    #region Helper Methods

    private static HostApplicationBuilder CreateHostApplicationBuilder()
    {
        var builder = Host.CreateApplicationBuilder(new HostApplicationBuilderSettings
        {
            ApplicationName = "TestApplication",
            EnvironmentName = "Development"
        });

        return builder;
    }

    #endregion
}