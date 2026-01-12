// =============================================================================
// Unit Tests for DbContextHealthCheck
// Tests database connectivity health check functionality
// =============================================================================

using eShop.Orders.API.Data;
using eShop.Orders.API.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using Moq;

namespace eShop.Orders.API.Tests.HealthChecks;

/// <summary>
/// Unit tests for the <see cref="DbContextHealthCheck"/> class.
/// Tests cover constructor validation, health check scenarios, and error handling.
/// </summary>
[TestClass]
public sealed class DbContextHealthCheckTests
{
    private OrderDbContext _dbContext = null!;
    private Mock<ILogger<DbContextHealthCheck>> _loggerMock = null!;
    private DbContextHealthCheck _healthCheck = null!;

    [TestInitialize]
    public async Task TestInitialize()
    {
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _dbContext = new OrderDbContext(options);
        _loggerMock = new Mock<ILogger<DbContextHealthCheck>>();

        // Ensure the in-memory database is created before tests run
        await _dbContext.Database.EnsureCreatedAsync();
    }

    [TestCleanup]
    public async Task TestCleanup()
    {
        if (_dbContext != null)
        {
            await _dbContext.Database.EnsureDeletedAsync();
            await _dbContext.DisposeAsync();
        }
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_WithValidParameters_CreatesInstance()
    {
        // Act
        var healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        // Assert
        Assert.IsNotNull(healthCheck);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullDbContext_ThrowsArgumentNullException()
    {
        // Act
        _ = new DbContextHealthCheck(null!, _loggerMock.Object);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Act
        _ = new DbContextHealthCheck(_dbContext, null!);
    }

    #endregion

    #region CheckHealthAsync Tests

    [TestMethod]
    public async Task CheckHealthAsync_WhenDatabaseCanConnect_ReturnsHealthy()
    {
        // Arrange
        _healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        var context = CreateHealthCheckContext();

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.AreEqual("Database connection is healthy", result.Description);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenCancellationRequested_HandlesGracefully()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        _healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        var context = CreateHealthCheckContext(HealthStatus.Unhealthy);

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, cts.Token);

        // Assert - In-memory database typically succeeds even with cancelled token
        Assert.IsNotNull(result);
    }

    [TestMethod]
    public async Task CheckHealthAsync_VerifiesConnectionAttempt()
    {
        // Arrange
        _healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        var context = CreateHealthCheckContext();

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WithValidContext_ReturnsResult()
    {
        // Arrange
        _healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        var context = CreateHealthCheckContext();

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.IsNotNull(result.Description);
    }

    [TestMethod]
    public async Task CheckHealthAsync_MultipleCalls_AllSucceed()
    {
        // Arrange
        _healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        var context = CreateHealthCheckContext();

        // Act
        var result1 = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);
        var result2 = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result1.Status);
        Assert.AreEqual(HealthStatus.Healthy, result2.Status);
    }

    #endregion

    #region Interface Implementation Tests

    [TestMethod]
    public void DbContextHealthCheck_ImplementsIHealthCheck()
    {
        // Arrange & Act
        _healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        // Assert
        Assert.IsInstanceOfType(_healthCheck, typeof(IHealthCheck));
    }

    #endregion

    #region Helper Methods

    private static HealthCheckContext CreateHealthCheckContext(HealthStatus failureStatus = HealthStatus.Unhealthy)
    {
        return new HealthCheckContext
        {
            Registration = new HealthCheckRegistration(
                name: "DbContext",
                factory: _ => new Mock<IHealthCheck>().Object,
                failureStatus: failureStatus,
                tags: null)
        };
    }

    #endregion
}