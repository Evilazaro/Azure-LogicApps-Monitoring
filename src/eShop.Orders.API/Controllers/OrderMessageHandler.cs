using Azure.Messaging.ServiceBus;
using System.Diagnostics;

namespace eShop.Orders.API.Services;

/// <summary>
/// Background service for processing Service Bus messages with distributed tracing.
/// Demonstrates context propagation from message producer to consumer.
/// </summary>
public class OrderMessageHandler : BackgroundService
{
    private readonly ILogger<OrderMessageHandler> _logger;
    private readonly ServiceBusClient _serviceBusClient;
    private static readonly ActivitySource _activitySource = Extensions.CreateActivitySource();
    private ServiceBusProcessor? _processor;
    private const string QueueName = "orders-queue";

    /// <summary>
    /// Initializes a new instance of the OrderMessageHandler.
    /// </summary>
    /// <param name="logger">Logger for structured logging with trace correlation.</param>
    /// <param name="serviceBusClient">Service Bus client injected by Aspire integration.</param>
    /// <exception cref="ArgumentNullException">Thrown when required dependencies are null.</exception>
    public OrderMessageHandler(
        ILogger<OrderMessageHandler> logger,
        ServiceBusClient serviceBusClient)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _serviceBusClient = serviceBusClient ?? throw new ArgumentNullException(nameof(serviceBusClient));
    }

    /// <inheritdoc/>
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Check if Service Bus client is configured properly
        if (_serviceBusClient == null)
        {
            _logger.LogWarning(
                "Service Bus client is not configured. Message processing will not start. " +
                "Ensure 'messaging' connection string is configured in appsettings or via Aspire.");
            return;
        }

        try
        {
            // Create processor for the orders queue
            _processor = _serviceBusClient.CreateProcessor(QueueName, new ServiceBusProcessorOptions
            {
                MaxConcurrentCalls = 10,
                AutoCompleteMessages = false,
                MaxAutoLockRenewalDuration = TimeSpan.FromMinutes(5)
            });

            // Register message and error handlers
            _processor.ProcessMessageAsync += ProcessMessageAsync;
            _processor.ProcessErrorAsync += ProcessErrorAsync;

            _logger.LogInformation("Starting Service Bus message processor for queue: {QueueName}", QueueName);
            await _processor.StartProcessingAsync(stoppingToken);

            _logger.LogInformation("Service Bus processor started successfully");

            // Wait for cancellation
            try
            {
                await Task.Delay(Timeout.Infinite, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Service Bus processor cancellation requested");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start Service Bus message processor");
            throw;
        }
    }

    /// <summary>
    /// Processes incoming Service Bus messages with distributed tracing.
    /// Extracts trace context from message properties to maintain correlation.
    /// </summary>
    /// <param name="args">Message event arguments containing the message.</param>
    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        // Extract trace context from message properties (W3C Trace Context)
        var traceparent = args.Message.ApplicationProperties.TryGetValue("traceparent", out var tp)
            ? tp?.ToString()
            : null;

        // Create a new activity with the parent context from the message
        using var activity = _activitySource.StartActivity(
            "ProcessOrderMessage",
            ActivityKind.Consumer,
            traceparent ?? Activity.Current?.Id ?? string.Empty);

        try
        {
            // Add message metadata as tags
            activity?.SetTag("messaging.system", "servicebus");
            activity?.SetTag("messaging.destination", args.EntityPath);
            activity?.SetTag("messaging.operation", "process");
            activity?.SetTag("messaging.message_id", args.Message.MessageId);
            activity?.SetTag("messaging.correlation_id", args.Message.CorrelationId);

            _logger.LogInformation(
                "Processing message {MessageId} from queue {QueueName}",
                args.Message.MessageId,
                args.EntityPath);

            // Extract order ID from message body
            var messageBody = args.Message.Body.ToString();
            activity?.SetTag("message.body_size", args.Message.Body.Length);

            // Create child span for business logic processing
            using (var processingActivity = _activitySource.StartActivity("ProcessOrder.BusinessLogic", ActivityKind.Internal))
            {
                processingActivity?.SetTag("order.processing", "true");

                // Simulate order processing
                await Task.Delay(100); // Replace with actual processing logic

                processingActivity?.AddEvent(new ActivityEvent("Order processed successfully"));
            }

            // Complete the message
            await args.CompleteMessageAsync(args.Message);

            activity?.SetStatus(ActivityStatusCode.Ok);
            activity?.AddEvent(new ActivityEvent("Message processed and completed"));

            _logger.LogInformation("Successfully processed message {MessageId}", args.Message.MessageId);
        }
        catch (Exception ex)
        {
            // Set span status to error
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "Error processing message {MessageId}", args.Message.MessageId);

            // Abandon the message for retry
            await args.AbandonMessageAsync(args.Message);
        }
    }

    /// <summary>
    /// Handles Service Bus processing errors with tracing.
    /// </summary>
    /// <param name="args">Error event arguments.</param>
    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        using var activity = _activitySource.StartActivity("ProcessError", ActivityKind.Consumer);

        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("error.type", args.Exception.GetType().FullName);
        activity?.SetStatus(ActivityStatusCode.Error, args.Exception.Message);
        activity?.AddException(args.Exception);

        _logger.LogError(
            args.Exception,
            "Error in Service Bus processor. Entity: {EntityPath}, Error: {ErrorSource}",
            args.EntityPath,
            args.ErrorSource);

        return Task.CompletedTask;
    }

    /// <inheritdoc/>
    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Stopping Service Bus message processor");

        if (_processor != null)
        {
            try
            {
                await _processor.StopProcessingAsync(cancellationToken);
                _logger.LogInformation("Service Bus processor stopped successfully");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error stopping Service Bus processor");
            }
            finally
            {
                await _processor.DisposeAsync();
            }
        }

        await base.StopAsync(cancellationToken);
    }
}