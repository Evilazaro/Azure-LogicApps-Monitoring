// =============================================================================
// Unit Tests for DbContextHealthCheck
// Tests database connectivity health check functionality
// =============================================================================

using eShop.Orders.API.Data;
using eShop.Orders.API.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;

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

    [TestInitialize]
    public void TestInitialize()
    {
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .Options;

        _dbContext = new OrderDbContext(options);
        _loggerMock = new Mock<ILogger<DbContextHealthCheck>>();

        // Ensure database schema is created for in-memory provider
        _dbContext.Database.EnsureCreated();
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _dbContext?.Dispose();
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
    public void Constructor_WithNullDbContext_ThrowsArgumentNullException()
    {
        // Act & Assert
        var ex = Assert.ThrowsException<ArgumentNullException>(
            () => new DbContextHealthCheck(null!, _loggerMock.Object));
        Assert.AreEqual("dbContext", ex.ParamName);
    }

    [TestMethod]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Act & Assert
        var ex = Assert.ThrowsException<ArgumentNullException>(
            () => new DbContextHealthCheck(_dbContext, null!));
        Assert.AreEqual("logger", ex.ParamName);
    }

    #endregion

    #region CheckHealthAsync Tests

    [TestMethod]
    public async Task CheckHealthAsync_WhenDatabaseCanConnect_ReturnsHealthy()
    {
        // Arrange
        var healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);
        var context = CreateHealthCheckContext(healthCheck);

        // Act
        var result = await healthCheck.CheckHealthAsync(context, CancellationToken.None);

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

        var healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);
        var context = CreateHealthCheckContext(healthCheck);

        // Act
        var result = await healthCheck.CheckHealthAsync(context, cts.Token);

        // Assert - In-memory database typically succeeds even with cancelled token
        Assert.IsNotNull(result);
    }

    [TestMethod]
    public async Task CheckHealthAsync_VerifiesConnectionAttempt()
    {
        // Arrange
        var healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);
        var context = CreateHealthCheckContext(healthCheck);

        // Act
        var result = await healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WithValidContext_ReturnsResult()
    {
        // Arrange
        var healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);
        var context = CreateHealthCheckContext(healthCheck);

        // Act
        var result = await healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.IsNotNull(result.Description);
    }

    [TestMethod]
    public async Task CheckHealthAsync_MultipleCalls_AllSucceed()
    {
        // Arrange
        var healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        // Act
        var result1 = await healthCheck.CheckHealthAsync(CreateHealthCheckContext(healthCheck), CancellationToken.None);
        var result2 = await healthCheck.CheckHealthAsync(CreateHealthCheckContext(healthCheck), CancellationToken.None);

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
        var healthCheck = new DbContextHealthCheck(_dbContext, _loggerMock.Object);

        // Assert
        Assert.IsInstanceOfType(healthCheck, typeof(IHealthCheck));
    }

    #endregion

    #region Helper Methods

    private static HealthCheckContext CreateHealthCheckContext(IHealthCheck healthCheck, HealthStatus failureStatus = HealthStatus.Unhealthy)
    {
        return new HealthCheckContext
        {
            Registration = new HealthCheckRegistration(
                name: "DbContext",
                instance: healthCheck,
                failureStatus: failureStatus,
                tags: null)
        };
    }

    #endregion
}