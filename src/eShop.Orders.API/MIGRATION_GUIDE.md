---
title: Entity Framework Core Migration Guide
description: Guide for migrating eShop.Orders.API from file-based storage to Entity Framework Core with Azure SQL Database
author: Evilazaro
version: 1.0
tags: [ef-core, migration, sql-azure, database]
---

# 🔄 Entity Framework Core Migration Guide

![EF Core](https://img.shields.io/badge/EF%20Core-9.0-512BD4?logo=dotnet)
![SQL Azure](https://img.shields.io/badge/SQL-Azure-0078D4?logo=microsoftazure)
![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)

> [!NOTE]
> 🎯 **For Developers**: This guide documents the migration from file-based storage to Entity Framework Core.
> ⏱️ **Estimated time:** 15-30 minutes for new setup

---

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [📝 Changes Made](#-changes-made)
- [🗄️ Database Configuration](#️-database-configuration)
- [🔄 Database Migration](#-database-migration)
- [📊 Database Schema](#-database-schema)
- [🔐 Authentication Requirements](#-authentication-requirements)
- [💻 Local Development](#-local-development)
- [🧪 Testing the Changes](#-testing-the-changes)
- [⏪ Rollback Instructions](#-rollback-instructions)
- [✅ Benefits of EF Core](#-benefits-of-ef-core)
- [📚 Additional Resources](#-additional-resources-1)

---

## 📋 Overview

The eShop.Orders.API project has been refactored to use **Entity Framework Core** with **SQL Azure Database** instead of file-based storage.

---

## 📝 Changes Made

### 1. 📦 NuGet Packages Added

- `Microsoft.EntityFrameworkCore.SqlServer` (v9.0.0)
- `Microsoft.EntityFrameworkCore.Design` (v9.0.0)
- `Microsoft.EntityFrameworkCore.Tools` (v9.0.0)

### 2. 📁 New Files Created

#### 💾 Data Layer

- **`Data/OrderDbContext.cs`**: EF Core DbContext for order management
- **`Data/Entities/OrderEntity.cs`**: Entity model for Orders table
- **`Data/Entities/OrderProductEntity.cs`**: Entity model for OrderProducts table
- **`Data/OrderMapper.cs`**: Extension methods to convert between domain models and entities

#### 🗃️ Repository

- **`Repositories/OrderRepository.cs`**: Refactored to use EF Core instead of file-based storage

---

### 3. ⚙️ Configuration Changes

#### Program.cs

- Removed file-based storage configuration (`OrderStorageOptions`)
- Added `AddDbContext<OrderDbContext>` with SQL Server provider
- Configured retry strategy for transient failures
- Enabled sensitive data logging and detailed errors in development

#### appsettings.json

- Removed `OrderStorage` section
- Added `ConnectionStrings:OrdersDatabase` configuration
- Added EF Core logging configuration

#### appsettings.Development.json

- Added connection string for development environment
- Enabled detailed EF Core command logging

---

## 🗄️ Database Configuration

### 🔗 Connection String Format

The connection string uses **Azure AD authentication** (passwordless):

```text
Server=tcp:{SQL_SERVER_FQDN},1433;Initial Catalog={DATABASE_NAME};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;
```

### 📋 Configuration Placeholders

Replace the following placeholders in `appsettings.json` and `appsettings.Development.json`:

- `{SQL_SERVER_FQDN}`: Your SQL Server's fully qualified domain name (from Bicep output: `ORDERSDATABASE_SQLSERVERFQDN`)
- `{DATABASE_NAME}`: Your database name (e.g., `ordersdb`)

### 💡 Example Configuration

```json
{
  "ConnectionStrings": {
    "OrdersDatabase": "Server=tcp:ordersserver123abc.database.windows.net,1433;Initial Catalog=ordersdb123abc;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;"
  }
}
```

---

## 🔄 Database Migration

### 1. 🛠️ Install EF Core Tools (if not already installed)

```powershell
dotnet tool install --global dotnet-ef
```

### 2. 📝 Create Initial Migration

Navigate to the project directory:

```powershell
cd d:\app\src\eShop.Orders.API
```

Create the initial migration:

```powershell
dotnet ef migrations add InitialCreate
```

This will create a `Migrations` folder with the migration files.

### 3. 🚀 Update Database Schema

Apply the migration to create the database tables:

```powershell
dotnet ef database update
```

### 📄 Alternative: Create Migration Script

To generate a SQL script instead of applying directly:

```powershell
dotnet ef migrations script -o migration.sql
```

---

## 📊 Database Schema

### 📋 Tables Created

#### 📦 Orders

- **Id** (nvarchar(100), PK): Unique order identifier
- **CustomerId** (nvarchar(100), indexed): Customer identifier
- **Date** (datetime2, indexed): Order date
- **DeliveryAddress** (nvarchar(500)): Delivery address
- **Total** (decimal(18,2)): Order total amount

#### 📦 OrderProducts

- **Id** (nvarchar(100), PK): Unique order product identifier
- **OrderId** (nvarchar(100), FK, indexed): Foreign key to Orders
- **ProductId** (nvarchar(100), indexed): Product identifier
- **ProductDescription** (nvarchar(500)): Product description
- **Quantity** (int): Quantity ordered
- **Price** (decimal(18,2)): Unit price

### 🔗 Relationships

- One-to-many relationship between Orders and OrderProducts
- Cascade delete enabled (deleting an order deletes its products)

---

## 🔐 Authentication Requirements

The application uses **Azure AD authentication** to connect to SQL Azure Database. Ensure:

1. **Managed Identity** is assigned to the application (Container App or App Service)
2. **Managed Identity** has been granted permissions on the SQL Database:
   - The Bicep deployment already configures this with `azureADOnlyAuthentication: true`
   - The managed identity is set as the Entra admin for the SQL Server

---

## 💻 Local Development

For local development with Azure AD authentication:

1. Ensure you're logged in with Azure CLI:

   ```powershell
   az login
   ```

2. Your account must have permissions on the SQL Database

3. Alternatively, update `appsettings.Development.json` to use a connection string with SQL authentication (not recommended for production)

---

## 🧪 Testing the Changes

### 1. 🔨 Build the Project

```powershell
dotnet build
```

### 2. ▶️ Run the Application

```powershell
dotnet run
```

### 3. 🌐 Test Endpoints

The API endpoints remain unchanged:

- `POST /api/orders` - Create a new order
- `GET /api/orders` - Get all orders
- `GET /api/orders/{id}` - Get a specific order
- `DELETE /api/orders/{id}` - Delete an order

---

## ⏪ Rollback Instructions

> [!WARNING]
> Only use rollback if absolutely necessary. This will revert to the less scalable file-based storage.

If you need to rollback to file-based storage:

1. Restore the original `OrderRepository.cs` from git history
2. Restore original `appsettings.json` files
3. Restore original `Program.cs` configuration
4. Remove EF Core packages from `eShop.Orders.API.csproj`
5. Delete the `Data` folder

---

## ✅ Benefits of EF Core

| Benefit                | Description                                              |
| ---------------------- | -------------------------------------------------------- |
| **Scalability**        | SQL Azure Database scales better than file-based storage |
| **ACID Transactions**  | Full transactional support with rollback capabilities    |
| **Concurrency**        | Built-in optimistic concurrency control                  |
| **Performance**        | Indexed queries and query optimization                   |
| **Reliability**        | Database-level backup and recovery                       |
| **Security**           | Azure AD authentication and encryption at rest           |
| **Query Capabilities** | Rich querying with LINQ                                  |

---

## 📚 Additional Resources than file-based storage

| Resource                            | Link                                                                                                       |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Entity Framework Core Documentation | [docs.microsoft.com/ef/core](https://docs.microsoft.com/ef/core/)                                          |
| SQL Azure Documentation             | [docs.microsoft.com/azure/azure-sql](https://docs.microsoft.com/azure/azure-sql/)                          |
| Azure AD Authentication for SQL     | [Authentication Overview](https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-overview) |

---

<div align="center">

**[⬆ Back to Top](#-entity-framework-core-migration-guide)**

</div>
