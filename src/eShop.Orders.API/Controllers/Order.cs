using System.ComponentModel.DataAnnotations;

namespace eShop.Orders.API.Models;

/// <summary>
/// Represents an order in the eShop system
/// </summary>
public sealed record Order
{
    /// <summary>
    /// Gets the unique identifier for the order
    /// </summary>
    [Required]
    [Range(1, int.MaxValue, ErrorMessage = "Order ID must be greater than 0")]
    public required int Id { get; init; }

    /// <summary>
    /// Gets the customer identifier
    /// </summary>
    [Required(ErrorMessage = "Customer ID is required")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "Customer ID must be between 1 and 100 characters")]
    public required string CustomerId { get; init; }

    /// <summary>
    /// Gets the order date and time
    /// </summary>
    [Required]
    public required DateTimeOffset OrderDate { get; init; }

    /// <summary>
    /// Gets the total order amount
    /// </summary>
    [Required]
    [Range(0.01, double.MaxValue, ErrorMessage = "Total amount must be greater than 0")]
    public required decimal TotalAmount { get; init; }

    /// <summary>
    /// Gets the order status
    /// </summary>
    [Required(ErrorMessage = "Status is required")]
    [StringLength(50, ErrorMessage = "Status must not exceed 50 characters")]
    public required string Status { get; init; }

    /// <summary>
    /// Gets the collection of order items
    /// </summary>
    [Required]
    [MinLength(1, ErrorMessage = "At least one order item is required")]
    public required IReadOnlyList<OrderItem> Items { get; init; }
}

/// <summary>
/// Represents an item within an order
/// </summary>
public sealed record OrderItem
{
    /// <summary>
    /// Gets the product identifier
    /// </summary>
    [Required(ErrorMessage = "Product ID is required")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "Product ID must be between 1 and 100 characters")]
    public required string ProductId { get; init; }

    /// <summary>
    /// Gets the product name
    /// </summary>
    [Required(ErrorMessage = "Product name is required")]
    [StringLength(200, MinimumLength = 1, ErrorMessage = "Product name must be between 1 and 200 characters")]
    public required string ProductName { get; init; }

    /// <summary>
    /// Gets the quantity ordered
    /// </summary>
    [Required]
    [Range(1, int.MaxValue, ErrorMessage = "Quantity must be at least 1")]
    public required int Quantity { get; init; }

    /// <summary>
    /// Gets the unit price
    /// </summary>
    [Required]
    [Range(0.01, double.MaxValue, ErrorMessage = "Unit price must be greater than 0")]
    public required decimal UnitPrice { get; init; }
}