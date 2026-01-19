---
title: Security Architecture
description: Authentication, authorization, network security, and compliance for the Azure Logic Apps Monitoring solution
author: Evilazaro
version: 1.0
tags: [architecture, security, managed-identity, rbac, network-security]
---

# 🔐 Security Architecture

> [!NOTE]
> 🎯 **For Security Engineers**: This document covers identity, secrets, network security, and compliance.  
> ⏱️ **Estimated reading time:** 15 minutes

<details>
<summary>📍 <strong>Quick Navigation</strong></summary>

| Previous | Index | Next |
|:---------|:------:|--------:|
| [← Observability Architecture](05-observability-architecture.md) | [📑 Index](README.md) | [Deployment Architecture →](07-deployment-architecture.md) |

</details>

---

## 📑 Table of Contents

- [📋 Security Overview](#-1-security-overview)
- [🔐 Authentication & Authorization](#-2-authentication--authorization)
- [🎭 Managed Identity Architecture](#-3-managed-identity-architecture)
- [🔑 Secret Management](#-4-secret-management)
- [🌐 Network Security](#-5-network-security)
- [🛡️ Data Protection](#%EF%B8%8F-6-data-protection)
- [✅ Compliance & Governance](#-7-compliance--governance)
- [📝 Security Checklist](#-8-security-checklist)
- [🔗 Cross-Architecture Relationships](#-cross-architecture-relationships)

---

## 📋 1. Security Overview

### Security Principles

| #       | Principle              | Statement                             | Implementation                          |
| ------- | ---------------------- | ------------------------------------- | --------------------------------------- |
| **S-1** | **Zero Trust**         | Never trust, always verify            | Managed Identity for all service auth   |
| **S-2** | **Least Privilege**    | Minimal permissions required          | Scoped RBAC role assignments            |
| **S-3** | **Defense in Depth**   | Multiple security layers              | Network + Identity + Encryption         |
| **S-4** | **Secrets-Free**       | No secrets in code or config          | Managed Identity, no connection strings |
| **S-5** | **Encrypt Everything** | Data protected at rest and in transit | TLS 1.2+, TDE, Azure encryption         |

### Threat Model Summary

| Threat Category         | Risk   | Mitigation                                        |
| ----------------------- | ------ | ------------------------------------------------- |
| **Credential Theft**    | High   | Managed Identity - no credentials to steal        |
| **Data Exfiltration**   | Medium | Network isolation, encryption at rest             |
| **Man-in-the-Middle**   | Medium | TLS 1.2+ for all communications                   |
| **Unauthorized Access** | High   | Azure RBAC, API authentication                    |
| **Injection Attacks**   | Medium | Parameterized queries (EF Core), input validation |

---

## 🔐 2. Authentication & Authorization

### Authentication Flow

```mermaid
---
title: Authentication Flow via Managed Identity
---
flowchart LR
    %% ===== CLASS DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== SERVICES SUBGRAPH =====
    subgraph Services["Services"]
        API["Orders API"]
        WebApp["Web App"]
        LogicApp["Logic App"]
    end
    style Services fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== IDENTITY PLATFORM SUBGRAPH =====
    subgraph Identity["Identity Platform"]
        MI["User-Assigned<br/>Managed Identity"]
        EntraID["Microsoft Entra ID"]
    end
    style Identity fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== AZURE RESOURCES SUBGRAPH =====
    subgraph Resources["Azure Resources"]
        SQL["Azure SQL"]
        SB["Service Bus"]
        Storage["Azure Storage"]
        AI["App Insights"]
    end
    style Resources fill:#D1FAE5,stroke:#10B981,stroke-width:2px

    %% ===== CONNECTIONS =====
    API -->|"Request Identity"| MI
    WebApp -->|"Request Identity"| MI
    LogicApp -->|"Request Identity"| MI
    MI -->|"Authenticate"| EntraID
    EntraID -->|"Access Token"| SQL
    EntraID -->|"Access Token"| SB
    EntraID -->|"Access Token"| Storage
    EntraID -->|"Access Token"| AI

    %% ===== NODE STYLES =====
    class API,WebApp,LogicApp primary
    class MI,EntraID trigger
    class SQL,SB,Storage,AI secondary
```

### Identity Providers

| Component             | Identity Type                  | Authentication Method                 |
| --------------------- | ------------------------------ | ------------------------------------- |
| **Orders API**        | User-Assigned Managed Identity | Azure.Identity DefaultAzureCredential |
| **Web App**           | User-Assigned Managed Identity | Azure.Identity DefaultAzureCredential |
| **Logic Apps**        | User-Assigned Managed Identity | Azure connector authentication        |
| **Local Development** | Azure CLI / Visual Studio      | Interactive login                     |

### API Security

| Endpoint      | Authentication  | Authorization     |
| ------------- | --------------- | ----------------- |
| `/api/orders` | None (internal) | Network isolation |
| `/health`     | None            | Public            |
| `/alive`      | None            | Public            |

> **Note**: In production, consider adding API authentication (e.g., Entra ID, API keys) for external access.

---

## 🎭 3. Managed Identity Architecture

### Identity Assignments

```mermaid
---
title: Managed Identity Role Assignments
---
flowchart TB
    %% ===== CLASS DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== MANAGED IDENTITY SUBGRAPH =====
    subgraph Identity["🔐 User-Assigned Managed Identity"]
        MI["id-orders-{env}"]
    end
    style Identity fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== SERVICES SUBGRAPH =====
    subgraph Services["📱 Services"]
        API["Container App:<br/>orders-api"]
        Web["Container App:<br/>web-app"]
        LA["Logic App:<br/>OrdersManagement"]
    end
    style Services fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== ROLE ASSIGNMENTS SUBGRAPH =====
    subgraph Roles["🎫 Role Assignments"]
        SQLRole["Azure SQL:<br/>SQL DB Contributor"]
        SBRole["Service Bus:<br/>Data Sender/Receiver"]
        StorageRole["Storage:<br/>Blob Data Contributor"]
        AIRole["App Insights:<br/>Monitoring Contributor"]
    end
    style Roles fill:#D1FAE5,stroke:#10B981,stroke-width:2px

    %% ===== SERVICE BINDINGS =====
    MI -->|"Assigned To"| API
    MI -->|"Assigned To"| Web
    MI -->|"Assigned To"| LA

    %% ===== ROLE BINDINGS =====
    MI -->|"Grants"| SQLRole
    MI -->|"Grants"| SBRole
    MI -->|"Grants"| StorageRole
    MI -->|"Grants"| AIRole

    %% ===== NODE STYLES =====
    class MI trigger
    class API,Web,LA primary
    class SQLRole,SBRole,StorageRole,AIRole secondary
```

### Role Assignments

| Resource                 | Role                            | Purpose                             |
| ------------------------ | ------------------------------- | ----------------------------------- |
| **Azure SQL Database**   | SQL DB Contributor              | Database read/write access          |
| **Azure Service Bus**    | Azure Service Bus Data Sender   | Publish messages to topics          |
| **Azure Service Bus**    | Azure Service Bus Data Receiver | Receive messages from subscriptions |
| **Azure Storage**        | Storage Blob Data Contributor   | Logic App workflow state            |
| **Application Insights** | Monitoring Contributor          | Telemetry write access              |

### Service-to-Service Auth Flow

```mermaid
---
title: Service-to-Service Authentication Flow
---
sequenceDiagram
    %% ===== PARTICIPANTS =====
    autonumber
    participant API as Orders API
    participant MI as Managed Identity
    participant Entra as Microsoft Entra ID
    participant SB as Service Bus

    %% ===== TOKEN ACQUISITION =====
    API->>MI: Request access token
    MI->>Entra: Authenticate via implicit flow
    Entra-->>MI: Return JWT Token
    MI-->>API: Return Access Token

    %% ===== SERVICE CALL =====
    API->>SB: Send message with Bearer token
    SB-->>API: Return Accepted response
```

---

## 🔑 4. Secret Management

### Secret Storage Approach

| Environment           | Approach         | Storage             |
| --------------------- | ---------------- | ------------------- |
| **Production**        | Managed Identity | No secrets stored   |
| **Local Development** | User Secrets     | .NET Secret Manager |
| **CI/CD**             | GitHub Variables | Repository settings |

### Secrets Inventory

| Secret                     | Usage           | Storage                 | Rotation |
| -------------------------- | --------------- | ----------------------- | -------- |
| **SQL Connection**         | Database access | None (Managed Identity) | N/A      |
| **Service Bus Connection** | Messaging       | None (Managed Identity) | N/A      |
| **App Insights Key**       | Telemetry       | Connection string       | N/A      |
| **Azure Client ID**        | Local dev only  | User Secrets            | Manual   |
| **Azure Tenant ID**        | Local dev only  | User Secrets            | Manual   |

### Local Development Secrets

```json
// User Secrets (secrets.json) - Local development only
{
  "Azure:TenantId": "<tenant-id>",
  "Azure:ClientId": "<client-id>",
  "ConnectionStrings:OrderDb": "Server=localhost;...",
  "MESSAGING_HOST": "localhost"
}
```

> **Important**: User secrets are never committed to source control.

---

## 🌐 5. Network Security

### Network Topology

```mermaid
---
title: Network Security Topology
---
flowchart TB
    %% ===== CLASS DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== INTERNET SUBGRAPH =====
    subgraph Internet["🌐 Internet"]
        Users["Users"]
    end
    style Internet fill:#FEE2E2,stroke:#EF4444,stroke-width:2px

    %% ===== VIRTUAL NETWORK SUBGRAPH =====
    subgraph VNet["🔒 Virtual Network"]
        subgraph APISubnet["API Subnet"]
            API["Container Apps"]
        end
        subgraph LASubnet["Logic App Subnet"]
            LA["Logic Apps"]
        end
    end
    style VNet fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style APISubnet fill:#E0E7FF,stroke:#6366F1,stroke-width:1px
    style LASubnet fill:#E0E7FF,stroke:#6366F1,stroke-width:1px

    %% ===== AZURE PAAS SUBGRAPH =====
    subgraph PaaS["☁️ Azure PaaS"]
        SQL["Azure SQL<br/>(Firewall rules)"]
        SB["Service Bus<br/>(Public endpoint)"]
        Storage["Azure Storage<br/>(Private endpoint optional)"]
    end
    style PaaS fill:#D1FAE5,stroke:#10B981,stroke-width:2px

    %% ===== NETWORK FLOWS =====
    Users -->|"HTTPS Request"| API
    API -->|"Private TDS/TLS"| SQL
    API -->|"AMQP/TLS"| SB
    LA -->|"Connector Call"| SB
    LA -->|"Blob Storage"| Storage

    %% ===== NODE STYLES =====
    class Users external
    class API,LA primary
    class SQL,SB,Storage secondary
```

### Network Controls

| Control               | Implementation             | Purpose                 |
| --------------------- | -------------------------- | ----------------------- |
| **VNet Integration**  | Container Apps, Logic Apps | Network isolation       |
| **SQL Firewall**      | Azure SQL firewall rules   | Database access control |
| **Private Endpoints** | Optional for SQL, Storage  | Enhanced isolation      |
| **TLS Enforcement**   | TLS 1.2+ required          | Encryption in transit   |

---

## 🛡️ 6. Data Protection

### Encryption at Rest

| Resource                 | Encryption                        | Key Management    |
| ------------------------ | --------------------------------- | ----------------- |
| **Azure SQL Database**   | TDE (Transparent Data Encryption) | Microsoft-managed |
| **Azure Service Bus**    | Service-managed encryption        | Microsoft-managed |
| **Azure Storage**        | SSE (Storage Service Encryption)  | Microsoft-managed |
| **Application Insights** | Azure encryption                  | Microsoft-managed |

### Encryption in Transit

| Connection         | Protocol      | Minimum Version |
| ------------------ | ------------- | --------------- |
| **HTTPS (APIs)**   | TLS           | 1.2             |
| **SQL Connection** | TDS over TLS  | 1.2             |
| **Service Bus**    | AMQP over TLS | 1.2             |
| **Storage**        | HTTPS         | TLS 1.2         |

### Data Classification

| Data Type              | Classification | Handling            |
| ---------------------- | -------------- | ------------------- |
| **Order IDs**          | Internal       | No special handling |
| **Customer IDs**       | Internal       | No special handling |
| **Delivery Addresses** | PII            | Encrypted at rest   |
| **Telemetry Data**     | Operational    | 90-day retention    |

---

## ✅ 7. Compliance & Governance

### Compliance Requirements

| Requirement         | Implementation                   | Evidence                 |
| ------------------- | -------------------------------- | ------------------------ |
| **Data Encryption** | TDE, TLS 1.2+                    | Azure compliance reports |
| **Access Control**  | RBAC, Managed Identity           | Role assignment audit    |
| **Audit Logging**   | Azure Activity Log, App Insights | Log retention policies   |
| **Data Residency**  | Single region deployment         | Resource location        |

### Audit Logging

| Event Type                    | Log Destination               | Retention |
| ----------------------------- | ----------------------------- | --------- |
| **Azure Resource Operations** | Activity Log                  | 90 days   |
| **Application Events**        | Application Insights          | 90 days   |
| **Security Events**           | Log Analytics                 | 30 days   |
| **API Access**                | Application Insights requests | 90 days   |

---

## 📝 8. Security Checklist

- [x] **Managed Identity** configured for all services
- [x] **No secrets** stored in code or configuration files
- [x] **TLS 1.2+** enforced for all connections
- [x] **RBAC** role assignments with least privilege
- [x] **Encryption at rest** enabled for all data stores
- [x] **Network isolation** via VNet integration
- [x] **Health endpoints** excluded from authentication
- [x] **Input validation** via Data Annotations
- [x] **Parameterized queries** via Entity Framework Core
- [ ] **API authentication** (consider for external access)
- [ ] **Private endpoints** (consider for enhanced isolation)
- [ ] **Key Vault** (consider for external secrets)

---

## 🔗 Cross-Architecture Relationships

| Related Architecture        | Connection                         | Reference                                                |
| --------------------------- | ---------------------------------- | -------------------------------------------------------- |
| **Technology Architecture** | Identity and network platform      | [Technology Architecture](04-technology-architecture.md) |
| **Deployment Architecture** | Secret management in CI/CD         | [Deployment Architecture](07-deployment-architecture.md) |
| **Data Architecture**       | Data classification and protection | [Data Architecture](02-data-architecture.md)             |

---

[← Observability Architecture](05-observability-architecture.md) | [Index](README.md) | [Deployment Architecture →](07-deployment-architecture.md)
