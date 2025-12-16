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
    private readonly ActivitySource _activitySource;
    private ServiceBusProcessor? _processor;

    /// <summary>
    /// Initializes a new instance of the OrderMessageHandler.
    /// </summary>
    /// <param name="logger">Logger for structured logging with trace correlation.</param>
    /// <param name="serviceBusClient">Service Bus client injected by Aspire integration.</param>
    public OrderMessageHandler(
        ILogger<OrderMessageHandler> logger,
        ServiceBusClient serviceBusClient)
    {
        _logger = logger;
        _serviceBusClient = serviceBusClient;
        _activitySource = Extensions.CreateActivitySource();
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Create processor for the orders queue
        _processor = _serviceBusClient.CreateProcessor("orders-queue", new ServiceBusProcessorOptions
        {
            MaxConcurrentCalls = 10,
            AutoCompleteMessages = false
        });

        // Register message and error handlers
        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        _logger.LogInformation("Starting Service Bus message processor for queue: orders-queue");
        await _processor.StartProcessingAsync(stoppingToken);

        // Wait for cancellation
        await Task.Delay(Timeout.Infinite, stoppingToken);
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

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Stopping Service Bus message processor");

        if (_processor != null)
        {
            await _processor.StopProcessingAsync(cancellationToken);
            await _processor.DisposeAsync();
        }

        await base.StopAsync(cancellationToken);
    }
}