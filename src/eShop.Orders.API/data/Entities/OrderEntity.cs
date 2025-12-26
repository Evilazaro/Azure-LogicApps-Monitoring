using System.ComponentModel.DataAnnotations;

namespace eShop.Orders.API.Data.Entities;

/// <summary>
/// Entity representing an order in the database.
/// Maps to the Orders table.
/// </summary>
public sealed class OrderEntity
{
    /// <summary>
    /// Gets or sets the unique identifier for the order.
    /// </summary>
    [Key]
    [Required]
    [MaxLength(100)]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the unique identifier for the customer who placed the order.
    /// </summary>
    [Required]
    [MaxLength(100)]
    public string CustomerId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the date and time when the order was placed.
    /// </summary>
    [Required]
    public DateTime Date { get; set; }

    /// <summary>
    /// Gets or sets the delivery address for the order.
    /// </summary>
    [Required]
    [MaxLength(500)]
    public string DeliveryAddress { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the total amount for the order.
    /// </summary>
    [Required]
    public decimal Total { get; set; }

    /// <summary>
    /// Gets or sets the collection of products included in this order.
    /// Navigation property for the one-to-many relationship.
    /// </summary>
    public ICollection<OrderProductEntity> Products { get; set; } = new List<OrderProductEntity>();
}
