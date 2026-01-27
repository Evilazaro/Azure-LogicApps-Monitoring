// =============================================================================
// Order Database Context
// Entity Framework Core DbContext for order management
// =============================================================================

using eShop.Orders.API.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace eShop.Orders.API.Data;

/// <summary>
/// Database context for order management system using Entity Framework Core.
/// Provides access to orders and order products with configured relationships.
/// </summary>
/// <remarks>
/// <para>
/// This context manages two main entities:
/// <list type="bullet">
///   <item><description><see cref="OrderEntity"/> - Represents customer orders with delivery information and totals.</description></item>
///   <item><description><see cref="OrderProductEntity"/> - Represents individual products within an order.</description></item>
/// </list>
/// </para>
/// <para>
/// The context configures cascade delete behavior for order-product relationships,
/// ensuring that when an order is deleted, all associated products are also removed.
/// </para>
/// </remarks>
/// <param name="options">The options to be used by the DbContext, typically configured via dependency injection.</param>
public sealed class OrderDbContext(DbContextOptions<OrderDbContext> options) : DbContext(options)
{

    /// <summary>
    /// Gets or sets the DbSet for Order entities.
    /// </summary>
    public DbSet<OrderEntity> Orders => Set<OrderEntity>();

    /// <summary>
    /// Gets or sets the DbSet for OrderProduct entities.
    /// </summary>
    public DbSet<OrderProductEntity> OrderProducts => Set<OrderProductEntity>();

    /// <summary>
    /// Configures the entity models and their relationships using Fluent API.
    /// </summary>
    /// <param name="modelBuilder">The builder being used to construct the model for this context.</param>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure Order entity
        modelBuilder.Entity<OrderEntity>(entity =>
        {
            // Table configuration
            entity.ToTable("Orders");

            // Primary key
            entity.HasKey(e => e.Id);

            // Properties
            entity.Property(e => e.Id)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(e => e.CustomerId)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(e => e.Date)
                .IsRequired();

            entity.Property(e => e.DeliveryAddress)
                .HasMaxLength(500)
                .IsRequired();

            entity.Property(e => e.Total)
                .HasPrecision(18, 2)
                .IsRequired();

            // Relationships
            entity.HasMany(e => e.Products)
                .WithOne(p => p.Order)
                .HasForeignKey(p => p.OrderId)
                .OnDelete(DeleteBehavior.Cascade);

            // Indexes
            entity.HasIndex(e => e.CustomerId);
            entity.HasIndex(e => e.Date);
        });

        // Configure OrderProduct entity
        modelBuilder.Entity<OrderProductEntity>(entity =>
        {
            // Table configuration
            entity.ToTable("OrderProducts");

            // Primary key
            entity.HasKey(e => e.Id);

            // Properties
            entity.Property(e => e.Id)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(e => e.OrderId)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(e => e.ProductId)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(e => e.ProductDescription)
                .HasMaxLength(500)
                .IsRequired();

            entity.Property(e => e.Quantity)
                .IsRequired();

            entity.Property(e => e.Price)
                .HasPrecision(18, 2)
                .IsRequired();

            // Indexes
            entity.HasIndex(e => e.OrderId);
            entity.HasIndex(e => e.ProductId);
        });
    }
}
