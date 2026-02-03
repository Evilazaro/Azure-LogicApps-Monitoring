---
description: Guide for migrating eShop.Orders.API from file-based storage to Entity Framework Core with Azure SQL Database
author: Evilazaro
version: 1.0
last_updated: 2026-01-28
tags: [ef-core, migration, sql-azure, database]
---

# Entity Framework Core Migration Guide

![EF Core](https://img.shields.io/badge/EF%20Core-9.0-512BD4?logo=dotnet)
![SQL Azure](https://img.shields.io/badge/SQL-Azure-0078D4?logo=microsoftazure)
![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)

> ℹ️ **Note**: This guide documents the migration from file-based storage to Entity Framework Core.
>
> ⏱️ **Estimated time**: 15-30 minutes for new setup

---

## Table of Contents

- [Overview](#overview)
- [Changes Made](#changes-made)
- [Database Configuration](#database-configuration)
- [Database Migration](#database-migration)
- [Database Schema](#database-schema)
- [Authentication Requirements](#authentication-requirements)
- [Local Development](#local-development)
- [Testing the Changes](#testing-the-changes)
- [Rollback Instructions](#rollback-instructions)
- [Benefits of EF Core](#benefits-of-ef-core)
- [Additional Resources](#additional-resources)

---

## 📋 Overview

The eShop.Orders.API project has been refactored to use **Entity Framework Core** with **Azure SQL Database** instead of file-based storage. This migration provides improved scalability, reliability, and data integrity for production workloads.

### Migration Benefits

| Benefit            | Impact                                             |
| :----------------- | :------------------------------------------------- |
| **Scalability**    | SQL Azure Database scales better than file storage |
| **Data Integrity** | ACID transactions with rollback capabilities       |
| **Performance**    | Indexed queries and query optimization             |
| **Security**       | Azure AD authentication and encryption at rest     |
| **Reliability**    | Database-level backup and disaster recovery        |

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 📝 Changes Made

### 1. 📦 NuGet Packages Added

> ℹ️ **Note**: These packages provide EF Core functionality and design-time tooling for SQL Server.

| Package                                   | Version | Purpose                       |
| :---------------------------------------- | :-----: | :---------------------------- |
| `Microsoft.EntityFrameworkCore.SqlServer` |  9.0.0  | SQL Server database provider  |
| `Microsoft.EntityFrameworkCore.Design`    |  9.0.0  | Design-time EF Core tools     |
| `Microsoft.EntityFrameworkCore.Tools`     |  9.0.0  | Package Manager Console tools |

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

#### Program.cs Updates

| Change                    | Description                                |
| :------------------------ | :----------------------------------------- |
| **Removed**               | File-based storage configuration           |
| **Added**                 | `AddDbContext<OrderDbContext>` with SQL    |
| **Configured**            | Retry strategy for transient failures      |
| **Enabled (Development)** | Sensitive data logging and detailed errors |

#### appsettings.json Updates

- ❌ Removed `OrderStorage` section
- ✅ Added `ConnectionStrings:OrdersDatabase` configuration
- ✅ Added EF Core logging configuration

#### appsettings.Development.json Updates

- ✅ Added development connection string
- ✅ Enabled detailed EF Core command logging

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 🗄️ Database Configuration

> 🔒 **Security**: This configuration uses Azure AD authentication for passwordless, secure database access.

### 🔗 Connection String Format

The connection string uses **Azure AD authentication** (passwordless):

```text
Server=tcp:{SQL_SERVER_FQDN},1433;Initial Catalog={DATABASE_NAME};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;
```

### 📋 Configuration Placeholders

> ℹ️ **Note**: Replace these placeholders in `appsettings.json` and `appsettings.Development.json`:

| Placeholder         | Description                            | Example                                |
| :------------------ | :------------------------------------- | :------------------------------------- |
| `{SQL_SERVER_FQDN}` | SQL Server fully qualified domain name | `ordersserver123.database.windows.net` |
| `{DATABASE_NAME}`   | Database name                          | `ordersdb123`                          |

> 💡 **Tip**: Retrieve the SQL Server FQDN from Bicep output: `ORDERSDATABASE_SQLSERVERFQDN`.

### 💡 Example Configuration

> ℹ️ **Note**: Replace the placeholder values with your actual Azure SQL Server details.

```json
{
  "ConnectionStrings": {
    "OrdersDatabase": "Server=tcp:ordersserver123abc.database.windows.net,1433;Initial Catalog=ordersdb123abc;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;"
  }
}
```

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 🔄 Database Migration

> 📋 **Prerequisites**: Ensure the connection string is properly configured in `appsettings.json` before running migrations.

### 1. 🛠️ Install EF Core Tools

> 📋 **Prerequisites**: Install the EF Core CLI tools if not already available.

```powershell
dotnet tool install --global dotnet-ef
```

> ✅ **Success**: Expected output: "Tool 'dotnet-ef' was successfully installed."

### 2. 📝 Create Initial Migration

Navigate to the project directory:

```powershell
cd d:\app\src\eShop.Orders.API
```

Create the initial migration:

```powershell
dotnet ef migrations add InitialCreate
```

> ✅ **Success**: This creates a `Migrations` folder with the migration files.

### 3. 🚀 Update Database Schema

Apply the migration to create the database tables:

```powershell
dotnet ef database update
```

> ✅ **Success**: Expected output: "Done. Applying migration 'InitialCreate'."

### 📄 Alternative: Create Migration Script

> 💡 **Tip**: Use SQL scripts for controlled production deployments.

Generate a SQL script instead of applying directly:

```powershell
dotnet ef migrations script -o migration.sql
```

This creates a `migration.sql` file that can be reviewed and executed by a DBA.

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 📊 Database Schema

### 📋 Tables Created

#### 📦 Orders

| Column              |   Data Type   | Constraints | Description             |
| :------------------ | :-----------: | :---------- | :---------------------- |
| **Id**              | nvarchar(100) | Primary Key | Unique order identifier |
| **CustomerId**      | nvarchar(100) | Indexed     | Customer identifier     |
| **Date**            |   datetime2   | Indexed     | Order date              |
| **DeliveryAddress** | nvarchar(500) | —           | Delivery address        |
| **Total**           | decimal(18,2) | —           | Order total amount      |

#### 📦 OrderProducts

| Column                 |   Data Type   | Constraints          | Description             |
| :--------------------- | :-----------: | :------------------- | :---------------------- |
| **Id**                 | nvarchar(100) | Primary Key          | Unique order product ID |
| **OrderId**            | nvarchar(100) | Foreign Key, Indexed | Foreign key to Orders   |
| **ProductId**          | nvarchar(100) | Indexed              | Product identifier      |
| **ProductDescription** | nvarchar(500) | —                    | Product description     |
| **Quantity**           |      int      | —                    | Quantity ordered        |
| **Price**              | decimal(18,2) | —                    | Unit price              |

### 🔗 Relationships

> ℹ️ **Note**: The database uses a one-to-many relationship pattern with cascade delete enabled.

- **One-to-many** relationship between Orders and OrderProducts
- **Cascade delete** enabled — Deleting an order automatically deletes its associated products

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 🔐 Authentication Requirements

> 🔒 **Security**: The application uses passwordless authentication via Azure Active Directory for enhanced security and compliance.

The application uses **Azure AD authentication** to connect to SQL Azure Database. Ensure:

### Required Configuration

| Requirement                 | Configuration                                             |
| :-------------------------- | :-------------------------------------------------------- |
| **Managed Identity**        | Assigned to the application (Container App)               |
| **Database Permissions**    | Managed Identity granted SQL Database access              |
| **Azure AD Authentication** | Enabled on SQL Server (`azureADOnlyAuthentication: true`) |
| **Entra Admin**             | Managed Identity set as SQL Server admin                  |

> ℹ️ **Note**: The Bicep deployment automatically configures all required authentication settings.

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 💻 Local Development

> 💡 **Tip**: Azure CLI authentication is recommended for development. SQL authentication should only be used for testing purposes.

### Authentication Setup

1. Ensure you're logged in with Azure CLI:

   ```powershell
   az login
   ```

2. Verify your account has permissions on the SQL Database

### Alternative: SQL Authentication (Not Recommended)

> ⚠️ **Warning**: SQL authentication is not recommended for production environments. Use Azure AD authentication for enhanced security.

Update [appsettings.Development.json](./appsettings.Development.json) to use SQL authentication:

```json
{
  "ConnectionStrings": {
    "OrdersDatabase": "Server=tcp:<SERVER>.database.windows.net,1433;Initial Catalog=<DATABASE>;User ID=<USERNAME>;Password=<PASSWORD>;Encrypt=True;"
  }
}
```

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 🧪 Testing the Changes

### 1. 🔨 Build the Project

```powershell
dotnet build
```

> ✅ **Success**: Expected output: "Build succeeded. 0 Warning(s) 0 Error(s)".

### 2. ▶️ Run the Application

```powershell
dotnet run
```

> ✅ **Success**: The application should start and display: "Now listening on: http://localhost:5000".

### 3. 🌐 Test Endpoints

The API endpoints remain unchanged:

| Method     | Endpoint           | Description          | Expected Response   |
| :--------- | :----------------- | :------------------- | :------------------ |
| **POST**   | `/api/orders`      | Create a new order   | HTTP 201 Created    |
| **GET**    | `/api/orders`      | Get all orders       | HTTP 200 OK         |
| **GET**    | `/api/orders/{id}` | Get a specific order | HTTP 200 OK         |
| **DELETE** | `/api/orders/{id}` | Delete an order      | HTTP 204 No Content |

> ✅ **Success**: If the application responds to API requests successfully, the migration is complete.

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## ⏪ Rollback Instructions

> ⚠️ **Warning**: Only use rollback if absolutely necessary. This reverts to the less scalable file-based storage and should be considered a temporary measure.

> 🔧 **Troubleshooting**: Follow these steps in the exact order shown to safely revert to the previous storage implementation.

### Rollback Steps

1. Restore the original [OrderRepository.cs](./Repositories/OrderRepository.cs) from git history:

   ```powershell
   git checkout HEAD~1 -- Repositories/OrderRepository.cs
   ```

2. Restore original [appsettings.json](./appsettings.json) files:

   ```powershell
   git checkout HEAD~1 -- appsettings.json appsettings.Development.json
   ```

3. Restore original [Program.cs](./Program.cs) configuration:

   ```powershell
   git checkout HEAD~1 -- Program.cs
   ```

4. Remove EF Core packages from [eShop.Orders.API.csproj](./eShop.Orders.API.csproj)

5. Delete the `Data` folder:

   ```powershell
   Remove-Item -Recurse -Force Data
   ```

> ℹ️ **Note**: After rollback, rebuild the project with `dotnet build` and verify all endpoints work correctly.

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## ✅ Benefits of EF Core

| Benefit                | Description                                              |
| :--------------------- | :------------------------------------------------------- |
| **Scalability**        | SQL Azure Database scales better than file-based storage |
| **ACID Transactions**  | Full transactional support with rollback capabilities    |
| **Concurrency**        | Built-in optimistic concurrency control                  |
| **Performance**        | Indexed queries and query optimization                   |
| **Reliability**        | Database-level backup and recovery                       |
| **Security**           | Azure AD authentication and encryption at rest           |
| **Query Capabilities** | Rich querying with LINQ                                  |

[↑ Back to Top](#entity-framework-core-migration-guide)

---

## 📚 Additional Resources

| Resource                                | Link                                                                                                       |
| :-------------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| **Entity Framework Core Documentation** | [docs.microsoft.com/ef/core](https://docs.microsoft.com/ef/core/)                                          |
| **SQL Azure Documentation**             | [docs.microsoft.com/azure/azure-sql](https://docs.microsoft.com/azure/azure-sql/)                          |
| **Azure AD Authentication for SQL**     | [Authentication Overview](https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-overview) |

[↑ Back to Top](#entity-framework-core-migration-guide)
