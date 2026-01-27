// =============================================================================
// Order Mapper - Domain-Entity Mapping
// Provides mapping between domain models and database entities
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Data.Entities;

namespace eShop.Orders.API.Data;

/// <summary>
/// Provides extension methods for mapping between Order domain models and their corresponding database entities.
/// This static class enables bidirectional conversion between <see cref="Order"/> and <see cref="OrderEntity"/>,
/// as well as between <see cref="OrderProduct"/> and <see cref="OrderProductEntity"/>.
/// </summary>
/// <remarks>
/// All mapping methods are implemented as extension methods to provide a fluent API for conversions.
/// Null checks are performed on all input parameters to ensure safe mapping operations.
/// </remarks>
public static class OrderMapper
{
    /// <summary>
    /// Converts an Order domain model to an OrderEntity database entity.
    /// </summary>
    /// <param name="order">The order domain model to convert.</param>
    /// <returns>The converted OrderEntity.</returns>
    public static OrderEntity ToEntity(this Order order)
    {
        ArgumentNullException.ThrowIfNull(order);

        return new OrderEntity
        {
            Id = order.Id,
            CustomerId = order.CustomerId,
            Date = order.Date,
            DeliveryAddress = order.DeliveryAddress,
            Total = order.Total,
            Products = order.Products.Select(p => p.ToEntity()).ToList()
        };
    }

    /// <summary>
    /// Converts an OrderEntity database entity to an Order domain model.
    /// </summary>
    /// <param name="entity">The OrderEntity to convert.</param>
    /// <returns>The converted Order domain model.</returns>
    public static Order ToDomainModel(this OrderEntity entity)
    {
        ArgumentNullException.ThrowIfNull(entity);

        return new Order
        {
            Id = entity.Id,
            CustomerId = entity.CustomerId,
            Date = entity.Date,
            DeliveryAddress = entity.DeliveryAddress,
            Total = entity.Total,
            Products = entity.Products.Select(p => p.ToDomainModel()).ToList()
        };
    }

    /// <summary>
    /// Converts an OrderProduct domain model to an OrderProductEntity database entity.
    /// </summary>
    /// <param name="product">The OrderProduct domain model to convert.</param>
    /// <returns>The converted OrderProductEntity.</returns>
    public static OrderProductEntity ToEntity(this OrderProduct product)
    {
        ArgumentNullException.ThrowIfNull(product);

        return new OrderProductEntity
        {
            Id = product.Id,
            OrderId = product.OrderId,
            ProductId = product.ProductId,
            ProductDescription = product.ProductDescription,
            Quantity = product.Quantity,
            Price = product.Price
        };
    }

    /// <summary>
    /// Converts an OrderProductEntity database entity to an OrderProduct domain model.
    /// </summary>
    /// <param name="entity">The OrderProductEntity to convert.</param>
    /// <returns>The converted OrderProduct domain model.</returns>
    public static OrderProduct ToDomainModel(this OrderProductEntity entity)
    {
        ArgumentNullException.ThrowIfNull(entity);

        return new OrderProduct
        {
            Id = entity.Id,
            OrderId = entity.OrderId,
            ProductId = entity.ProductId,
            ProductDescription = entity.ProductDescription,
            Quantity = entity.Quantity,
            Price = entity.Price
        };
    }
}
