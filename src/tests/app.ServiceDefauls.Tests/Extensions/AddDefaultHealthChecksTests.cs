// =============================================================================
// Unit Tests for AddDefaultHealthChecks Extension Method
// Tests health check configuration including self-check endpoint
// =============================================================================

using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace app.ServiceDefaults.Tests.Extensions;

/// <summary>
/// Unit tests for the <see cref="Microsoft.Extensions.Hosting.Extensions.AddDefaultHealthChecks{TBuilder}"/> method.
/// </summary>
[TestClass]
public sealed class AddDefaultHealthChecksTests
{
    #region Null Parameter Tests

    [TestMethod]
    public void AddDefaultHealthChecks_WithNullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IHostApplicationBuilder builder = null!;

        // Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => builder.AddDefaultHealthChecks());

        Assert.AreEqual("builder", exception.ParamName);
    }

    #endregion

    #region Health Check Registration Tests

    [TestMethod]
    public void AddDefaultHealthChecks_WithValidBuilder_ReturnsBuilder()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        var result = builder.AddDefaultHealthChecks();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void AddDefaultHealthChecks_RegistersHealthCheckService()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        builder.AddDefaultHealthChecks();

        // Assert
        var serviceProvider = builder.Services.BuildServiceProvider();
        var healthCheckService = serviceProvider.GetService<HealthCheckService>();

        Assert.IsNotNull(healthCheckService, "HealthCheckService should be registered");
    }

    [TestMethod]
    public async Task AddDefaultHealthChecks_SelfCheckReturnsHealthy()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();
        builder.AddDefaultHealthChecks();

        var serviceProvider = builder.Services.BuildServiceProvider();
        var healthCheckService = serviceProvider.GetRequiredService<HealthCheckService>();

        // Act
        var report = await healthCheckService.CheckHealthAsync();

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, report.Status);
        Assert.IsTrue(report.Entries.ContainsKey("self"), "Should contain 'self' health check");
        Assert.AreEqual(HealthStatus.Healthy, report.Entries["self"].Status);
    }

    [TestMethod]
    public async Task AddDefaultHealthChecks_SelfCheckHasLiveTag()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();
        builder.AddDefaultHealthChecks();

        var serviceProvider = builder.Services.BuildServiceProvider();
        var healthCheckService = serviceProvider.GetRequiredService<HealthCheckService>();

        // Act
        var report = await healthCheckService.CheckHealthAsync(
            predicate: registration => registration.Tags.Contains("live"));

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, report.Status);
        Assert.IsTrue(report.Entries.ContainsKey("self"), "Self check should have 'live' tag");
    }

    [TestMethod]
    public async Task AddDefaultHealthChecks_SelfCheckReturnsCorrectDescription()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();
        builder.AddDefaultHealthChecks();

        var serviceProvider = builder.Services.BuildServiceProvider();
        var healthCheckService = serviceProvider.GetRequiredService<HealthCheckService>();

        // Act
        var report = await healthCheckService.CheckHealthAsync();

        // Assert
        var selfCheck = report.Entries["self"];
        Assert.AreEqual("Application is running", selfCheck.Description);
    }

    #endregion

    #region Method Chaining Tests

    [TestMethod]
    public void AddDefaultHealthChecks_SupportsMethodChaining()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act - Should support fluent API
        var result = builder
            .AddDefaultHealthChecks()
            .AddDefaultHealthChecks(); // Can be called multiple times

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void AddDefaultHealthChecks_CanBeCombinedWithAddServiceDefaults()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        var result = builder
            .AddServiceDefaults()
            .AddDefaultHealthChecks();

        // Assert
        Assert.IsNotNull(result);
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