using System.ComponentModel.DataAnnotations;

namespace eShop.Orders.API.Models;

/// <summary>
/// Represents an order in the eShop system
/// </summary>
public class Order
{
    /// <summary>
    /// Gets or sets the unique identifier for the order
    /// </summary>
    [Required(ErrorMessage = "Order ID is required")]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the order date and time
    /// </summary>
    [Required(ErrorMessage = "Order date is required")]
    public DateTime Date { get; set; }

    /// <summary>
    /// Gets or sets the quantity
    /// </summary>
    [Required]
    [Range(1, int.MaxValue, ErrorMessage = "Quantity must be at least 1")]
    public int Quantity { get; set; }

    /// <summary>
    /// Gets or sets the total amount
    /// </summary>
    [Required]
    [Range(0.01, double.MaxValue, ErrorMessage = "Total must be greater than 0")]
    public decimal Total { get; set; }

    /// <summary>
    /// Gets or sets the order message
    /// </summary>
    [Required(ErrorMessage = "Message is required")]
    public string Message { get; set; } = string.Empty;
}