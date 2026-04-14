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
/// <remarks>
/// <para>
/// This repository provides a comprehensive data access layer for managing orders using Entity Framework Core.
/// It implements the <see cref="IOrderRepository"/> interface and supports CRUD operations with optimized
/// query patterns including pagination, split queries, and no-tracking for read-only operations.
/// </para>
/// <para>
/// Key features include:
/// <list type="bullet">
///   <item><description>Asynchronous operations with cancellation token support</description></item>
///   <item><description>Internal timeout handling to prevent HTTP cancellation from interrupting database transactions</description></item>
///   <item><description>Distributed tracing integration via <see cref="Activity"/> for observability</description></item>
///   <item><description>Structured logging with trace context correlation</description></item>
///   <item><description>Optimized queries using split queries and no-tracking for performance</description></item>
///   <item><description>Pagination support for handling large datasets efficiently</description></item>
///   <item><description>Duplicate key violation detection and meaningful error handling</description></item>
/// </list>
/// </para>
/// </remarks>
/// <example>
/// <code>
/// // Register in DI container
/// services.AddScoped&lt;IOrderRepository, OrderRepository&gt;();
/// 
/// // Usage in a service
/// public class OrderService
/// {
///     private readonly IOrderRepository _repository;
///     
///     public async Task&lt;Order?&gt; GetOrderAsync(string id, CancellationToken ct)
///     {
///         return await _repository.GetOrderByIdAsync(id, ct);
///     }
/// }
/// </code>
/// </example>
/// <seealso cref="IOrderRepository"/>
/// <seealso cref="OrderDbContext"/>
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
    /// Uses an internal timeout to prevent HTTP request cancellation from interrupting database transactions.
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

        // Use internal timeout to prevent HTTP cancellation from interrupting database commits
        // This ensures data consistency even if the HTTP request is cancelled
        using var dbCts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        var dbToken = dbCts.Token;

        try
        {
            _logger.LogDebug("Saving order {OrderId} to database", order.Id);

            // Convert domain model to entity
            var orderEntity = order.ToEntity();

            // Add new order - EF Core will handle duplicate detection via exception
            await _dbContext.Orders.AddAsync(orderEntity, dbToken);
            await _dbContext.SaveChangesAsync(dbToken);

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
    /// WARNING: This method loads all orders into memory. For large datasets, use GetOrdersPagedAsync instead.
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
    /// Retrieves orders with pagination support for efficient handling of large datasets.
    /// </summary>
    /// <param name="pageNumber">The 1-based page number to retrieve.</param>
    /// <param name="pageSize">The number of orders per page (max 100).</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A tuple containing the orders for the page and the total count of all orders.</returns>
    public async Task<(IEnumerable<Order> Orders, int TotalCount)> GetOrdersPagedAsync(
        int pageNumber = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        // Validate and normalize pagination parameters
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);

        using var activity = Activity.Current;
        activity?.AddEvent(new ActivityEvent("GetOrdersPagedStarted", tags: new ActivityTagsCollection
        {
            { "page.number", pageNumber },
            { "page.size", pageSize }
        }));

        // Add trace context to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none",
            ["PageNumber"] = pageNumber,
            ["PageSize"] = pageSize
        });

        try
        {
            _logger.LogDebug("Retrieving orders page {PageNumber} with size {PageSize} from database", pageNumber, pageSize);

            // Get total count for pagination metadata
            var totalCount = await _dbContext.Orders
                .AsNoTracking()
                .CountAsync(cancellationToken);

            // Get paginated orders
            var orderEntities = await _dbContext.Orders
                .Include(o => o.Products)
                .AsNoTracking()
                .AsSplitQuery()
                .OrderByDescending(o => o.Date)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            var orders = orderEntities.Select(e => e.ToDomainModel()).ToList();

            activity?.AddEvent(new ActivityEvent("GetOrdersPagedCompleted", tags: new ActivityTagsCollection
            {
                { "orders.count", orders.Count },
                { "total.count", totalCount }
            }));

            _logger.LogDebug("Retrieved {Count} orders (page {PageNumber}, total {TotalCount}) from database",
                orders.Count, pageNumber, totalCount);

            return (orders, totalCount);
        }
        catch (Exception ex)
        {
            activity?.AddEvent(new ActivityEvent("GetOrdersPagedFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
            _logger.LogError(ex, "Failed to retrieve paginated orders from database (page {PageNumber}, size {PageSize})",
                pageNumber, pageSize);
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

        // Use internal timeout to prevent HTTP cancellation from interrupting database queries
        using var dbCts = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var dbToken = dbCts.Token;

        try
        {
            _logger.LogDebug("Retrieving order {OrderId} from database", orderId);

            var orderEntity = await _dbContext.Orders
                .Include(o => o.Products)
                .AsNoTracking()
                .AsSplitQuery() // Use split query for better performance
                .FirstOrDefaultAsync(o => o.Id == orderId, dbToken);

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
    /// Uses an internal timeout to prevent HTTP request cancellation from interrupting database transactions.
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

        // Use internal timeout to prevent HTTP cancellation from interrupting database commits
        // This ensures data consistency even if the HTTP request is cancelled
        using var dbCts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        var dbToken = dbCts.Token;

        try
        {
            _logger.LogInformation("Deleting order {OrderId} from database", orderId);

            var orderEntity = await _dbContext.Orders
                .Include(o => o.Products)
                .FirstOrDefaultAsync(o => o.Id == orderId, dbToken);

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
            await _dbContext.SaveChangesAsync(dbToken);

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

    /// <summary>
    /// Checks if an order exists in the database by its unique identifier.
    /// This is an optimized operation that performs a simple existence check without loading the entity.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>True if the order exists; otherwise, false.</returns>
    /// <exception cref="ArgumentException">Thrown when orderId is null or empty.</exception>
    public async Task<bool> OrderExistsAsync(string orderId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
        }

        using var activity = Activity.Current;
        activity?.AddEvent(new ActivityEvent("OrderExistsCheckStarted", tags: new ActivityTagsCollection
        {
            { "order.id", orderId }
        }));

        try
        {
            // Use AnyAsync for efficient existence check - single query, no entity materialization
            var exists = await _dbContext.Orders
                .AsNoTracking()
                .AnyAsync(o => o.Id == orderId, cancellationToken);

            activity?.AddEvent(new ActivityEvent("OrderExistsCheckCompleted", tags: new ActivityTagsCollection
            {
                { "order.exists", exists }
            }));

            _logger.LogDebug("Order existence check for {OrderId}: {Exists}", orderId, exists);
            return exists;
        }
        catch (Exception ex)
        {
            activity?.AddEvent(new ActivityEvent("OrderExistsCheckFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Failed to check existence of order {OrderId}", orderId);
            throw;
        }
    }

    /// <summary>
    /// Checks the existence of multiple orders by their unique identifiers.
    /// Returns a set of order IDs that exist in the database.
    /// </summary>
    /// <param name="orderIds">The collection of unique identifiers of the orders.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A set of existing order IDs.</returns>
    /// <exception cref="ArgumentNullException">Thrown when orderIds is null.</exception>
    public async Task<HashSet<string>> GetExistingOrderIdsAsync(IEnumerable<string> orderIds, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(orderIds);

        using var activity = Activity.Current;
        activity?.AddEvent(new ActivityEvent("GetExistingOrderIdsStarted", tags: new ActivityTagsCollection
        {
            { "orderIds.count", orderIds.Count() }
        }));

        // Add trace context to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none"
        });

        try
        {
            _logger.LogDebug("Checking existence of {Count} orders in database", orderIds.Count());

            var orderIdList = orderIds.ToList();

            // Use a batched query instead of N individual queries
            var existingIds = await _dbContext.Orders
                .Where(o => orderIdList.Contains(o.Id))
                .Select(o => o.Id)
                .ToListAsync(cancellationToken);

            var existingIdSet = new HashSet<string>(existingIds);

            activity?.AddEvent(new ActivityEvent("GetExistingOrderIdsCompleted", tags: new ActivityTagsCollection
            {
                { "existingOrderIds.count", existingIdSet.Count }
            }));

            _logger.LogDebug("Checked existence of {Count} orders, found {FoundCount} existing", orderIds.Count(), existingIdSet.Count);

            return existingIdSet;
        }
        catch (Exception ex)
        {
            activity?.AddEvent(new ActivityEvent("GetExistingOrderIdsFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Failed to check existence of orders batch");
            throw;
        }
    }
}
