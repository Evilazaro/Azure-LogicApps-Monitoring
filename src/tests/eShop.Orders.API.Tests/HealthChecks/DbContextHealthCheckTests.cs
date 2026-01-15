// =============================================================================
// Unit Tests for DbContextHealthCheck
// Tests Entity Framework Core DbContext connectivity health check functionality
// =============================================================================

using eShop.Orders.API.Data;
using eShop.Orders.API.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace eShop.Orders.API.Tests.HealthChecks;

/// <summary>
/// Unit tests for <see cref="DbContextHealthCheck"/> class.
/// Verifies database connectivity health check behavior.
/// </summary>
[TestClass]
public sealed class DbContextHealthCheckTests
{
    private OrderDbContext _dbContext = null!;
    private ILogger<DbContextHealthCheck> _logger = null!;
    private DbContextHealthCheck _healthCheck = null!;
    private HealthCheckContext _healthCheckContext = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        // Create an in-memory database context for testing
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase(databaseName: $"TestDb_{Guid.NewGuid()}")
            .Options;

        _dbContext = new OrderDbContext(options);
        _logger = Substitute.For<ILogger<DbContextHealthCheck>>();

        _healthCheck = new DbContextHealthCheck(_dbContext, _logger);

        // Create a health check context with default registration
        var registration = new HealthCheckRegistration(
            name: "Database",
            instance: _healthCheck,
            failureStatus: HealthStatus.Unhealthy,
            tags: null);
        _healthCheckContext = new HealthCheckContext { Registration = registration };
    }

    [TestCleanup]
    public async Task TestCleanup()
    {
        await _dbContext.DisposeAsync();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_NullDbContext_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new DbContextHealthCheck(null!, _logger));

        Assert.AreEqual("dbContext", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new DbContextHealthCheck(_dbContext, null!));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_ValidParameters_CreatesInstance()
    {
        // Arrange & Act
        var healthCheck = new DbContextHealthCheck(_dbContext, _logger);

        // Assert
        Assert.IsNotNull(healthCheck);
        Assert.IsInstanceOfType<IHealthCheck>(healthCheck);
    }

    #endregion

    #region CheckHealthAsync Tests

    [TestMethod]
    public async Task CheckHealthAsync_DatabaseConnected_ReturnsHealthy()
    {
        // Arrange - In-memory database is always connectable

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.AreEqual("Database connection is healthy", result.Description);
        Assert.IsNull(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_DisposedContext_ReturnsUnhealthy()
    {
        // Arrange - Create and dispose a context to simulate connection failure
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase($"DisposedDb_{Guid.NewGuid()}")
            .Options;
        var disposedDbContext = new OrderDbContext(options);
        await disposedDbContext.DisposeAsync();

        var healthCheck = new DbContextHealthCheck(disposedDbContext, _logger);

        // Act
        var result = await healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.AreEqual("Database connection failed", result.Description);
        Assert.IsNotNull(result.Exception);
        Assert.IsInstanceOfType<ObjectDisposedException>(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_RespectsFailureStatusFromRegistration_Degraded()
    {
        // Arrange - Create context with Degraded failure status
        var degradedRegistration = new HealthCheckRegistration(
            name: "Database",
            instance: _healthCheck,
            failureStatus: HealthStatus.Degraded,
            tags: null);
        var degradedContext = new HealthCheckContext { Registration = degradedRegistration };

        // Create a disposed context to force an exception
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase($"DisposedDb_{Guid.NewGuid()}")
            .Options;
        var disposedDbContext = new OrderDbContext(options);
        await disposedDbContext.DisposeAsync();

        var healthCheckWithDisposedContext = new DbContextHealthCheck(disposedDbContext, _logger);

        // Act
        var result = await healthCheckWithDisposedContext.CheckHealthAsync(degradedContext, CancellationToken.None);

        // Assert - Should use the failure status from registration
        Assert.AreEqual(HealthStatus.Degraded, result.Status);
        Assert.AreEqual("Database connection failed", result.Description);
        Assert.IsNotNull(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_ExceptionOccurs_LogsError()
    {
        // Arrange - Create a disposed context to force an exception
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase($"DisposedDb_{Guid.NewGuid()}")
            .Options;
        var disposedDbContext = new OrderDbContext(options);
        await disposedDbContext.DisposeAsync();

        var healthCheck = new DbContextHealthCheck(disposedDbContext, _logger);

        // Act
        await healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - Verify logger was called with LogError
        _logger.Received(1).Log(
            LogLevel.Error,
            Arg.Any<EventId>(),
            Arg.Any<object>(),
            Arg.Any<Exception>(),
            Arg.Any<Func<object, Exception?, string>>());
    }

    [TestMethod]
    public async Task CheckHealthAsync_CancellationRequested_RespectsCancellation()
    {
        // Arrange
        using var cts = new CancellationTokenSource();

        // Act - With in-memory database, this completes quickly regardless of cancellation
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, cts.Token);

        // Assert - Should complete successfully with in-memory database
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
    }

    [TestMethod]
    public async Task CheckHealthAsync_MultipleCalls_AllSucceed()
    {
        // Arrange & Act
        var result1 = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);
        var result2 = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);
        var result3 = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - All calls should succeed
        Assert.AreEqual(HealthStatus.Healthy, result1.Status);
        Assert.AreEqual(HealthStatus.Healthy, result2.Status);
        Assert.AreEqual(HealthStatus.Healthy, result3.Status);
    }

    [TestMethod]
    public async Task CheckHealthAsync_HealthyResult_HasNoException()
    {
        // Arrange & Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.IsNull(result.Exception);
        Assert.IsNotNull(result.Description);
    }

    [TestMethod]
    public async Task CheckHealthAsync_UnhealthyResult_HasException()
    {
        // Arrange - Create a disposed context
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase($"DisposedDb_{Guid.NewGuid()}")
            .Options;
        var disposedDbContext = new OrderDbContext(options);
        await disposedDbContext.DisposeAsync();

        var healthCheck = new DbContextHealthCheck(disposedDbContext, _logger);

        // Act
        var result = await healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.IsNotNull(result.Exception);
        Assert.IsNotNull(result.Description);
    }

    #endregion
}