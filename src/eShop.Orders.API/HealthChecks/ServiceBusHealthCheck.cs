// =============================================================================
// Service Bus Health Check
// Monitors Azure Service Bus connectivity with actual connection verification
// =============================================================================

using Azure.Messaging.ServiceBus;
using Azure.Messaging.ServiceBus.Administration;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Diagnostics;

namespace eShop.Orders.API.HealthChecks;

/// <summary>
/// Health check for Azure Service Bus connectivity.
/// Verifies actual connectivity by checking topic properties.
/// </summary>
public sealed class ServiceBusHealthCheck : IHealthCheck
{
    private readonly ServiceBusClient _serviceBusClient;
    private readonly ILogger<ServiceBusHealthCheck> _logger;
    private readonly string _topicName;
    private readonly string? _fullyQualifiedNamespace;

    /// <summary>
    /// Initializes a new instance of the <see cref="ServiceBusHealthCheck"/> class.
    /// </summary>
    /// <param name="serviceBusClient">The Service Bus client for connectivity checks.</param>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <param name="configuration">The configuration to retrieve Service Bus settings.</param>
    /// <exception cref="ArgumentNullException">Thrown when any parameter is null.</exception>
    public ServiceBusHealthCheck(
        ServiceBusClient serviceBusClient,
        ILogger<ServiceBusHealthCheck> logger,
        IConfiguration configuration)
    {
        _serviceBusClient = serviceBusClient ?? throw new ArgumentNullException(nameof(serviceBusClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        ArgumentNullException.ThrowIfNull(configuration);

        _topicName = configuration["Azure:ServiceBus:TopicName"] ?? "ordersplaced";
        _fullyQualifiedNamespace = _serviceBusClient.FullyQualifiedNamespace;
    }

    /// <summary>
    /// Checks the health of the Service Bus connection.
    /// </summary>
    /// <param name="context">The health check context.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The health check result indicating Service Bus connectivity status.</returns>
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();

        try
        {
            // Use a reasonable timeout for health checks (5 seconds)
            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeoutCts.CancelAfter(TimeSpan.FromSeconds(5));

            // Verify actual connectivity by attempting to create a sender and checking if it can be opened
            // The sender creation verifies the client is properly configured and can reach Service Bus
            await using var sender = _serviceBusClient.CreateSender(_topicName);

            // For a more thorough check, we attempt to create a message batch
            // This forces actual communication with Service Bus to validate quotas and permissions
            using var messageBatch = await sender.CreateMessageBatchAsync(timeoutCts.Token);

            stopwatch.Stop();

            var healthData = new Dictionary<string, object>
            {
                ["Namespace"] = _fullyQualifiedNamespace ?? "unknown",
                ["TopicName"] = _topicName,
                ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds
            };

            return HealthCheckResult.Healthy(
                $"Service Bus connection is healthy. Namespace: {_fullyQualifiedNamespace}, Topic: {_topicName}, Response time: {stopwatch.ElapsedMilliseconds}ms",
                healthData);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            stopwatch.Stop();
            _logger.LogWarning(
                "Service Bus health check timed out after {ElapsedMs}ms for topic {TopicName}",
                stopwatch.ElapsedMilliseconds,
                _topicName);

            return HealthCheckResult.Degraded(
                $"Service Bus health check timed out after {stopwatch.ElapsedMilliseconds}ms",
                data: new Dictionary<string, object>
                {
                    ["Namespace"] = _fullyQualifiedNamespace ?? "unknown",
                    ["TopicName"] = _topicName,
                    ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds,
                    ["TimedOut"] = true
                });
        }
        catch (ServiceBusException ex) when (ex.IsTransient)
        {
            stopwatch.Stop();
            _logger.LogWarning(
                ex,
                "Transient Service Bus health check failure for topic {TopicName}: {Reason}",
                _topicName,
                ex.Reason);

            return HealthCheckResult.Degraded(
                $"Service Bus connection is degraded (transient error): {ex.Message}",
                ex,
                new Dictionary<string, object>
                {
                    ["Namespace"] = _fullyQualifiedNamespace ?? "unknown",
                    ["TopicName"] = _topicName,
                    ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds,
                    ["ErrorReason"] = ex.Reason.ToString(),
                    ["IsTransient"] = true
                });
        }
        catch (ServiceBusException ex)
        {
            stopwatch.Stop();
            _logger.LogError(
                ex,
                "Service Bus health check failed for topic {TopicName}: {Reason}",
                _topicName,
                ex.Reason);

            return new HealthCheckResult(
                context.Registration.FailureStatus,
                description: $"Service Bus connection failed: {ex.Message} (Reason: {ex.Reason})",
                exception: ex,
                data: new Dictionary<string, object>
                {
                    ["Namespace"] = _fullyQualifiedNamespace ?? "unknown",
                    ["TopicName"] = _topicName,
                    ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds,
                    ["ErrorReason"] = ex.Reason.ToString(),
                    ["IsTransient"] = false
                });
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Service Bus health check failed unexpectedly for topic {TopicName}", _topicName);

            return new HealthCheckResult(
                context.Registration.FailureStatus,
                description: $"Service Bus connection failed: {ex.Message}",
                exception: ex,
                data: new Dictionary<string, object>
                {
                    ["Namespace"] = _fullyQualifiedNamespace ?? "unknown",
                    ["TopicName"] = _topicName,
                    ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds,
                    ["ErrorType"] = ex.GetType().Name
                });
        }
    }
}