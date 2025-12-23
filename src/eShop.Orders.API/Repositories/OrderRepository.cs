using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;
using Microsoft.Extensions.Options;
using System.Text.Json;

namespace eShop.Orders.API.Repositories;

public sealed class OrderRepository : IOrderRepository, IDisposable
{
    private readonly ILogger<OrderRepository> _logger;
    private readonly IWebHostEnvironment _environment;
    private readonly OrderStorageOptions _options;
    private readonly SemaphoreSlim _fileLock = new(1, 1);
    private bool _disposed;

    public OrderRepository(
        ILogger<OrderRepository> logger,
        IWebHostEnvironment environment,
        IOptions<OrderStorageOptions> options)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _environment = environment ?? throw new ArgumentNullException(nameof(environment));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
    }

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

    public async Task<IEnumerable<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default)
    {
        var filePath = GetFilePath();
        return await GetAllOrdersInternalAsync(filePath, cancellationToken).ConfigureAwait(false);
    }

    public async Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
        }

        var orders = await GetAllOrdersAsync(cancellationToken).ConfigureAwait(false);
        return orders.FirstOrDefault(o => o.Id == orderId);
    }

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

public sealed class OrderStorageOptions
{
    public const string SectionName = "OrderStorage";

    public required string StorageDirectory { get; init; } = "Files";
    public required string FileName { get; init; } = "orders.json";
}