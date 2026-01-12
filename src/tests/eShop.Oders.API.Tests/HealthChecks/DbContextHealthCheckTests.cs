// =============================================================================
// Unit Tests for DbContextHealthCheck
// Tests database connectivity health check functionality
// =============================================================================

using eShop.Orders.API.Data;
using eShop.Orders.API.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
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
    private Mock<OrderDbContext> _dbContextMock = null!;
    private Mock<ILogger<DbContextHealthCheck>> _loggerMock = null!;
    private Mock<DatabaseFacade> _databaseFacadeMock = null!;
    private DbContextHealthCheck _healthCheck = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        // Create a mock of OrderDbContext without requiring actual DbContextOptions
        // Use MockBehavior.Loose to allow unmocked members to return defaults
        _dbContextMock = new Mock<OrderDbContext>(
            new DbContextOptions<OrderDbContext>())
        { CallBase = false };
        _loggerMock = new Mock<ILogger<DbContextHealthCheck>>();
        _databaseFacadeMock = new Mock<DatabaseFacade>(_dbContextMock.Object);

        _dbContextMock
            .Setup(c => c.Database)
            .Returns(_databaseFacadeMock.Object);
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_WithValidParameters_CreatesInstance()
    {
        // Act
        var healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

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
        _ = new DbContextHealthCheck(_dbContextMock.Object, null!);
    }

    #endregion

    #region CheckHealthAsync Tests

    [TestMethod]
    public async Task CheckHealthAsync_WhenDatabaseCanConnect_ReturnsHealthy()
    {
        // Arrange
        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        var context = CreateHealthCheckContext();

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.AreEqual("Database connection is healthy", result.Description);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenDatabaseThrowsException_ReturnsUnhealthy()
    {
        // Arrange
        var expectedException = new InvalidOperationException("Database connection failed");

        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(expectedException);

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        var context = CreateHealthCheckContext(HealthStatus.Unhealthy);

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.AreEqual("Database connection failed", result.Description);
        Assert.AreEqual(expectedException, result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenDatabaseThrowsException_LogsError()
    {
        // Arrange
        var expectedException = new InvalidOperationException("Connection timeout");

        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(expectedException);

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        var context = CreateHealthCheckContext(HealthStatus.Unhealthy);

        // Act
        await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Error,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Database health check failed")),
                expectedException,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenDatabaseThrowsException_UsesDegradedFailureStatus()
    {
        // Arrange
        var expectedException = new InvalidOperationException("Transient failure");

        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(expectedException);

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        // Configure with Degraded as failure status
        var context = CreateHealthCheckContext(HealthStatus.Degraded);

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Degraded, result.Status);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenCancellationRequested_ThrowsOperationCanceledException()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new OperationCanceledException());

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        var context = CreateHealthCheckContext(HealthStatus.Unhealthy);

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, cts.Token);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.IsInstanceOfType(result.Exception, typeof(OperationCanceledException));
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenDatabaseThrowsSqlException_ReturnsUnhealthyWithException()
    {
        // Arrange
        var sqlException = new InvalidOperationException("A network-related or instance-specific error occurred");

        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(sqlException);

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        var context = CreateHealthCheckContext(HealthStatus.Unhealthy);

        // Act
        var result = await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.AreEqual("Database connection failed", result.Description);
        Assert.IsNotNull(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_VerifiesCanConnectAsyncIsCalled()
    {
        // Arrange
        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        var context = CreateHealthCheckContext();

        // Act
        await _healthCheck.CheckHealthAsync(context, CancellationToken.None);

        // Assert
        _databaseFacadeMock.Verify(
            d => d.CanConnectAsync(It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [TestMethod]
    public async Task CheckHealthAsync_PassesCancellationTokenToCanConnectAsync()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        CancellationToken capturedToken = default;

        _databaseFacadeMock
            .Setup(d => d.CanConnectAsync(It.IsAny<CancellationToken>()))
            .Callback<CancellationToken>(token => capturedToken = token)
            .ReturnsAsync(true);

        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

        var context = CreateHealthCheckContext();

        // Act
        await _healthCheck.CheckHealthAsync(context, cts.Token);

        // Assert
        Assert.AreEqual(cts.Token, capturedToken);
    }

    #endregion

    #region Interface Implementation Tests

    [TestMethod]
    public void DbContextHealthCheck_ImplementsIHealthCheck()
    {
        // Arrange & Act
        _healthCheck = new DbContextHealthCheck(_dbContextMock.Object, _loggerMock.Object);

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
                instance: null!,
                failureStatus: failureStatus,
                tags: null)
        };
    }

    #endregion
}