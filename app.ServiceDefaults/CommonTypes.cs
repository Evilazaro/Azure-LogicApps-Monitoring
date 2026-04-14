// =============================================================================
// Common Types - Shared Domain Models
// Contains shared data models used across the eShop distributed application
// =============================================================================

using System.ComponentModel.DataAnnotations;

namespace app.ServiceDefaults.CommonTypes;

/// <summary>
/// Contains shared domain models used across the eShop distributed application.
/// </summary>
/// <remarks>
/// This namespace provides common data transfer objects and domain models including:
/// <list type="bullet">
///     <item><description><see cref="WeatherForecast"/> - Weather forecast data for demonstration and health checks</description></item>
///     <item><description><see cref="Order"/> - Customer order with products and delivery information</description></item>
///     <item><description><see cref="OrderProduct"/> - Individual product item within an order</description></item>
/// </list>
/// All models include data validation attributes for ensuring data integrity.
/// </remarks>

/// <summary>
/// Represents a weather forecast with temperature and condition information.
/// Used for demonstration and health check purposes.
/// </summary>
/// <remarks>
/// This class provides weather forecast data including the date, temperature in both
/// Celsius and Fahrenheit, and a textual summary of conditions. The Fahrenheit temperature
/// is automatically calculated from the Celsius value.
/// </remarks>
/// <example>
/// <code>
/// var forecast = new WeatherForecast
/// {
///     Date = DateOnly.FromDateTime(DateTime.Now),
///     TemperatureC = 25,
///     Summary = "Warm and sunny"
/// };
/// Console.WriteLine($"Temperature: {forecast.TemperatureF}°F");
/// </code>
/// </example>
public sealed class WeatherForecast
{
    /// <summary>
    /// Gets or sets the date of the forecast.
    /// </summary>
    public required DateOnly Date { get; set; }

    /// <summary>
    /// Gets or sets the temperature in Celsius.
    /// </summary>
    [Range(-273, 200, ErrorMessage = "Temperature must be between -273°C and 200°C")]
    public required int TemperatureC { get; set; }

    /// <summary>
    /// Gets the temperature in Fahrenheit (calculated from Celsius).
    /// </summary>
    public int TemperatureF => 32 + (int)(TemperatureC * 1.8);

    /// <summary>
    /// Gets or sets a summary description of the weather conditions.
    /// </summary>
    [MaxLength(100, ErrorMessage = "Summary must not exceed 100 characters")]
    public string? Summary { get; set; }
}

/// <summary>
/// Represents a customer order with products, delivery information, and total amount.
/// </summary>
public sealed record Order
{
    /// <summary>
    /// Gets the unique identifier for the order.
    /// </summary>
    [Required(ErrorMessage = "Order ID is required")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "Order ID must be between 1 and 100 characters")]
    public required string Id { get; init; }

    /// <summary>
    /// Gets the unique identifier for the customer who placed the order.
    /// </summary>
    [Required(ErrorMessage = "Customer ID is required")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "Customer ID must be between 1 and 100 characters")]
    public required string CustomerId { get; init; }

    /// <summary>
    /// Gets the date and time when the order was placed.
    /// </summary>
    public DateTime Date { get; init; } = DateTime.UtcNow;

    /// <summary>
    /// Gets the delivery address for the order.
    /// </summary>
    [Required(ErrorMessage = "Delivery address is required")]
    [StringLength(500, MinimumLength = 5, ErrorMessage = "Delivery address must be between 5 and 500 characters")]
    public required string DeliveryAddress { get; init; }

    /// <summary>
    /// Gets the total amount for the order.
    /// </summary>
    [Range(0.01, double.MaxValue, ErrorMessage = "Order total must be greater than zero")]
    public decimal Total { get; init; }

    /// <summary>
    /// Gets the list of products included in the order.
    /// </summary>
    [Required(ErrorMessage = "Order must contain at least one product")]
    [MinLength(1, ErrorMessage = "Order must contain at least one product")]
    public required List<OrderProduct> Products { get; init; }
}

/// <summary>
/// Represents a product item within an order.
/// </summary>
public sealed record OrderProduct
{
    /// <summary>
    /// Gets the unique identifier for this order product entry.
    /// </summary>
    [Required(ErrorMessage = "Order product ID is required")]
    public required string Id { get; init; }

    /// <summary>
    /// Gets the identifier of the order this product belongs to.
    /// </summary>
    [Required(ErrorMessage = "Order ID is required")]
    public required string OrderId { get; init; }

    /// <summary>
    /// Gets the unique identifier of the product.
    /// </summary>
    [Required(ErrorMessage = "Product ID is required")]
    public required string ProductId { get; init; }

    /// <summary>
    /// Gets the description of the product.
    /// </summary>
    [Required(ErrorMessage = "Product description is required")]
    [StringLength(500, MinimumLength = 1, ErrorMessage = "Product description must be between 1 and 500 characters")]
    public required string ProductDescription { get; init; }

    /// <summary>
    /// Gets the quantity of the product ordered.
    /// </summary>
    [Range(1, int.MaxValue, ErrorMessage = "Quantity must be at least 1")]
    public int Quantity { get; init; }

    /// <summary>
    /// Gets the unit price of the product.
    /// </summary>
    [Range(0.01, double.MaxValue, ErrorMessage = "Price must be greater than zero")]
    public decimal Price { get; init; }
}
