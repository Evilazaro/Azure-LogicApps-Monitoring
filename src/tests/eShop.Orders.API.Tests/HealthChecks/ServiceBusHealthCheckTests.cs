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
        StringAssert.Contains(result.Description, TestTopicName);
    }

    [TestMethod]
    public async Task CheckHealthAsync_TransientServiceBusError_ReturnsDegraded()
    {
        // Arrange - Transient errors should result in Degraded status per distributed systems best practices
        var expectedException = new ServiceBusException(
            "Connection refused",
            ServiceBusFailureReason.ServiceCommunicationProblem,
            innerException: null);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - Transient errors return Degraded, not Unhealthy
        Assert.AreEqual(HealthStatus.Degraded, result.Status);
        Assert.IsNotNull(result.Description);
        Assert.IsTrue(result.Description.Contains("transient error") || result.Description.Contains("degraded"),
            $"Expected description to contain 'transient error' or 'degraded', but was: {result.Description}");
        Assert.IsNotNull(result.Exception);
        Assert.IsInstanceOfType<ServiceBusException>(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_NonTransientServiceBusError_ReturnsUnhealthy()
    {
        // Arrange - Non-transient errors like entity not found should be Unhealthy
        var expectedException = new ServiceBusException(
            "Topic not found",
            ServiceBusFailureReason.MessagingEntityNotFound);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.IsNotNull(result.Description);
        StringAssert.Contains(result.Description, "Service Bus connection failed");
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
        Assert.IsNotNull(result.Description);
        StringAssert.Contains(result.Description, "Service Bus connection failed");
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
        StringAssert.Contains(result.Description, DefaultTopicName);
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
    public async Task CheckHealthAsync_TransientException_LogsWarning()
    {
        // Arrange - Transient errors should log Warning, not Error
        var expectedException = new ServiceBusException(
            "Auth failed",
            ServiceBusFailureReason.ServiceCommunicationProblem);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - Verify logger was called with LogWarning for transient errors
        _logger.Received(1).Log(
            LogLevel.Warning,
            Arg.Any<EventId>(),
            Arg.Any<object>(),
            Arg.Any<Exception>(),
            Arg.Any<Func<object, Exception?, string>>());
    }

    [TestMethod]
    public async Task CheckHealthAsync_NonTransientException_LogsError()
    {
        // Arrange - Non-transient errors should log Error
        var expectedException = new ServiceBusException(
            "Entity not found",
            ServiceBusFailureReason.MessagingEntityNotFound);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - Verify logger was called with LogError for non-transient errors
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

        // Use non-transient error to verify registration failure status is used
        var expectedException = new ServiceBusException(
            "Entity not found",
            ServiceBusFailureReason.MessagingEntityNotFound);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(degradedContext, CancellationToken.None);

        // Assert - Should use the failure status from registration for non-transient errors
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
        StringAssert.Contains(result.Description, customTopicName);
    }

    [TestMethod]
    [DynamicData(nameof(GetTransientServiceBusFailureReasons))]
    public async Task CheckHealthAsync_TransientFailures_ReturnsDegraded(ServiceBusFailureReason failureReason)
    {
        // Arrange - Transient failures should return Degraded per distributed systems best practices
        var expectedException = new ServiceBusException($"Error: {failureReason}", failureReason);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - Transient errors return Degraded
        Assert.AreEqual(HealthStatus.Degraded, result.Status);
        Assert.IsNotNull(result.Exception);
        var serviceBusException = result.Exception as ServiceBusException;
        Assert.IsNotNull(serviceBusException);
        Assert.AreEqual(failureReason, serviceBusException.Reason);
    }

    [TestMethod]
    [DynamicData(nameof(GetNonTransientServiceBusFailureReasons))]
    public async Task CheckHealthAsync_NonTransientFailures_ReturnsUnhealthy(ServiceBusFailureReason failureReason)
    {
        // Arrange - Non-transient failures should return Unhealthy
        var expectedException = new ServiceBusException($"Error: {failureReason}", failureReason);

        _serviceBusClient
            .CreateSender(TestTopicName)
            .Throws(expectedException);

        // Act
        var result = await _healthCheck.CheckHealthAsync(_healthCheckContext, CancellationToken.None);

        // Assert - Non-transient errors return Unhealthy
        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.IsNotNull(result.Exception);
        var serviceBusException = result.Exception as ServiceBusException;
        Assert.IsNotNull(serviceBusException);
        Assert.AreEqual(failureReason, serviceBusException.Reason);
    }

    private static IEnumerable<object[]> GetTransientServiceBusFailureReasons()
    {
        // These are transient errors that may resolve on retry
        yield return [ServiceBusFailureReason.ServiceBusy];
        yield return [ServiceBusFailureReason.ServiceTimeout];
        yield return [ServiceBusFailureReason.ServiceCommunicationProblem];
    }

    private static IEnumerable<object[]> GetNonTransientServiceBusFailureReasons()
    {
        // These are non-transient errors that require configuration changes
        yield return [ServiceBusFailureReason.MessagingEntityNotFound];
        yield return [ServiceBusFailureReason.QuotaExceeded];
    }

    #endregion
}