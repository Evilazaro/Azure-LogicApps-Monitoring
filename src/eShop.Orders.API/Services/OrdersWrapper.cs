// =============================================================================
// Orders Wrapper - Response Model
// Container class for wrapping order collections in API responses
// =============================================================================

using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Services;

/// <summary>
/// Wrapper class for encapsulating a collection of orders in API responses.
/// Provides a consistent response structure for order list operations.
/// </summary>
public sealed class OrdersWrapper
{
    /// <summary>
    /// Gets or initializes the collection of orders.
    /// </summary>
    public required List<Order> Orders { get; init; } = [];
}