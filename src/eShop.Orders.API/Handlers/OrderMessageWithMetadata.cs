using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Handlers;

/// <summary>
/// Represents an order message with its Service Bus metadata.
/// </summary>
public sealed class OrderMessageWithMetadata
{
    /// <summary>
    /// The order data.
    /// </summary>
    public required Order Order { get; init; }

    /// <summary>
    /// The Service Bus message ID.
    /// </summary>
    public required string MessageId { get; init; }

    /// <summary>
    /// The message sequence number.
    /// </summary>
    public long SequenceNumber { get; init; }

    /// <summary>
    /// The time the message was enqueued.
    /// </summary>
    public DateTimeOffset EnqueuedTime { get; init; }

    /// <summary>
    /// The content type of the message.
    /// </summary>
    public string? ContentType { get; init; }

    /// <summary>
    /// The subject of the message.
    /// </summary>
    public string? Subject { get; init; }

    /// <summary>
    /// The correlation ID of the message.
    /// </summary>
    public string? CorrelationId { get; init; }

    /// <summary>
    /// The size of the message in bytes.
    /// </summary>
    public long MessageSize { get; init; }

    /// <summary>
    /// Application properties from the message.
    /// </summary>
    public IReadOnlyDictionary<string, object> ApplicationProperties { get; init; } = new Dictionary<string, object>();
}

