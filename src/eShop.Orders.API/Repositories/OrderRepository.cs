using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Data;
using eShop.Orders.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace eShop.Orders.API.Repositories;

/// <summary>
/// Provides Entity Framework Core-based persistence for order data with async operations.
/// Implements the repository pattern for order management with SQL Azure Database.
/// </summary>
public sealed class OrderRepository : IOrderRepository
{
    private readonly ILogger<OrderRepository> _logger;
    private readonly OrderDbContext _dbContext;

    /// <summary>
    /// Initializes a new instance of the <see cref="OrderRepository"/> class.
    /// </summary>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <param name="dbContext">The database context for EF Core operations.</param>
    /// <exception cref="ArgumentNullException">Thrown when any parameter is null.</exception>
    public OrderRepository(
        ILogger<OrderRepository> logger,
        OrderDbContext dbContext)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    /// <summary>
    /// Saves an order to the database asynchronously.
    /// Creates or updates the order if it already exists.
    /// </summary>
    /// <param name="order">The order to save.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    /// <exception cref="ArgumentNullException">Thrown when order is null.</exception>
    public async Task SaveOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        try
        {
            _logger.LogDebug("Saving order {OrderId} to database", order.Id);

            // Check if order already exists
            var existingOrder = await _dbContext.Orders
                .Include(o => o.Products)
                .FirstOrDefaultAsync(o => o.Id == order.Id, cancellationToken)
                .ConfigureAwait(false);

            if (existingOrder != null)
            {
                // Update existing order
                existingOrder.CustomerId = order.CustomerId;
                existingOrder.Date = order.Date;
                existingOrder.DeliveryAddress = order.DeliveryAddress;
                existingOrder.Total = order.Total;

                // Remove old products
                _dbContext.OrderProducts.RemoveRange(existingOrder.Products);

                // Add new products
                existingOrder.Products = order.Products.Select(p => p.ToEntity()).ToList();

                _dbContext.Orders.Update(existingOrder);
            }
            else
            {
                // Add new order
                var orderEntity = order.ToEntity();
                await _dbContext.Orders.AddAsync(orderEntity, cancellationToken).ConfigureAwait(false);
            }

            await _dbContext.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

            _logger.LogDebug("Order {OrderId} saved to database successfully", order.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save order {OrderId} to database", order.Id);
            throw;
        }
    }

    /// <summary>
    /// Retrieves all orders from the database asynchronously.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of all orders.</returns>
    public async Task<IEnumerable<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var orderEntities = await _dbContext.Orders
                .Include(o => o.Products)
                .AsNoTracking()
                .ToListAsync(cancellationToken)
                .ConfigureAwait(false);

            return orderEntities.Select(e => e.ToDomainModel()).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to retrieve all orders from database");
            throw;
        }
    }

    /// <summary>
    /// Retrieves a specific order by its unique identifier.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The order if found; otherwise, null.</returns>
    /// <exception cref="ArgumentException">Thrown when orderId is null or empty.</exception>
    public async Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
        }

        try
        {
            var orderEntity = await _dbContext.Orders
                .Include(o => o.Products)
                .AsNoTracking()
                .FirstOrDefaultAsync(o => o.Id == orderId, cancellationToken)
                .ConfigureAwait(false);

            return orderEntity?.ToDomainModel();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to retrieve order {OrderId} from database", orderId);
            throw;
        }
    }

    /// <summary>
    /// Deletes an order from the database by its unique identifier.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order to delete.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>True if the order was successfully deleted; otherwise, false.</returns>
    /// <exception cref="ArgumentException">Thrown when orderId is null or empty.</exception>
    public async Task<bool> DeleteOrderAsync(string orderId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
        }

        try
        {
            _logger.LogInformation("Deleting order {OrderId} from database", orderId);

            var orderEntity = await _dbContext.Orders
                .Include(o => o.Products)
                .FirstOrDefaultAsync(o => o.Id == orderId, cancellationToken)
                .ConfigureAwait(false);

            if (orderEntity == null)
            {
                _logger.LogWarning("Order {OrderId} not found in database for deletion", orderId);
                return false;
            }

            _dbContext.Orders.Remove(orderEntity);
            await _dbContext.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

            _logger.LogInformation("Successfully deleted order {OrderId} from database", orderId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting order {OrderId} from database", orderId);
            throw;
        }
    }
}
