using System.ComponentModel.DataAnnotations;

namespace eShop.Orders.App.Client.Models;

/// <summary>
/// Represents an order in the eShop system.
/// </summary>
/// <remarks>
/// This model is used for both API requests/responses and data validation.
/// All properties include data annotations for automatic model validation.
/// </remarks>
public sealed class Order
{
    /// <summary>
    /// Gets or sets the unique identifier for the order.
    /// </summary>
    [Required(ErrorMessage = "Order ID is required")]
    [StringLength(50, MinimumLength = 1, ErrorMessage = "Order ID must be between 1 and 50 characters")]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the order date and time in UTC.
    /// </summary>
    [Required(ErrorMessage = "Order date is required")]
    public DateTime Date { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Gets or sets the quantity of items ordered.
    /// </summary>
    [Required(ErrorMessage = "Quantity is required")]
    [Range(1, int.MaxValue, ErrorMessage = "Quantity must be at least 1")]
    public int Quantity { get; set; } = 1;

    /// <summary>
    /// Gets or sets the total amount for the order in the system's base currency.
    /// </summary>
    [Required(ErrorMessage = "Total is required")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Total must be greater than 0")]
    public decimal Total { get; set; }

    /// <summary>
    /// Gets or sets the order confirmation or customer message.
    /// </summary>
    [Required(ErrorMessage = "Message is required")]
    [StringLength(500, MinimumLength = 1, ErrorMessage = "Message must be between 1 and 500 characters")]
    public string Message { get; set; } = "Thank you for your order!";
}