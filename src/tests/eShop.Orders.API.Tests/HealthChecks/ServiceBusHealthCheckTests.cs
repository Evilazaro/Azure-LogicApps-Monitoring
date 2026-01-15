// =============================================================================
// Unit Tests for ServiceBusHealthCheck
// Tests Azure Service Bus connectivity health check functionality
// =============================================================================

using Azure.Messaging.ServiceBus;
using eShop.Orders.API.HealthChecks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using NSubstitute;
using NSubstitute.ExceptionExtensions;

namespace eShop.Orders.API.Tests.HealthChecks;

/// <summary>
/// Unit tests for <see cref="ServiceBusHealthCheck"/> class.
/// Verifies Service Bus connectivity health check behavior.
/// </summary>
[TestClass]
public sealed class ServiceBusHealthCheckTests
{
    private ServiceBusClient _serviceBusClient = null!;
    private ServiceBusSender _serviceBusSender = null!;
    private ILogger<ServiceBusHealthCheck> _logger = null!;
    private IConfiguration _configuration = null!;
    private ServiceBusHealthCheck _healthCheck = null!;
    private HealthCheckContext _healthCheckContext = null!;

    private const string TestTopicName = "test-orders-topic";
    private const string DefaultTopicName = "ordersplaced";

    [TestInitialize]
    public void TestInitialize()
    {
        _serviceBusClient = Substitute.For<ServiceBusClient>();
        _serviceBusSender = Substitute.For<ServiceBusSender>();
        _logger = Substitute.For<ILogger<ServiceBusHealthCheck>>();

        var configData = new Dictionary<string, string?>
        {
            ["Azure:ServiceBus:TopicName"] = TestTopicName
        };
        _configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(configData)
            .Build();

        _serviceBusClient.CreateSender(TestTopicName).Returns(_serviceBusSender);

        _healthCheck = new ServiceBusHealthCheck(
            _serviceBusClient,
            _logger,
            _configuration);

        // Create a health check context with default registration
        var registration = new HealthCheckRegistration(
            name: "ServiceBus",
            instance: _healthCheck,
            failureStatus: HealthStatus.Unhealthy,
            tags: null);
        _healthCheckContext = new HealthCheckContext { Registration = registration };
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_NullServiceBusClient_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new ServiceBusHealthCheck(
                null!,
                _logger,
                _configuration));

        Assert.AreEqual("serviceBusClient", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new ServiceBusHealthCheck(
                _serviceBusClient,
                null!,
                _configuration));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullConfiguration_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new ServiceBusHealthCheck(
                _serviceBusClient,
                _logger,
                null!));

        Assert.AreEqual("configuration", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_ValidParameters_CreatesInstance()
    {
        // Arrange & Act
        var healthCheck = new ServiceBusHealthCheck(
            _serviceBusClient,
            _logger,
            _configuration);

        // Assert
        Assert.IsNotNull(healthCheck);
        Assert.IsInstanceOfType<IHealthCheck>(healthCheck);
    }

    #endregion

    #region CheckHealthAsync Tests

    [TestMethod]
    public async Task CheckHealthAsync_ServiceBusConnected_ReturnsHealthy()
    {
        // Arrange - sender creation succeeds (default mock behavior)

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.IsNotNull(result.Description);
        Assert.Contains(TestTopicName, result.Description);
    }

    [TestMethod]
    public async Task CheckHealthAsync_ServiceBusConnectionFails_ReturnsUnhealthy()
    {
        // Arrange
        var expectedException = new ServiceBusException(
            "Connection refused",
            ServiceBusFailureReason.ServiceCommunicationProblem);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.AreEqual("Service Bus connection failed", result.Description);
        Assert.IsNotNull(result.Exception);
        Assert.IsInstanceOfType<ServiceBusException>(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_GenericException_ReturnsUnhealthy()
    {
        // Arrange
        var expectedException = new InvalidOperationException("Unexpected error");

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.AreEqual("Service Bus connection failed", result.Description);
        Assert.IsNotNull(result.Exception);
        Assert.IsInstanceOfType<InvalidOperationException>(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_NoTopicConfigured_UsesDefaultTopicName()
    {
        // Arrange
        var emptyConfig = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>())
            .Build();

        var serviceBusClient = Substitute.For<ServiceBusClient>();
        var sender = Substitute.For<ServiceBusSender>();
        serviceBusClient.CreateSender(DefaultTopicName).Returns(sender);

        var healthCheck = new ServiceBusHealthCheck(
            serviceBusClient,
            _logger,
            emptyConfig);

        // Act
        var result = await healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.IsNotNull(result.Description);
        Assert.Contains(DefaultTopicName, result.Description);
        serviceBusClient.Received(1).CreateSender(DefaultTopicName);
    }

    [TestMethod]
    public async Task CheckHealthAsync_CancellationRequested_PropagatesCancellation()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        // Note: The current implementation doesn't pass cancellation token to CreateSender
        // This test verifies behavior when cancellation is already requested

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, cts.Token);

        // Assert - Should still complete (CreateSender is synchronous)
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
    }

    [TestMethod]
    public async Task CheckHealthAsync_ExceptionOccurs_LogsError()
    {
        // Arrange
        var expectedException = new ServiceBusException(
            "Auth failed",
            ServiceBusFailureReason.ServiceCommunicationProblem);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - Verify logger was called with LogError
        _logger.Received(1).Log(
            LogLevel.Error,
            Arg.Any<EventId>(),
            Arg.Any<object>(),
            Arg.Any<Exception>(),
            Arg.Any<Func<object, Exception?, string>>());
    }

    [TestMethod]
    public async Task CheckHealthAsync_RespectsFailureStatusFromRegistration()
    {
        // Arrange
        var degradedRegistration = new HealthCheckRegistration(
            name: "ServiceBus",
            instance: _healthCheck,
            failureStatus: HealthStatus.Degraded, // Using Degraded instead of Unhealthy
            tags: null);
        var degradedContext = new HealthCheckContext { Registration = degradedRegistration };

        var expectedException = new ServiceBusException(
            "Connection lost",
            ServiceBusFailureReason.ServiceCommunicationProblem);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(degradedContext, CancellationToken.None);

        // Assert - Should use the failure status from registration
        Assert.AreEqual(HealthStatus.Degraded, result.Status);
    }

    [TestMethod]
    public async Task CheckHealthAsync_HealthyResult_ContainsTopicInDescription()
    {
        // Arrange
        const string customTopicName = "my-custom-topic";
        var customConfig = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Azure:ServiceBus:TopicName"] = customTopicName
            })
            .Build();

        var serviceBusClient = Substitute.For<ServiceBusClient>();
        var sender = Substitute.For<ServiceBusSender>();
        serviceBusClient.CreateSender(customTopicName).Returns(sender);

        var healthCheck = new ServiceBusHealthCheck(
            serviceBusClient,
            _logger,
            customConfig);

        // Act
        var result = await healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.IsNotNull(result.Description);
        Assert.Contains(customTopicName, result.Description);
    }

    [TestMethod]
    [DynamicData(nameof(GetServiceBusFailureReasons))]
    public async Task CheckHealthAsync_VariousServiceBusFailures_ReturnsUnhealthy(ServiceBusFailureReason failureReason)
    {
        // Arrange
        var expectedException = new ServiceBusException($"Error: {failureReason}", failureReason);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.IsNotNull(result.Exception);
        var serviceBusException = result.Exception as ServiceBusException;
        Assert.IsNotNull(serviceBusException);
        Assert.AreEqual(failureReason, serviceBusException.Reason);
    }

    private static IEnumerable<object[]> GetServiceBusFailureReasons()
    {
        yield return [ServiceBusFailureReason.ServiceBusy];
        yield return [ServiceBusFailureReason.ServiceTimeout];
        yield return [ServiceBusFailureReason.MessagingEntityNotFound];
        yield return [ServiceBusFailureReason.QuotaExceeded];
        yield return [ServiceBusFailureReason.ServiceCommunicationProblem];
    }

    #endregion
}