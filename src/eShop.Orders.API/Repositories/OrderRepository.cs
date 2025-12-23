using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;
using Microsoft.Extensions.Options;
using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace eShop.Orders.API.Repositories;

/// <summary>
/// Provides file-based persistence for order data with thread-safe operations.
/// Implements the repository pattern for order management.
/// </summary>
public sealed class OrderRepository : IOrderRepository, IDisposable
{
    private readonly ILogger<OrderRepository> _logger;
    private readonly IWebHostEnvironment _environment;
    private readonly OrderStorageOptions _options;
    private readonly SemaphoreSlim _fileLock = new(1, 1);
    private bool _disposed;

    /// <summary>
    /// Initializes a new instance of the <see cref="OrderRepository"/> class.
    /// </summary>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <param name="environment">The web host environment for path resolution.</param>
    /// <param name="options">The configured storage options.</param>
    /// <exception cref="ArgumentNullException">Thrown when any parameter is null.</exception>
    public OrderRepository(
        ILogger<OrderRepository> logger,
        IWebHostEnvironment environment,
        IOptions<OrderStorageOptions> options)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _environment = environment ?? throw new ArgumentNullException(nameof(environment));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
    }

    /// <summary>
    /// Saves an order to the file-based storage asynchronously.
    /// Creates or updates the order if it already exists.
    /// </summary>
    /// <param name="order">The order to save.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    /// <exception cref="ArgumentNullException">Thrown when order is null.</exception>
    public async Task SaveOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        var filePath = GetFilePath();
        await _fileLock.WaitAsync(cancellationToken).ConfigureAwait(false);

        try
        {
            var orders = await GetAllOrdersInternalAsync(filePath, cancellationToken).ConfigureAwait(false);
            var ordersList = orders.ToList();

            // Add or update order
            var existingIndex = ordersList.FindIndex(o => o.Id == order.Id);
            if (existingIndex >= 0)
            {
                ordersList[existingIndex] = order;
            }
            else
            {
                ordersList.Add(order);
            }

            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                WriteIndented = true
            };

            var ordersJson = JsonSerializer.Serialize(ordersList, options);
            await File.WriteAllTextAsync(filePath, ordersJson, cancellationToken).ConfigureAwait(false);

            _logger.LogDebug("Order {OrderId} saved to file successfully", order.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save order {OrderId} to file {FilePath}", order.Id, filePath);
            throw;
        }
        finally
        {
            _fileLock.Release();
        }
    }

    /// <summary>
    /// Retrieves all orders from the file-based storage asynchronously.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of all orders.</returns>
    public async Task<IEnumerable<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default)
    {
        var filePath = GetFilePath();
        return await GetAllOrdersInternalAsync(filePath, cancellationToken).ConfigureAwait(false);
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

        var orders = await GetAllOrdersAsync(cancellationToken).ConfigureAwait(false);
        return orders.FirstOrDefault(o => o.Id == orderId);
    }

    /// <summary>
    /// Deletes an order from the file-based storage by its unique identifier.
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
            _logger.LogInformation("Deleting order {OrderId} from repository", orderId);

            var orders = await GetAllOrdersAsync(cancellationToken).ConfigureAwait(false);
            var ordersList = orders.ToList();
            var orderToDelete = ordersList.FirstOrDefault(o => o.Id.Equals(orderId, StringComparison.OrdinalIgnoreCase));

            if (orderToDelete == null)
            {
                _logger.LogWarning("Order {OrderId} not found in repository for deletion", orderId);
                return false;
            }

            ordersList.Remove(orderToDelete);

            // Save updated list
            await SaveOrdersListAsync(ordersList, cancellationToken).ConfigureAwait(false);

            _logger.LogInformation("Successfully deleted order {OrderId} from repository", orderId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting order {OrderId} from repository", orderId);
            throw;
        }
    }

    /// <summary>
    /// Saves the list of orders to the file system asynchronously.
    /// </summary>
    /// <param name="orders">The list of orders to save.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    private async Task SaveOrdersListAsync(List<Order> orders, CancellationToken cancellationToken)
    {
        var filePath = GetFilePath();
        await _fileLock.WaitAsync(cancellationToken).ConfigureAwait(false);

        try
        {
            await using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write, FileShare.None, 4096, true);
            await JsonSerializer.SerializeAsync(fileStream, orders, cancellationToken: cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _fileLock.Release();
        }
    }

    /// <summary>
    /// Retrieves all orders from the file system asynchronously.
    /// </summary>
    /// <param name="filePath">The path to the orders file.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A list of all orders.</returns>
    private async Task<List<Order>> GetAllOrdersInternalAsync(string filePath, CancellationToken cancellationToken)
    {
        if (!File.Exists(filePath))
        {
            _logger.LogWarning("Orders file not found at {FilePath}", filePath);
            return new List<Order>();
        }

        try
        {
            var ordersJson = await File.ReadAllTextAsync(filePath, cancellationToken).ConfigureAwait(false);

            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };

            return JsonSerializer.Deserialize<List<Order>>(ordersJson, options) ?? new List<Order>();
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to deserialize orders from file {FilePath}", filePath);
            throw;
        }
    }

    /// <summary>
    /// Gets the full file path for the orders storage file.
    /// </summary>
    /// <returns>The full file path.</returns>
    /// <exception cref="ObjectDisposedException">Thrown if the repository has been disposed.</exception>
    private string GetFilePath()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        var directory = Path.Combine(_environment.ContentRootPath, _options.StorageDirectory);

        if (!Directory.Exists(directory))
        {
            Directory.CreateDirectory(directory);
            _logger.LogInformation("Created storage directory at {Directory}", directory);
        }

        return Path.Combine(directory, _options.FileName);
    }

    /// <summary>
    /// Disposes the resources used by the repository.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _fileLock?.Dispose();
        _disposed = true;
    }
}

/// <summary>
/// Configuration options for order file-based storage.
/// </summary>
public sealed class OrderStorageOptions
{
    /// <summary>
    /// Gets the configuration section name for order storage options.
    /// </summary>
    public const string SectionName = "OrderStorage";

    /// <summary>
    /// Gets or initializes the directory path for storing order files.
    /// </summary>
    [Required(AllowEmptyStrings = false, ErrorMessage = "Storage directory path is required")]
    public required string StorageDirectory { get; init; } = "Files";

    /// <summary>
    /// Gets or initializes the filename for the orders JSON file.
    /// </summary>
    [Required(AllowEmptyStrings = false, ErrorMessage = "Storage filename is required")]
    public required string FileName { get; init; } = "orders.json";
}