// =============================================================================
// Order Repository - Data Access Layer
// Provides Entity Framework Core-based persistence for order data
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Data;
using eShop.Orders.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;

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
    /// Creates a new order if it doesn't exist.
    /// </summary>
    /// <param name="order">The order to save.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    /// <exception cref="ArgumentNullException">Thrown when order is null.</exception>
    public async Task SaveOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = Activity.Current;
        activity?.AddEvent(new ActivityEvent("SaveOrderStarted", tags: new ActivityTagsCollection
        {
            { "order.id", order.Id },
            { "order.customer_id", order.CustomerId }
        }));

        // Add trace context to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none",
            ["OrderId"] = order.Id
        });

        try
        {
            _logger.LogDebug("Saving order {OrderId} to database", order.Id);

            // Convert domain model to entity
            var orderEntity = order.ToEntity();

            // Add new order - EF Core will handle duplicate detection via exception
            await _dbContext.Orders.AddAsync(orderEntity, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);

            activity?.AddEvent(new ActivityEvent("SaveOrderCompleted"));
            _logger.LogDebug("Order {OrderId} saved to database successfully", order.Id);
        }
        catch (DbUpdateException ex) when (IsDuplicateKeyViolation(ex))
        {
            activity?.AddEvent(new ActivityEvent("SaveOrderFailed", tags: new ActivityTagsCollection
            {
                { "error.type", "DuplicateKeyViolation" },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
            _logger.LogError(ex, "Failed to save order {OrderId} - duplicate key violation", order.Id);
            throw new InvalidOperationException($"Order with ID {order.Id} already exists", ex);
        }
        catch (Exception ex)
        {
            activity?.AddEvent(new ActivityEvent("SaveOrderFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
            _logger.LogError(ex, "Failed to save order {OrderId} to database", order.Id);
            throw;
        }
    }

    /// <summary>
    /// Checks if a DbUpdateException is caused by a duplicate key violation.
    /// </summary>
    /// <param name="ex">The exception to check.</param>
    /// <returns>True if the exception is a duplicate key violation; otherwise, false.</returns>
    private static bool IsDuplicateKeyViolation(DbUpdateException ex)
    {
        return ex.InnerException?.Message.Contains("duplicate", StringComparison.OrdinalIgnoreCase) == true ||
               ex.InnerException?.Message.Contains("unique constraint", StringComparison.OrdinalIgnoreCase) == true ||
               ex.InnerException?.Message.Contains("primary key", StringComparison.OrdinalIgnoreCase) == true;
    }

    /// <summary>
    /// Retrieves all orders from the database asynchronously with optimized query.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of all orders.</returns>
    public async Task<IEnumerable<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default)
    {
        using var activity = Activity.Current;
        activity?.AddEvent(new ActivityEvent("GetAllOrdersStarted"));

        // Add trace context to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none"
        });

        try
        {
            _logger.LogDebug("Retrieving all orders from database");

            var orderEntities = await _dbContext.Orders
                .Include(o => o.Products)
                .AsNoTracking()
                .AsSplitQuery() // Use split query for better performance with multiple includes
                .ToListAsync(cancellationToken);

            var orders = orderEntities.Select(e => e.ToDomainModel()).ToList();

            activity?.AddEvent(new ActivityEvent("GetAllOrdersCompleted", tags: new ActivityTagsCollection
            {
                { "orders.count", orders.Count }
            }));

            _logger.LogDebug("Retrieved {Count} orders from database", orders.Count);

            return orders;
        }
        catch (Exception ex)
        {
            activity?.AddEvent(new ActivityEvent("GetAllOrdersFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
            _logger.LogError(ex, "Failed to retrieve all orders from database");
            throw;
        }
    }

    /// <summary>
    /// Retrieves a specific order by its unique identifier with optimized query.
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

        using var activity = Activity.Current;
        activity?.AddEvent(new ActivityEvent("GetOrderByIdStarted", tags: new ActivityTagsCollection
        {
            { "order.id", orderId }
        }));

        // Add trace context to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none",
            ["OrderId"] = orderId
        });

        try
        {
            _logger.LogDebug("Retrieving order {OrderId} from database", orderId);

            var orderEntity = await _dbContext.Orders
                .Include(o => o.Products)
                .AsNoTracking()
                .AsSplitQuery() // Use split query for better performance
                .FirstOrDefaultAsync(o => o.Id == orderId, cancellationToken);

            var order = orderEntity?.ToDomainModel();

            if (order != null)
            {
                activity?.AddEvent(new ActivityEvent("GetOrderByIdCompleted", tags: new ActivityTagsCollection
                {
                    { "order.found", true }
                }));
                _logger.LogDebug("Order {OrderId} retrieved successfully from database", orderId);
            }
            else
            {
                activity?.AddEvent(new ActivityEvent("GetOrderByIdCompleted", tags: new ActivityTagsCollection
                {
                    { "order.found", false }
                }));
                _logger.LogDebug("Order {OrderId} not found in database", orderId);
            }

            return order;
        }
        catch (Exception ex)
        {
            activity?.AddEvent(new ActivityEvent("GetOrderByIdFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
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

        using var activity = Activity.Current;
        activity?.AddEvent(new ActivityEvent("DeleteOrderStarted", tags: new ActivityTagsCollection
        {
            { "order.id", orderId }
        }));

        // Add trace context to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none",
            ["OrderId"] = orderId
        });

        try
        {
            _logger.LogInformation("Deleting order {OrderId} from database", orderId);

            var orderEntity = await _dbContext.Orders
                .Include(o => o.Products)
                .FirstOrDefaultAsync(o => o.Id == orderId, cancellationToken);

            if (orderEntity == null)
            {
                activity?.AddEvent(new ActivityEvent("DeleteOrderCompleted", tags: new ActivityTagsCollection
                {
                    { "order.found", false },
                    { "order.deleted", false }
                }));
                _logger.LogWarning("Order {OrderId} not found in database for deletion", orderId);
                return false;
            }

            _dbContext.Orders.Remove(orderEntity);
            await _dbContext.SaveChangesAsync(cancellationToken);

            activity?.AddEvent(new ActivityEvent("DeleteOrderCompleted", tags: new ActivityTagsCollection
            {
                { "order.found", true },
                { "order.deleted", true }
            }));
            _logger.LogInformation("Successfully deleted order {OrderId} from database", orderId);
            return true;
        }
        catch (Exception ex)
        {
            activity?.AddEvent(new ActivityEvent("DeleteOrderFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
            _logger.LogError(ex, "Error deleting order {OrderId} from database", orderId);
            throw;
        }
    }
}
