// =============================================================================
// Database Context Health Check
// Monitors SQL Server/Azure SQL Database connectivity
// =============================================================================

using eShop.Orders.API.Data;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Diagnostics;

namespace eShop.Orders.API.HealthChecks;

/// <summary>
/// Health check for Entity Framework Core DbContext connectivity.
/// Uses IServiceScopeFactory to create scoped DbContext instances for thread-safe health checks.
/// </summary>
public sealed class DbContextHealthCheck : IHealthCheck
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<DbContextHealthCheck> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="DbContextHealthCheck"/> class.
    /// </summary>
    /// <param name="scopeFactory">The service scope factory for creating scoped DbContext instances.</param>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <exception cref="ArgumentNullException">Thrown when any parameter is null.</exception>
    public DbContextHealthCheck(IServiceScopeFactory scopeFactory, ILogger<DbContextHealthCheck> logger)
    {
        _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Checks the health of the database connection.
    /// </summary>
    /// <param name="context">The health check context.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The health check result indicating database connectivity status.</returns>
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();

        try
        {
            // Create a new scope to get a fresh DbContext instance
            // This ensures thread-safety and proper connection management
            await using var scope = _scopeFactory.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<OrderDbContext>();

            // Use a reasonable timeout for health checks (5 seconds)
            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeoutCts.CancelAfter(TimeSpan.FromSeconds(5));

            // Try to execute a simple query to verify database connectivity
            var canConnect = await dbContext.Database.CanConnectAsync(timeoutCts.Token);

            stopwatch.Stop();

            if (canConnect)
            {
                return HealthCheckResult.Healthy(
                    $"Database connection is healthy. Response time: {stopwatch.ElapsedMilliseconds}ms",
                    new Dictionary<string, object>
                    {
                        ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds
                    });
            }

            return HealthCheckResult.Unhealthy("Database connection test returned false");
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            stopwatch.Stop();
            _logger.LogWarning("Database health check timed out after {ElapsedMs}ms", stopwatch.ElapsedMilliseconds);

            return HealthCheckResult.Degraded(
                $"Database health check timed out after {stopwatch.ElapsedMilliseconds}ms",
                data: new Dictionary<string, object>
                {
                    ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds,
                    ["TimedOut"] = true
                });
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Database health check failed after {ElapsedMs}ms", stopwatch.ElapsedMilliseconds);

            return new HealthCheckResult(
                context.Registration.FailureStatus,
                description: $"Database connection failed: {ex.Message}",
                exception: ex,
                data: new Dictionary<string, object>
                {
                    ["ResponseTimeMs"] = stopwatch.ElapsedMilliseconds,
                    ["ErrorType"] = ex.GetType().Name
                });
        }
    }
}