---
title: Generate Orders Script
description: PowerShell and Bash scripts for generating sample e-commerce order data for testing Azure Logic Apps
author: Evilazaro
version: 2.0.1
tags: [hooks, testing, data-generation, orders, powershell, bash]
---

# 📦 Generate-Orders (.ps1 / .sh)

> [!NOTE]
> 🎯 **For Developers & Testers**: Generate sample e-commerce order data for Azure Logic Apps workflow testing.
> ⏱️ **Execution time:** ~2-5 seconds (2000 orders)

![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)
![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)
![Cross-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)
![Version](https://img.shields.io/badge/version-2.0.1-green.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

<details>
<summary>📍 <strong>Quick Navigation</strong></summary>

| Previous                                                 |         Index         |                                    Next |
| :------------------------------------------------------- | :-------------------: | --------------------------------------: |
| [← SQL Managed Identity](sql-managed-identity-config.md) | [📑 Index](README.md) | [Deploy Workflow →](deploy-workflow.md) |

</details>

---

## 📋 Overview

The `Generate-Orders` script is a utility tool in the Developer Inner Loop Workflow that generates sample e-commerce order data for testing Azure Logic Apps monitoring workflows. Available in both PowerShell (`.ps1`) and Bash (`.sh`) versions, it provides cross-platform support for creating realistic test datasets with random products, customers, and delivery addresses.

This script generates orders with unique GUID-based identifiers, random date timestamps within a configurable range (2024-2025), and realistic product selections with price variations. Each order contains customer information, a delivery address from a global address pool, and multiple line items with calculated totals. The output is saved as a JSON file ready for consumption by Azure Logic Apps workflows.

By supporting multiple execution modes (interactive, force, preview, verbose), the script accommodates various workflows from manual development testing to automated CI/CD pipelines. Typical operations generate 2000 orders in seconds with comprehensive progress tracking and detailed logging capabilities.

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [🎯 Purpose](#-purpose)
- [📦 Data Structure](#-data-structure)
  - [📋 Order Schema](#order-schema)
  - [🛒 Product Catalog](#product-catalog)
  - [📍 Address Pool](#address-pool)
- [🚀 Usage](#-usage)
  - [💻 Basic Usage](#basic-usage)
  - [⚡ Custom Order Count](#custom-order-count)
  - [📁 Custom Output Path](#custom-output-path)
  - [🛍️ Product Count Configuration](#product-count-configuration)
  - [⚡ Force Mode (No Confirmation)](#force-mode-no-confirmation)
  - [👁️ Preview Mode (WhatIf/Dry-Run)](#preview-mode-whatifdry-run)
  - [📝 Verbose Mode](#verbose-mode)
- [🔧 Parameters](#-parameters)
- [📚 Examples](#-examples)
  - [🔄 Example 1: Generate Test Data for Development](#example-1-generate-test-data-for-development)
  - [🔁 Example 2: CI/CD Pipeline Integration](#example-2-cicd-pipeline-integration)
  - [📊 Example 3: Load Testing Data Generation](#example-3-load-testing-data-generation)
- [🛠️ How It Works](#%EF%B8%8F-how-it-works)
  - [🔄 Internal Process Flow](#internal-process-flow)
  - [🔗 Integration Points](#integration-points)
- [📖 Related Documentation](#-related-documentation)
- [🔐 Security Considerations](#-security-considerations)
- [🎓 Best Practices](#-best-practices)
- [📊 Performance](#-performance)
- [📜 Version History](#-version-history)

## 🎯 Purpose

This script helps developers and operators:

- 📊 **Generate Test Data**: Create realistic e-commerce order data for testing
- 🔄 **Simulate Load**: Generate configurable volumes of orders for load testing
- 🎲 **Randomization**: Produce unique orders with varied products, quantities, and prices
- 📁 **JSON Export**: Output data in JSON format compatible with Azure Logic Apps
- ✅ **Validation**: Ensure data consistency with parameter validation
- 🔗 **Workflow Integration**: Support integration with deployment and testing pipelines

## 📦 Data Structure

### Order Schema

Each generated order follows this structure:

```json
{
  "id": "ORD-A1B2C3D4E5F6",
  "customerId": "CUST-12345678",
  "date": "2024-06-15T14:23:45Z",
  "deliveryAddress": "350 Fifth Ave, New York, NY, USA",
  "total": 245.97,
  "products": [
    {
      "id": "OP-ABCDEF123456",
      "orderId": "ORD-A1B2C3D4E5F6",
      "productId": "PROD-1001",
      "productDescription": "Wireless Mouse",
      "quantity": 2,
      "price": 24.99
    }
  ]
}
```

| Field             | Type    | Description                                |
| ----------------- | ------- | ------------------------------------------ |
| `id`              | string  | Unique order ID (ORD-{12 hex chars})       |
| `customerId`      | string  | Unique customer ID (CUST-{8 hex chars})    |
| `date`            | string  | ISO 8601 timestamp (2024-2025 range)       |
| `deliveryAddress` | string  | Shipping address from global pool          |
| `total`           | decimal | Calculated order total (rounded to cents)  |
| `products`        | array   | Array of line items (1-6 products default) |

### Product Catalog

The script includes 20 predefined products spanning electronics, office equipment, and accessories:

| Category         | Products                                                         | Price Range      |
| ---------------- | ---------------------------------------------------------------- | ---------------- |
| **Input**        | Wireless Mouse, Mechanical Keyboard                              | $25.99 - $89.99  |
| **Connectivity** | USB-C Hub, Portable Charger                                      | $34.99 - $49.99  |
| **Audio**        | Noise Cancelling Headphones, Bluetooth Speaker, Wireless Earbuds | $79.99 - $149.99 |
| **Storage**      | External SSD 1TB                                                 | $119.99          |
| **Video**        | Webcam 1080p, Ring Light                                         | $44.99 - $69.99  |
| **Displays**     | Monitor 27" 4K, Monitor Arm                                      | $89.99 - $399.99 |
| **Furniture**    | Ergonomic Chair, Standing Desk, Laptop Stand                     | $39.99 - $499.99 |
| **Creative**     | Graphics Tablet, Drawing Pen Set, USB Microphone                 | $29.99 - $199.99 |
| **Accessories**  | Cable Organizer, Smartphone Holder                               | $12.99 - $19.99  |

**Price Variation**: Each order applies ±20% variation to base prices to simulate real-world pricing fluctuations.

### Address Pool

Orders are randomly assigned addresses from 20 global locations:

- **North America**: New York, San Francisco, Mountain View, Cupertino, Redmond, Seattle, Toronto
- **Europe**: London (2), Paris, Berlin (2), Barcelona, Milan
- **Asia-Pacific**: Tokyo, Shanghai, Seoul, Sydney, Melbourne
- **South America**: São Paulo

## 🚀 Usage

### Basic Usage

**PowerShell (Windows):**

```powershell
# Generate 2000 orders using default settings
.\Generate-Orders.ps1
```

**Bash (Linux/macOS):**

```bash
# Generate 2000 orders using default settings
./Generate-Orders.sh
```

**Output:**

```
Generating orders: 2000/2000 (100%)
✓ Successfully generated 2000 orders
  Output file: Z:\Azure-LogicApps-Monitoring\infra\data\ordersBatch.json
  File size: 2456.78 KB
  Products per order: 1-6
```

### Custom Order Count

**PowerShell (Windows):**

```powershell
# Generate 100 orders
.\Generate-Orders.ps1 -OrderCount 100
```

**Bash (Linux/macOS):**

```bash
# Generate 100 orders
./Generate-Orders.sh --count 100
```

### Custom Output Path

**PowerShell (Windows):**

```powershell
# Save to custom location
.\Generate-Orders.ps1 -OutputPath "C:\temp\test-orders.json"
```

**Bash (Linux/macOS):**

```bash
# Save to custom location
./Generate-Orders.sh --output "/tmp/test-orders.json"
```

### Product Count Configuration

**PowerShell (Windows):**

```powershell
# Generate orders with 2-4 products each
.\Generate-Orders.ps1 -MinProducts 2 -MaxProducts 4
```

**Bash (Linux/macOS):**

```bash
# Generate orders with 2-4 products each
./Generate-Orders.sh --min-products 2 --max-products 4
```

### Force Mode (No Confirmation)

**PowerShell (Windows):**

```powershell
# Skip all confirmation prompts
.\Generate-Orders.ps1 -Force
```

**Bash (Linux/macOS):**

```bash
# Skip all confirmation prompts
./Generate-Orders.sh --force
```

### Preview Mode (WhatIf/Dry-Run)

**PowerShell (Windows):**

```powershell
# Show what would be generated without making changes
.\Generate-Orders.ps1 -WhatIf
```

**Bash (Linux/macOS):**

```bash
# Show what would be generated without making changes
./Generate-Orders.sh --dry-run
```

**Output:**

```
What if: Would generate 2000 orders
What if: Would save to ../infra/data/ordersBatch.json
What if: Products per order: 1-6

No changes were made. This was a simulation.
```

### Verbose Mode

**PowerShell (Windows):**

```powershell
# Get detailed execution information
.\Generate-Orders.ps1 -Verbose
```

**Bash (Linux/macOS):**

```bash
# Get detailed execution information
./Generate-Orders.sh --verbose
```

## 🔧 Parameters

### `-OrderCount` (PowerShell) / `--count` (Bash)

Number of orders to generate.

**Type:** `Integer`  
**Required:** No  
**Default:** `2000`  
**Valid Range:** `1-10000`

**PowerShell Example:**

```powershell
.\Generate-Orders.ps1 -OrderCount 500
```

**Bash Example:**

```bash
./Generate-Orders.sh --count 500
```

---

### `-OutputPath` (PowerShell) / `--output` (Bash)

File path where the JSON output will be saved.

**Type:** `String`  
**Required:** No  
**Default:** `../infra/data/ordersBatch.json` (relative to script location)

**PowerShell Example:**

```powershell
.\Generate-Orders.ps1 -OutputPath "C:\data\orders.json"
```

**Bash Example:**

```bash
./Generate-Orders.sh --output "/data/orders.json"
```

---

### `-MinProducts` (PowerShell) / `--min-products` (Bash)

Minimum number of products per order.

**Type:** `Integer`  
**Required:** No  
**Default:** `1`  
**Valid Range:** `1-20`

**PowerShell Example:**

```powershell
.\Generate-Orders.ps1 -MinProducts 2
```

**Bash Example:**

```bash
./Generate-Orders.sh --min-products 2
```

---

### `-MaxProducts` (PowerShell) / `--max-products` (Bash)

Maximum number of products per order.

**Type:** `Integer`  
**Required:** No  
**Default:** `6`  
**Valid Range:** `1-20`

**Note:** Must be greater than or equal to MinProducts.

**PowerShell Example:**

```powershell
.\Generate-Orders.ps1 -MaxProducts 10
```

**Bash Example:**

```bash
./Generate-Orders.sh --max-products 10
```

---

### `-Force` (PowerShell) / `--force` (Bash)

Skips all confirmation prompts and forces immediate execution.

**Type:** `SwitchParameter` / `Flag`  
**Required:** No  
**Default:** `$false` / `false`

**Use Cases:**

- Automated CI/CD pipelines
- Scripted test data generation
- Non-interactive environments

---

### `-WhatIf` (PowerShell) / `--dry-run` (Bash)

Shows what operations would be performed without making actual changes.

**Type:** `SwitchParameter` / `Flag`  
**Required:** No  
**Default:** `$false` / `false`

**Use Cases:**

- Verifying script behavior before execution
- Auditing planned changes
- Training and demonstrations

---

### `-Verbose` (PowerShell) / `--verbose` (Bash)

Enables detailed diagnostic output for troubleshooting.

**Type:** `SwitchParameter` / `Flag`  
**Required:** No  
**Default:** `$false` / `false`

## 📚 Examples

### Example 1: Generate Test Data for Development

**PowerShell (Windows):**

```powershell
# Scenario: Setting up local development environment
cd Z:\Azure-LogicApps-Monitoring\hooks

# Generate a small test dataset
.\Generate-Orders.ps1 -OrderCount 50 -Verbose

# Verify the output
Get-Content ..\infra\data\ordersBatch.json | ConvertFrom-Json | Select-Object -First 5
```

**Bash (Linux/macOS):**

```bash
# Scenario: Setting up local development environment
cd /path/to/Azure-LogicApps-Monitoring/hooks

# Generate a small test dataset
./Generate-Orders.sh --count 50 --verbose

# Verify the output
jq '.[0:5]' ../infra/data/ordersBatch.json
```

---

### Example 2: CI/CD Pipeline Integration

**PowerShell (Windows):**

```powershell
# In CI/CD pipeline script
$ErrorActionPreference = 'Stop'

try {
    # Generate test data non-interactively
    & ./hooks/Generate-Orders.ps1 -OrderCount 1000 -Force

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to generate orders"
    }

    Write-Host "✓ Test data generated successfully"
}
catch {
    Write-Error "Data generation failed: $_"
    exit 1
}
```

**Bash (Linux/macOS):**

```bash
#!/bin/bash
set -e  # Exit on error

# Generate test data non-interactively
if ./hooks/Generate-Orders.sh --count 1000 --force; then
    echo "✓ Test data generated successfully"
else
    echo "ERROR: Data generation failed" >&2
    exit 1
fi
```

---

### Example 3: Load Testing Data Generation

**PowerShell (Windows):**

```powershell
# Generate maximum orders for load testing
.\Generate-Orders.ps1 -OrderCount 10000 -MinProducts 3 -MaxProducts 8 -Force -Verbose

# Check file size
Get-Item ..\infra\data\ordersBatch.json | Select-Object Length, @{N='SizeKB';E={[math]::Round($_.Length/1KB,2)}}
```

**Bash (Linux/macOS):**

```bash
# Generate maximum orders for load testing
./Generate-Orders.sh --count 10000 --min-products 3 --max-products 8 --force --verbose

# Check file size
ls -lh ../infra/data/ordersBatch.json
```

## 🛠️ How It Works

### Internal Process Flow

The script executes a systematic workflow through four distinct phases:

```mermaid
---
title: Generate-Orders Process Flow
---
flowchart LR
    %% ===== STYLE DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== ENTRY AND EXIT POINTS =====
    Start(["🚀 Generate-Orders starts"]):::trigger
    End(["🏁 Script completes"]):::secondary

    Start -->|"begins"| Initialization

    %% ===== PHASE 1: INITIALIZATION & VALIDATION =====
    subgraph Initialization["1️⃣ Initialization Phase"]
        direction TB
        Init["Script Initialization"]:::primary
        InitDetails["• Parse command-line args<br/>• Set StrictMode/strict mode<br/>• Configure preferences"]:::input
        Validate["Parameter Validation"]:::primary
        ValidateDetails["• Validate OrderCount range<br/>• Validate Min/Max products<br/>• Verify output path"]:::input
        Init -->|"configures"| InitDetails
        InitDetails -->|"validates"| Validate
        Validate -->|"checks"| ValidateDetails
    end

    %% ===== PHASE 2: DATA PREPARATION =====
    subgraph Preparation["2️⃣ Preparation Phase"]
        direction TB
        Catalog["Load Product Catalog"]:::datastore
        CatalogDetails["• 20 predefined products<br/>• Base prices configured<br/>• Product IDs assigned"]:::input
        Addresses["Load Address Pool"]:::datastore
        AddressDetails["• 20 global addresses<br/>• Major cities worldwide<br/>• Geographic diversity"]:::input
        Catalog -->|"loads"| CatalogDetails
        CatalogDetails -->|"prepares"| Addresses
        Addresses -->|"loads"| AddressDetails
    end

    %% ===== PHASE 3: ORDER GENERATION =====
    subgraph Generation["3️⃣ Generation Phase"]
        direction TB
        Loop["Order Generation Loop"]:::primary
        LoopDetails["• Generate GUID-based Order ID<br/>• Create Customer ID<br/>• Random date timestamp"]:::input
        Products["Product Selection"]:::primary
        ProductDetails["• Random product count<br/>• Apply ±20% price variation<br/>• Calculate line totals"]:::input
        Progress["Progress Tracking"]:::secondary
        ProgressDetails["• Update every 10 orders<br/>• Display percentage<br/>• Show current count"]:::input
        Loop -->|"generates"| LoopDetails
        LoopDetails -->|"selects"| Products
        Products -->|"calculates"| ProductDetails
        ProductDetails -->|"tracks"| Progress
        Progress -->|"reports"| ProgressDetails
    end

    %% ===== PHASE 4: EXPORT =====
    subgraph Export["4️⃣ Export Phase"]
        direction TB
        Serialize["JSON Serialization"]:::primary
        SerializeDetails["• Convert to JSON format<br/>• Depth 10 for nesting<br/>• UTF-8 encoding"]:::input
        Write["Write to File"]:::datastore
        WriteDetails["• Create directory if needed<br/>• Write JSON content<br/>• Display file size"]:::input
        Summary["Display Summary"]:::secondary
        SummaryDetails["• Total orders generated<br/>• Output file path<br/>• Products per order range"]:::input
        Serialize -->|"converts"| SerializeDetails
        SerializeDetails -->|"writes"| Write
        Write -->|"saves"| WriteDetails
        WriteDetails -->|"summarizes"| Summary
        Summary -->|"displays"| SummaryDetails
    end

    %% ===== FLOW CONNECTIONS =====
    Initialization -->|"proceeds to"| Preparation
    Preparation -->|"proceeds to"| Generation
    Generation -->|"proceeds to"| Export
    SummaryDetails -->|"completes"| End

    %% ===== SUBGRAPH STYLES =====
    style Initialization fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Preparation fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style Generation fill:#F3E8FF,stroke:#A855F7,stroke-width:2px
    style Export fill:#D1FAE5,stroke:#10B981,stroke-width:2px
```

**Process Details:**

1. **Initialization Phase**: Parses command-line arguments (`-OrderCount`, `-OutputPath`, `-MinProducts`, `-MaxProducts`, `-Force`), sets strict mode, and validates all parameters are within acceptable ranges
2. **Preparation Phase**: Loads the 20-product catalog with base prices and the 20-address global pool for geographic diversity
3. **Generation Phase**: Iterates through order count, generating unique GUID-based IDs, random timestamps (2024-2025), random product selections with ±20% price variations, and tracks progress every 10 orders
4. **Export Phase**: Serializes orders to JSON format with proper depth, writes to file (creating directories as needed), and displays execution summary

### Integration Points

| Aspect           | Details                                                                                                                                                                                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Called By**    | • `deploy-workflow.ps1/.sh` - Generates test data before deployment<br/>• Manual execution for development testing<br/>• CI/CD pipelines for automated test data setup                                     |
| **Calls**        | • `New-Guid` / `uuidgen` - Unique ID generation<br/>• `Get-Random` / `$RANDOM` - Random number generation<br/>• `ConvertTo-Json` / `jq` - JSON serialization<br/>• `bc` - Decimal calculations (Bash only) |
| **Dependencies** | • **Runtime:** PowerShell 7.0+ or Bash 4.0+<br/>• **Tools:** `jq` and `bc` required for Bash version<br/>• **Output Directory:** Auto-created if missing                                                   |
| **Outputs**      | • **Exit Code:** `0` (success) or `1` (failure)<br/>• **File:** JSON array of order objects<br/>• **Console:** Progress updates and summary                                                                |
| **Data Schema**  | • **Order ID:** `ORD-{12 hex chars}`<br/>• **Customer ID:** `CUST-{8 hex chars}`<br/>• **Product ID:** `OP-{12 hex chars}`<br/>• **Date Range:** 2024-01-01 to 2025-12-31                                  |

## 📖 Related Documentation

- **[postprovision.md](./postprovision.md)** - Configures secrets after Azure deployment
- **[deploy-workflow.md](./deploy-workflow.md)** - Deploys Logic Apps workflows (uses generated data)
- **[README.md](./README.md)** - Hooks directory overview
- **[Azure Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)** - Official Microsoft documentation

## 🔐 Security Considerations

### Safe Operations

✅ **Safe to Run:**

- Only creates/overwrites JSON data files
- Does not modify source code
- Does not affect production environments
- Local operation only (no network calls)
- Does not store or transmit sensitive data
- Generated data uses fake/random identifiers

### Generated Data Characteristics

| Aspect           | Details                                      |
| ---------------- | -------------------------------------------- |
| **Customer IDs** | Randomly generated GUIDs (not real)          |
| **Order IDs**    | Randomly generated GUIDs (not real)          |
| **Addresses**    | Fictional/famous addresses (not real people) |
| **Dates**        | Random timestamps within 2024-2025           |
| **Prices**       | Simulated with ±20% variation                |

### When to Run

| Scenario                    | Safe to Run? | Notes                      |
| --------------------------- | ------------ | -------------------------- |
| **Local Development**       | ✅ Yes       | Standard use case          |
| **Before Testing**          | ✅ Yes       | Generates fresh test data  |
| **CI/CD Pipeline**          | ✅ Yes       | Use `--force` flag         |
| **Production Environment**  | ⚠️ Caution   | Overwrites existing data   |
| **Shared Data Directories** | ⚠️ Caution   | May affect other processes |

## 🎓 Best Practices

### When to Use This Script

| Situation                           | Recommendation     |
| ----------------------------------- | ------------------ |
| **Setting up dev environment**      | ✅ Recommended     |
| **Before running Logic Apps tests** | ✅ Recommended     |
| **Load testing preparation**        | ✅ Recommended     |
| **Demo/presentation setup**         | ✅ Recommended     |
| **CI/CD test data setup**           | ✅ Recommended     |
| **Production data**                 | ❌ Not recommended |

### Data Generation Guidelines

1. **Start Small**: Begin with 50-100 orders for development
2. **Scale Gradually**: Increase order count for load testing
3. **Verify Output**: Always validate JSON structure before use
4. **Clean Previous Data**: Overwrite existing files to prevent stale data
5. **Use Verbose Mode**: Enable for troubleshooting and CI/CD logs

### Development Workflow Integration

```powershell
# Typical development workflow

# Step 1: Generate fresh test data
.\hooks\Generate-Orders.ps1 -OrderCount 100 -Force

# Step 2: Start local development environment
.\app.AppHost\bin\Debug\net10.0\app.AppHost.exe

# Step 3: Test Logic Apps with generated data
# ...
```

## 📊 Performance

### Performance Characteristics

| Characteristic     | Details                                                                                                                                                                                                                                   |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Execution Time** | • **100 orders:** ~1 second<br/>• **2000 orders (default):** ~5-10 seconds<br/>• **10000 orders:** ~30-60 seconds<br/>• **Scaling:** Linear O(n) with order count                                                                         |
| **Resource Usage** | • **Memory:** ~50-100 MB peak during execution<br/>• **CPU:** Moderate utilization (GUID generation, JSON serialization)<br/>• **Disk I/O:** Single write operation at completion<br/>• **Process spawning:** None (pure PowerShell/Bash) |
| **Output Size**    | • **Per order:** ~500-800 bytes (varies by product count)<br/>• **100 orders:** ~50-80 KB<br/>• **2000 orders:** ~1-2 MB<br/>• **10000 orders:** ~5-8 MB                                                                                  |
| **Network Impact** | • **Zero network calls** - completely offline operation<br/>• **No Azure connections** - local file system only<br/>• **No API requests** - uses local random generation<br/>• **Ideal for disconnected environments**                    |

### Optimization Tips

- Use `-Force` in scripts to skip confirmation overhead
- Progress updates every 10 orders minimize console I/O
- JSON serialization uses efficient depth setting
- Generic lists used for memory-efficient collection building

## 📜 Version History

| Version | Date       | Author                          | Changes                                                                                                                                                |
| ------- | ---------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1.0.0   | 2025-12-01 | Azure-LogicApps-Monitoring Team | • Initial release<br/>• Basic order generation with fixed structure<br/>• PowerShell implementation only                                               |
| 2.0.0   | 2025-12-15 | Azure-LogicApps-Monitoring Team | • Added GUID-based order IDs<br/>• Added price variation simulation<br/>• Enhanced product catalog<br/>• Added global address pool                     |
| 2.0.1   | 2026-01-06 | Azure-LogicApps-Monitoring Team | • Added Bash implementation<br/>• Added -WhatIf/--dry-run support<br/>• Enhanced documentation<br/>• Applied PowerShell best practices<br/>• Bug fixes |

## Quick Links

- **Repository**: [Azure-LogicApps-Monitoring](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- **Issues**: [Report Bug](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues)
- **Azure Logic Apps**: [Microsoft Learn](https://learn.microsoft.com/azure/logic-apps/)

---

<div align="center">

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**

[⬆ Back to Top](#-generate-orders-ps1--sh) | [← SQL Managed Identity](sql-managed-identity-config.md) | [📑 Index](README.md) | [Deploy Workflow →](deploy-workflow.md)

</div>
