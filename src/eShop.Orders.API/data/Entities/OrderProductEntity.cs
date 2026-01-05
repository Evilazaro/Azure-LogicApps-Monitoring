// =============================================================================
// Order Product Entity - Database Model
// Represents a product item within an order in the database
// =============================================================================

using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eShop.Orders.API.Data.Entities;

/// <summary>
/// Entity representing a product item within an order in the database.
/// Maps to the OrderProducts table.
/// </summary>
public sealed class OrderProductEntity
{
    /// <summary>
    /// Gets or sets the unique identifier for this order product entry.
    /// </summary>
    [Key]
    [Required]
    [MaxLength(100)]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the identifier of the order this product belongs to.
    /// Foreign key to the Orders table.
    /// </summary>
    [Required]
    [MaxLength(100)]
    public string OrderId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the unique identifier of the product.
    /// </summary>
    [Required]
    [MaxLength(100)]
    public string ProductId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the description of the product.
    /// </summary>
    [Required]
    [MaxLength(500)]
    public string ProductDescription { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the quantity of the product ordered.
    /// </summary>
    [Required]
    public int Quantity { get; set; }

    /// <summary>
    /// Gets or sets the unit price of the product.
    /// </summary>
    [Required]
    public decimal Price { get; set; }

    /// <summary>
    /// Gets or sets the navigation property to the parent order.
    /// </summary>
    [ForeignKey(nameof(OrderId))]
    public OrderEntity? Order { get; set; }
}
