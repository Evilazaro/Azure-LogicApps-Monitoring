# TOGAF BDAT Model: Azure Logic Apps Standard - Enterprise-Scale Monitoring & Orchestration

## Project Overview

### Problem Statement

Enterprise organizations deploying Azure Logic Apps Standard at global scale encounter significant operational and financial challenges when managing thousands of workflows. Microsoft's current guidance recommends limiting deployments to approximately **20 workflows per Logic App instance** and up to **64 apps per App Service Plan**. Organizations that exceed these thresholds—particularly when leveraging 64-bit worker processes—frequently experience memory pressure, workflow instability, performance degradation, and unpredictable scaling behavior. These limitations become especially problematic for enterprises running **long-running workflows** that may execute for 18–36 months, such as complex approval chains, multi-stage fulfillment processes, or regulatory compliance workflows.

The combination of high workflow density and extended execution times creates compounding operational risks, including increased memory consumption, state management challenges, and difficulty isolating problematic workflows. Without proper architecture patterns and monitoring, these issues cascade into **significant cost overruns**—with some organizations reporting operational costs approaching **US$80,000 annually per environment**. Current monitoring solutions often lack the granularity needed to diagnose performance issues at the individual workflow level, making it difficult to identify bottlenecks, track resource consumption patterns, or optimize workflow placement strategies.

This solution provides a production-ready reference architecture that addresses these enterprise-scale challenges by demonstrating optimal workflow hosting density, implementing comprehensive observability aligned with the Azure Well-Architected Framework, and establishing proven patterns for long-running workflows without compromising stability or cost-effectiveness. The architecture leverages .NET Aspire for orchestration, Azure Container Apps for containerized hosting, and Azure Application Insights with OpenTelemetry for end-to-end observability.

---

## Business Architecture

### Purpose
The Business Architecture layer defines the **capabilities, value streams, and business outcomes** that the solution enables. It focuses on how the system supports order management processes, workflow orchestration, and operational monitoring for enterprise-scale deployments of Azure Logic Apps Standard.

### Key Capabilities
- **Order Lifecycle Management**: Create, update, process, and delete orders through automated workflows
- **Workflow Orchestration**: Design, execute, and monitor long-running business processes
- **Operational Excellence**: Performance optimization, cost management, and incident response
- **Integration Management**: API-driven integration, event processing, and data synchronization

### Process (High-Level)
The business processes center around **order lifecycle management** (create, update, process, delete) orchestrated through Logic Apps workflows, with comprehensive monitoring providing visibility into business outcomes, performance metrics, and cost optimization opportunities.

### Business Capability Map

```mermaid
flowchart TB
    subgraph OrderManagement["Order Management"]
        OrderCreation["Order Creation"]
        OrderFulfillment["Order Fulfillment"]
        OrderTracking["Order Tracking"]
    end
    
    subgraph WorkflowOrchestration["Workflow Orchestration"]
        WorkflowDesign["Workflow Design"]
        WorkflowExecution["Workflow Execution"]
        WorkflowMonitoring["Workflow Monitoring"]
    end
    
    subgraph OperationalExcellence["Operational Excellence"]
        PerformanceOptimization["Performance Optimization"]
        CostManagement["Cost Management"]
        IncidentResponse["Incident Response"]
    end
    
    subgraph Integration["Integration Capabilities"]
        APIManagement["API Management"]
        EventProcessing["Event Processing"]
        DataSynchronization["Data Synchronization"]
    end
    
    style OrderManagement fill:#E6D5FF
    style WorkflowOrchestration fill:#E6D5FF
    style OperationalExcellence fill:#E6D5FF
    style Integration fill:#E6D5FF
    style OrderCreation fill:#E6D5FF
    style OrderFulfillment fill:#E6D5FF
    style OrderTracking fill:#E6D5FF
    style WorkflowDesign fill:#E6D5FF
    style WorkflowExecution fill:#E6D5FF
    style WorkflowMonitoring fill:#E6D5FF
    style PerformanceOptimization fill:#E6D5FF
    style CostManagement fill:#E6D5FF
    style IncidentResponse fill:#E6D5FF
    style APIManagement fill:#E6D5FF
    style EventProcessing fill:#E6D5FF
    style DataSynchronization fill:#E6D5FF
```

### Value Stream Map

```mermaid
flowchart LR
    Demand["Customer Order Demand"] --> Capture["Order Capture via API"]
    Capture --> Validate["Order Validation"]
    Validate --> Route["Workflow Routing"]
    Route --> Execute["Workflow Execution"]
    Execute --> Monitor["Real-time Monitoring"]
    Monitor --> Fulfill["Order Fulfillment"]
    Fulfill --> Deliver["Value Delivered to Customer"]
    
    Monitor --> Optimize["Continuous Optimization"]
    Optimize --> Route
    
    style Demand fill:#E6D5FF
    style Capture fill:#E6D5FF
    style Validate fill:#E6D5FF
    style Route fill:#E6D5FF
    style Execute fill:#E6D5FF
    style Monitor fill:#FFD580
    style Fulfill fill:#E6D5FF
    style Deliver fill:#E6D5FF
    style Optimize fill:#FFD580
```

---

## Data Architecture

### Purpose
The Data Architecture layer defines how data flows through the system, how it is stored and managed, and how monitoring and observability data is collected, processed, and analyzed to support operational excellence and business intelligence.

### Key Capabilities
- **Transactional Data Management**: Order data persistence in Cosmos DB with hierarchical partition keys
- **Event Stream Management**: Asynchronous messaging via Azure Service Bus topics and subscriptions
- **Telemetry Collection**: OpenTelemetry-based metrics, logs, and distributed traces
- **State Management**: Workflow state persistence for long-running processes

### Process (High-Level)
Data flows through **ingestion** (orders via API, events via Service Bus), **processing** (workflow execution, business logic in microservices), **storage** (Cosmos DB for orders with userId partition key, Application Insights for telemetry), and **governance** (monitoring dashboards, alerting, optimization).

### Master Data Management (MDM)

```mermaid
flowchart LR
    subgraph Sources["Data Sources"]
        OrdersAPI["Orders API"]
        LogicAppWorkflows["Logic App Workflows"]
        ServiceBusEvents["Service Bus Events"]
    end
    
    subgraph MDMHub["MDM Hub - Cosmos DB"]
        OrderMasterData["Order Master Data<br/>(Partition: userId)"]
        WorkflowState["Workflow State Data"]
    end
    
    subgraph Consumers["Data Consumers"]
        BlazorApp["Blazor Application"]
        MonitoringSystems["Monitoring Systems"]
        AspireDashboard["Aspire Dashboard"]
    end
    
    OrdersAPI --> OrderMasterData
    LogicAppWorkflows --> WorkflowState
    ServiceBusEvents --> OrderMasterData
    
    OrderMasterData --> BlazorApp
    WorkflowState --> MonitoringSystems
    OrderMasterData --> AspireDashboard
    WorkflowState --> AspireDashboard
    
    style Sources fill:#ADD8E6
    style MDMHub fill:#FFE5B4
    style Consumers fill:#90EE90
    style OrdersAPI fill:#ADD8E6
    style LogicAppWorkflows fill:#ADD8E6
    style ServiceBusEvents fill:#ADD8E6
    style OrderMasterData fill:#FFE5B4
    style WorkflowState fill:#FFE5B4
    style BlazorApp fill:#90EE90
    style MonitoringSystems fill:#90EE90
    style AspireDashboard fill:#90EE90
```

### Event-Driven Data Topology

```mermaid
flowchart LR
    subgraph Producers["Event Producers"]
        OrdersAPI["Orders API"]
        Workflows["Logic App Workflows<br/>(CreateOrder, UpdateOrder,<br/>DeleteOrder, ProcessOrder)"]
    end
    
    subgraph EventBus["Azure Service Bus"]
        OrdersTopic["Orders Topic"]
        WorkflowTopics["Workflow Topics"]
    end
    
    subgraph Consumers["Event Consumers"]
        CreateOrderWorkflow["CreateOrder Workflow"]
        UpdateOrderWorkflow["UpdateOrder Workflow"]
        ProcessOrderWorkflow["ProcessOrder Workflow"]
        DeleteOrderWorkflow["DeleteOrder Workflow"]
    end
    
    subgraph Storage["Event Storage"]
        CosmosDB["Cosmos DB<br/>(Order Event Store)"]
        AppInsights["Application Insights<br/>(Telemetry Events)"]
    end
    
    OrdersAPI --> OrdersTopic
    Workflows --> WorkflowTopics
    
    OrdersTopic --> CreateOrderWorkflow
    OrdersTopic --> UpdateOrderWorkflow
    OrdersTopic --> ProcessOrderWorkflow
    OrdersTopic --> DeleteOrderWorkflow
    
    CreateOrderWorkflow --> CosmosDB
    UpdateOrderWorkflow --> CosmosDB
    ProcessOrderWorkflow --> CosmosDB
    DeleteOrderWorkflow --> CosmosDB
    
    CreateOrderWorkflow --> AppInsights
    UpdateOrderWorkflow --> AppInsights
    ProcessOrderWorkflow --> AppInsights
    DeleteOrderWorkflow --> AppInsights
    
    style Producers fill:#90EE90
    style EventBus fill:#FFB347
    style Consumers fill:#90EE90
    style Storage fill:#FFE5B4
    style OrdersAPI fill:#90EE90
    style Workflows fill:#90EE90
    style OrdersTopic fill:#FFB347
    style WorkflowTopics fill:#FFB347
    style CreateOrderWorkflow fill:#90EE90
    style UpdateOrderWorkflow fill:#90EE90
    style ProcessOrderWorkflow fill:#90EE90
    style DeleteOrderWorkflow fill:#90EE90
    style CosmosDB fill:#FFE5B4
    style AppInsights fill:#FFE5B4
```

### Monitoring Dataflow

```mermaid
flowchart LR
    subgraph Ingestion["Telemetry Ingestion"]
        OTLP["OpenTelemetry SDK<br/>(Orders API, Blazor App)"]
        AspireExporter["Aspire Exporter<br/>(ServiceDefaults)"]
        LogicAppsLogs["Logic Apps Runtime Logs"]
    end
    
    subgraph Processing["Processing Layer"]
        AspireDashboard["Aspire Dashboard<br/>(Local Development)"]
        AppInsightsProcessing["Application Insights<br/>Processing Pipeline"]
    end
    
    subgraph StorageZones["Storage Zones"]
        MetricsDB["Metrics Store<br/>(Application Insights)"]
        LogsDB["Logs Store<br/>(Log Analytics)"]
        TracesDB["Distributed Traces<br/>(Application Insights)"]
    end
    
    subgraph Governance["Governance & Analytics"]
        AzureMonitor["Azure Monitor Alerts"]
        Workbooks["Azure Workbooks"]
        CustomDashboards["Custom Dashboards"]
    end
    
    OTLP --> AspireDashboard
    AspireExporter --> AppInsightsProcessing
    LogicAppsLogs --> AppInsightsProcessing
    
    AspireDashboard --> MetricsDB
    AppInsightsProcessing --> LogsDB
    AppInsightsProcessing --> TracesDB
    AppInsightsProcessing --> MetricsDB
    
    MetricsDB --> AzureMonitor
    LogsDB --> Workbooks
    TracesDB --> CustomDashboards
    
    style Ingestion fill:#ADD8E6
    style Processing fill:#90EE90
    style StorageZones fill:#FFE5B4
    style Governance fill:#D3D3D3
    style OTLP fill:#ADD8E6
    style AspireExporter fill:#ADD8E6
    style LogicAppsLogs fill:#ADD8E6
    style AspireDashboard fill:#90EE90
    style AppInsightsProcessing fill:#90EE90
    style MetricsDB fill:#FFE5B4
    style LogsDB fill:#FFE5B4
    style TracesDB fill:#FFE5B4
    style AzureMonitor fill:#D3D3D3
    style Workbooks fill:#D3D3D3
    style CustomDashboards fill:#D3D3D3
```

---

## Application Architecture

### Purpose
The Application Architecture layer defines the **services, APIs, workflows, and their interactions** that implement business capabilities. It focuses on microservices patterns, event-driven architecture, and workflow orchestration for scalable order management.

### Key Capabilities
- **RESTful API Services**: Orders API for CRUD operations and workflow triggering
- **Interactive User Interfaces**: Blazor Server and WebAssembly client for order management
- **Workflow Automation**: Logic Apps Standard workflows (CreateOrder, UpdateOrder, DeleteOrder, ProcessOrder)
- **Service Orchestration**: .NET Aspire AppHost for service discovery and configuration management

### Process (High-Level)
Applications are organized as **microservices** (Orders API, Blazor App) orchestrated through **.NET Aspire AppHost** and integrated via **event-driven patterns** using Azure Service Bus. Logic Apps workflows consume events from Service Bus topics and execute stateful, long-running business processes, with all components instrumented for observability through OpenTelemetry.

### Microservices Architecture

```mermaid
flowchart LR
    subgraph Clients["Client Applications"]
        WebBrowser["Web Browser"]
    end
    
    subgraph Gateway["Application Gateway"]
        AspireAppHost["Aspire AppHost<br/>(Service Discovery)"]
    end
    
    subgraph Services["Application Services"]
        OrdersAPI["Orders API<br/>(eShop.Orders.API)"]
        BlazorServer["Blazor Server<br/>(eShop.Orders.App)"]
        BlazorClient["Blazor WebAssembly<br/>(eShop.Orders.App.Client)"]
    end
    
    subgraph Workflows["Workflow Services"]
        CreateOrderWF["CreateOrder Workflow"]
        UpdateOrderWF["UpdateOrder Workflow"]
        ProcessOrderWF["ProcessOrder Workflow"]
        DeleteOrderWF["DeleteOrder Workflow"]
    end
    
    subgraph DataServices["Data Services"]
        CosmosDB["Cosmos DB<br/>(Partition: userId)"]
        ServiceBus["Azure Service Bus<br/>(Topics & Subscriptions)"]
    end
    
    WebBrowser --> AspireAppHost
    AspireAppHost --> OrdersAPI
    AspireAppHost --> BlazorServer
    BlazorServer --> BlazorClient
    
    OrdersAPI --> ServiceBus
    ServiceBus --> CreateOrderWF
    ServiceBus --> UpdateOrderWF
    ServiceBus --> ProcessOrderWF
    ServiceBus --> DeleteOrderWF
    
    OrdersAPI --> CosmosDB
    CreateOrderWF --> CosmosDB
    UpdateOrderWF --> CosmosDB
    ProcessOrderWF --> CosmosDB
    DeleteOrderWF --> CosmosDB
    
    style Clients fill:#ADD8E6
    style Gateway fill:#E6D5FF
    style Services fill:#90EE90
    style Workflows fill:#90EE90
    style DataServices fill:#FFE5B4
    style WebBrowser fill:#ADD8E6
    style AspireAppHost fill:#E6D5FF
    style OrdersAPI fill:#90EE90
    style BlazorServer fill:#90EE90
    style BlazorClient fill:#90EE90
    style CreateOrderWF fill:#90EE90
    style UpdateOrderWF fill:#90EE90
    style ProcessOrderWF fill:#90EE90
    style DeleteOrderWF fill:#90EE90
    style CosmosDB fill:#FFE5B4
    style ServiceBus fill:#FFE5B4
```

### Event-Driven Architecture

```mermaid
flowchart LR
    subgraph Producers["Event Producers"]
        OrdersAPI["Orders API<br/>(HTTP Triggers)"]
    end
    
    subgraph EventBus["Azure Service Bus"]
        OrdersTopic["Orders Topic"]
        subgraph Subscriptions["Subscriptions"]
            CreateSub["CreateOrder Subscription"]
            UpdateSub["UpdateOrder Subscription"]
            ProcessSub["ProcessOrder Subscription"]
            DeleteSub["DeleteOrder Subscription"]
        end
    end
    
    subgraph Consumers["Event Consumers"]
        CreateWorkflow["CreateOrder Workflow<br/>(LogicAppWP/ConsosoOrders)"]
        UpdateWorkflow["UpdateOrder Workflow<br/>(LogicAppWP/ConsosoOrders)"]
        ProcessWorkflow["ProcessOrder Workflow<br/>(LogicAppWP/ConsosoOrders)"]
        DeleteWorkflow["DeleteOrder Workflow<br/>(LogicAppWP/ConsosoOrders)"]
    end
    
    subgraph Analytics["Analytics Services"]
        AppInsights["Application Insights<br/>(Telemetry Collection)"]
        AspireDashboard["Aspire Dashboard<br/>(Development Monitoring)"]
    end
    
    OrdersAPI --> OrdersTopic
    
    OrdersTopic --> CreateSub
    OrdersTopic --> UpdateSub
    OrdersTopic --> ProcessSub
    OrdersTopic --> DeleteSub
    
    CreateSub --> CreateWorkflow
    UpdateSub --> UpdateWorkflow
    ProcessSub --> ProcessWorkflow
    DeleteSub --> DeleteWorkflow
    
    CreateWorkflow --> AppInsights
    UpdateWorkflow --> AppInsights
    ProcessWorkflow --> AppInsights
    DeleteWorkflow --> AppInsights
    
    CreateWorkflow --> AspireDashboard
    UpdateWorkflow --> AspireDashboard
    ProcessWorkflow --> AspireDashboard
    DeleteWorkflow --> AspireDashboard
    
    style Producers fill:#90EE90
    style EventBus fill:#FFB347
    style Consumers fill:#90EE90
    style Analytics fill:#FFE5B4
    style OrdersAPI fill:#90EE90
    style OrdersTopic fill:#FFB347
    style Subscriptions fill:#FFB347
    style CreateSub fill:#FFB347
    style UpdateSub fill:#FFB347
    style ProcessSub fill:#FFB347
    style DeleteSub fill:#FFB347
    style CreateWorkflow fill:#90EE90
    style UpdateWorkflow fill:#90EE90
    style ProcessWorkflow fill:#90EE90
    style DeleteWorkflow fill:#90EE90
    style AppInsights fill:#FFE5B4
    style AspireDashboard fill:#FFE5B4
```

### Event State Transitions

```mermaid
stateDiagram-v2
    [*] --> OrderReceived: HTTP Request to Orders API
    
    OrderReceived --> OrderValidated: Validate Order Schema
    OrderValidated --> OrderPersisted: Store in Cosmos DB (userId partition)
    OrderPersisted --> EventPublished: Publish to Service Bus Topic
    
    EventPublished --> WorkflowTriggered: Service Bus Subscription Activated
    
    WorkflowTriggered --> WorkflowRunning: Logic App Execution Start
    WorkflowRunning --> WorkflowCheckpoint: Save State (Stateful Workflow)
    WorkflowCheckpoint --> WorkflowRunning: Continue Execution
    
    WorkflowRunning --> WorkflowCompleted: Success
    WorkflowRunning --> WorkflowFailed: Error Occurred
    WorkflowRunning --> WorkflowSuspended: Long-Running Wait State
    
    WorkflowSuspended --> WorkflowRunning: Resume After Wait
    
    WorkflowCompleted --> TelemetryRecorded: Log to Application Insights
    WorkflowFailed --> ErrorHandling: Retry Policy Applied
    
    ErrorHandling --> WorkflowRunning: Retry Attempt
    ErrorHandling --> DeadLetter: Max Retries Exceeded
    
    TelemetryRecorded --> [*]
    DeadLetter --> [*]
```

---

## Technology Architecture

### Purpose
The Technology Architecture layer defines the **platforms, infrastructure, runtime environments, and supporting services** that host and operate the application components. It focuses on cloud-native patterns, containerization, serverless computing, and platform engineering practices to enable scalable, cost-effective deployments.

### Key Capabilities
- **Containerized Hosting**: Azure Container Apps for microservices and Logic Apps Standard
- **Infrastructure as Code**: Azure Bicep templates for reproducible deployments
- **Developer Platform**: .NET Aspire for local orchestration and service management
- **Observability Stack**: Application Insights, Log Analytics, OpenTelemetry SDK
- **Identity & Security**: Azure Managed Identity, Azure Key Vault

### Process (High-Level)
The solution runs on **Azure Container Apps** for hosting containerized microservices and Logic Apps, uses **.NET Aspire** for local development orchestration and service discovery, leverages **Azure PaaS services** (Cosmos DB, Service Bus, Application Insights) for data persistence and messaging, and implements **platform engineering** practices with IaC (Bicep), CI/CD pipelines, and standardized observability through ServiceDefaults.

### Cloud-Native Platform

```mermaid
flowchart LR
    subgraph Clients["Client Tier"]
        Browser["Web Browser"]
    end
    
    subgraph ApplicationServices["Application Services"]
        ContainerApps["Azure Container Apps<br/>(Managed Environment)"]
        OrdersAPIContainer["Orders API Container"]
        BlazorAppContainer["Blazor App Container"]
        LogicAppsContainers["Logic Apps Containers<br/>(CreateOrder, UpdateOrder,<br/>DeleteOrder, ProcessOrder)"]
    end
    
    subgraph MessagingServices["Messaging & Events"]
        ServiceBus["Azure Service Bus<br/>(Topics & Subscriptions)"]
    end
    
    subgraph DataServices["Data Services"]
        CosmosDB["Azure Cosmos DB<br/>(NoSQL, userId partition)"]
    end
    
    subgraph ObservabilityServices["Observability & Security"]
        AppInsights["Application Insights<br/>(OpenTelemetry)"]
        LogAnalytics["Log Analytics Workspace"]
        KeyVault["Azure Key Vault<br/>(Secrets Management)"]
        ManagedIdentity["Azure Managed Identity<br/>(Passwordless Auth)"]
    end
    
    Browser --> ContainerApps
    
    ContainerApps --> OrdersAPIContainer
    ContainerApps --> BlazorAppContainer
    ContainerApps --> LogicAppsContainers
    
    OrdersAPIContainer --> ServiceBus
    LogicAppsContainers --> ServiceBus
    
    OrdersAPIContainer --> CosmosDB
    LogicAppsContainers --> CosmosDB
    
    OrdersAPIContainer --> AppInsights
    BlazorAppContainer --> AppInsights
    LogicAppsContainers --> LogAnalytics
    
    OrdersAPIContainer --> KeyVault
    LogicAppsContainers --> ManagedIdentity
    
    style Clients fill:#ADD8E6
    style ApplicationServices fill:#90EE90
    style MessagingServices fill:#FFB347
    style DataServices fill:#FFE5B4
    style ObservabilityServices fill:#D3D3D3
    style Browser fill:#ADD8E6
    style ContainerApps fill:#90EE90
    style OrdersAPIContainer fill:#90EE90
    style BlazorAppContainer fill:#90EE90
    style LogicAppsContainers fill:#90EE90
    style ServiceBus fill:#FFB347
    style CosmosDB fill:#FFE5B4
    style AppInsights fill:#D3D3D3
    style LogAnalytics fill:#D3D3D3
    style KeyVault fill:#D3D3D3
    style ManagedIdentity fill:#D3D3D3
```

### Container-Based Architecture

```mermaid
flowchart TB
    subgraph LoadBalancer["Load Balancer"]
        Ingress["Azure Container Apps Ingress<br/>(HTTP/HTTPS)"]
    end
    
    subgraph ContainerEnvironment["Container Apps Environment"]
        subgraph Services["Container Apps Services"]
            OrdersAPISvc["Orders API Service"]
            BlazorAppSvc["Blazor App Service"]
            LogicAppsSvc["Logic Apps Service"]
        end
        
        subgraph Workloads["Container Workloads"]
            subgraph OrdersAPIPods["Orders API Replicas"]
                OrdersAPI1["API Replica 1"]
                OrdersAPI2["API Replica 2"]
            end
            
            subgraph BlazorAppPods["Blazor App Replicas"]
                BlazorApp1["App Replica 1"]
                BlazorApp2["App Replica 2"]
            end
            
            subgraph LogicAppPods["Logic Apps Replicas"]
                LogicApp1["CreateOrder Instance"]
                LogicApp2["UpdateOrder Instance"]
                LogicApp3["ProcessOrder Instance"]
                LogicApp4["DeleteOrder Instance"]
            end
        end
    end
    
    subgraph PersistentStorage["Persistent Storage"]
        CosmosDB["Cosmos DB<br/>(userId partition)"]
    end
    
    subgraph ObservabilityPlatform["Observability"]
        AppInsights["Application Insights"]
        LogAnalytics["Log Analytics"]
        AspireDashboard["Aspire Dashboard<br/>(Development)"]
    end
    
    Ingress --> OrdersAPISvc
    Ingress --> BlazorAppSvc
    
    OrdersAPISvc --> OrdersAPI1
    OrdersAPISvc --> OrdersAPI2
    
    BlazorAppSvc --> BlazorApp1
    BlazorAppSvc --> BlazorApp2
    
    LogicAppsSvc --> LogicApp1
    LogicAppsSvc --> LogicApp2
    LogicAppsSvc --> LogicApp3
    LogicAppsSvc --> LogicApp4
    
    OrdersAPI1 --> CosmosDB
    OrdersAPI2 --> CosmosDB
    LogicApp1 --> CosmosDB
    LogicApp2 --> CosmosDB
    LogicApp3 --> CosmosDB
    LogicApp4 --> CosmosDB
    
    OrdersAPI1 --> AppInsights
    OrdersAPI2 --> AppInsights
    BlazorApp1 --> AppInsights
    BlazorApp2 --> AppInsights
    LogicApp1 --> LogAnalytics
    LogicApp2 --> LogAnalytics
    LogicApp3 --> LogAnalytics
    LogicApp4 --> LogAnalytics
    
    OrdersAPISvc --> AspireDashboard
    BlazorAppSvc --> AspireDashboard
    LogicAppsSvc --> AspireDashboard
    
    style LoadBalancer fill:#E6D5FF
    style ContainerEnvironment fill:#90EE90
    style Services fill:#90EE90
    style Workloads fill:#90EE90
    style PersistentStorage fill:#FFE5B4
    style ObservabilityPlatform fill:#D3D3D3
    style Ingress fill:#E6D5FF
    style OrdersAPISvc fill:#90EE90
    style BlazorAppSvc fill:#90EE90
    style LogicAppsSvc fill:#90EE90
    style OrdersAPIPods fill:#90EE90
    style BlazorAppPods fill:#90EE90
    style LogicAppPods fill:#90EE90
    style OrdersAPI1 fill:#90EE90
    style OrdersAPI2 fill:#90EE90
    style BlazorApp1 fill:#90EE90
    style BlazorApp2 fill:#90EE90
    style LogicApp1 fill:#90EE90
    style LogicApp2 fill:#90EE90
    style LogicApp3 fill:#90EE90
    style LogicApp4 fill:#90EE90
    style CosmosDB fill:#FFE5B4
    style AppInsights fill:#D3D3D3
    style LogAnalytics fill:#D3D3D3
    style AspireDashboard fill:#D3D3D3
```

### Serverless Architecture

```mermaid
flowchart LR
    subgraph APIGateway["API Gateway"]
        AspireHost["Aspire AppHost<br/>(Development Orchestration)"]
    end
    
    subgraph Functions["Serverless Functions"]
        OrdersAPI["Orders API<br/>(Container App)"]
        LogicAppsStandard["Logic Apps Standard<br/>(Stateful Workflows)"]
    end
    
    subgraph EventSources["Event Sources"]
        ServiceBusTopic["Service Bus Topic<br/>(Orders Topic)"]
        ServiceBusSubscriptions["Service Bus Subscriptions<br/>(CreateOrder, UpdateOrder,<br/>ProcessOrder, DeleteOrder)"]
    end
    
    subgraph DataStorage["Storage Services"]
        CosmosDB["Cosmos DB<br/>(NoSQL, userId partition)"]
    end
    
    subgraph Monitoring["Monitoring Services"]
        AppInsights["Application Insights<br/>(OpenTelemetry)"]
        LogAnalytics["Log Analytics Workspace"]
    end
    
    AspireHost --> OrdersAPI
    
    ServiceBusSubscriptions --> LogicAppsStandard
    
    OrdersAPI --> ServiceBusTopic
    OrdersAPI --> CosmosDB
    
    LogicAppsStandard --> CosmosDB
    
    OrdersAPI --> AppInsights
    LogicAppsStandard --> LogAnalytics
    
    style APIGateway fill:#E6D5FF
    style Functions fill:#90EE90
    style EventSources fill:#FFB347
    style DataStorage fill:#FFE5B4
    style Monitoring fill:#D3D3D3
    style AspireHost fill:#E6D5FF
    style OrdersAPI fill:#90EE90
    style LogicAppsStandard fill:#90EE90
    style ServiceBusTopic fill:#FFB347
    style ServiceBusSubscriptions fill:#FFB347
    style CosmosDB fill:#FFE5B4
    style AppInsights fill:#D3D3D3
    style LogAnalytics fill:#D3D3D3
```

### Platform Engineering

```mermaid
flowchart TB
    subgraph DeveloperExperience["Developer Experience"]
        VSCode["Visual Studio Code<br/>(IDE)"]
        AspireDashboard["Aspire Dashboard<br/>(http://localhost:15888)"]
        LocalOrchestration["Local Orchestration<br/>(docker-compose)"]
    end
    
    subgraph InternalDeveloperPlatform["Internal Developer Platform"]
        AspireAppHost["Aspire AppHost<br/>(eShopOrders.AppHost)"]
        ServiceDefaults["Service Defaults<br/>(eShopOrders.ServiceDefaults:<br/>OpenTelemetry, Health Checks)"]
    end
    
    subgraph CICDPipelines["CI/CD & Policies"]
        BicepTemplates["Bicep IaC Templates<br/>(infra/)"]
        AzureCLI["Azure CLI Deployment"]
    end
    
    subgraph RuntimePlatforms["Runtime Platforms"]
        ContainerApps["Azure Container Apps<br/>(Hosting Environment)"]
        LogicAppsRuntime["Logic Apps Standard Runtime<br/>(Workflow Host)"]
    end
    
    subgraph SharedServices["Shared Services"]
        MonitoringStack["Monitoring Stack<br/>(Application Insights,<br/>Log Analytics)"]
        SecurityServices["Security Services<br/>(Managed Identity,<br/>Key Vault)"]
    end
    
    subgraph DataServices["Data Services"]
        CosmosDB["Cosmos DB<br/>(NoSQL Database)"]
        ServiceBus["Service Bus<br/>(Messaging)"]
    end
    
    VSCode --> AspireAppHost
    AspireDashboard --> AspireAppHost
    LocalOrchestration --> AspireAppHost
    
    AspireAppHost --> ServiceDefaults
    
    BicepTemplates --> ContainerApps
    BicepTemplates --> LogicAppsRuntime
    AzureCLI --> BicepTemplates
    
    ServiceDefaults --> MonitoringStack
    ServiceDefaults --> SecurityServices
    
    ContainerApps --> CosmosDB
    ContainerApps --> ServiceBus
    LogicAppsRuntime --> CosmosDB
    LogicAppsRuntime --> ServiceBus
    
    MonitoringStack --> ContainerApps
    MonitoringStack --> LogicAppsRuntime
    SecurityServices --> ContainerApps
    SecurityServices --> LogicAppsRuntime
    
    style DeveloperExperience fill:#ADD8E6
    style InternalDeveloperPlatform fill:#90EE90
    style CICDPipelines fill:#90EE90
    style RuntimePlatforms fill:#E6D5FF
    style SharedServices fill:#D3D3D3
    style DataServices fill:#FFE5B4
    style VSCode fill:#ADD8E6
    style AspireDashboard fill:#ADD8E6
    style LocalOrchestration fill:#ADD8E6
    style AspireAppHost fill:#90EE90
    style ServiceDefaults fill:#90EE90
    style BicepTemplates fill:#90EE90
    style AzureCLI fill:#90EE90
    style ContainerApps fill:#E6D5FF
    style LogicAppsRuntime fill:#E6D5FF
    style MonitoringStack fill:#D3D3D3
    style SecurityServices fill:#D3D3D3
    style CosmosDB fill:#FFE5B4
    style ServiceBus fill:#FFE5B4
```

---

## TOGAF Compliance Summary

This TOGAF BDAT Model strictly adheres to The Open Group Architecture Framework standards by:

1. **Business Architecture Layer**: Defining business capabilities (Order Management, Workflow Orchestration, Operational Excellence, Integration) and value streams that trace from customer demand through order fulfillment to value delivery.

2. **Data Architecture Layer**: Documenting master data management with Cosmos DB as the MDM hub (partitioned by userId), event-driven data topology through Service Bus, and comprehensive monitoring dataflow from ingestion through storage to governance.

3. **Application Architecture Layer**: Mapping the microservices architecture (Orders API, Blazor App, Logic Apps workflows) with explicit dependencies, event-driven integration patterns using Service Bus topics and subscriptions, and stateful workflow orchestration.

4. **Technology Architecture Layer**: Detailing the cloud-native platform on Azure Container Apps, container-based cluster architecture, serverless Logic Apps Standard runtime, and platform engineering practices with .NET Aspire, Bicep IaC, and OpenTelemetry observability.

All components, dependencies, and processes documented in this model are explicitly found in the provided workspace folders (infra, eShopOrders.AppHost, eShopOrders.ServiceDefaults, src, LogicAppWP). No hypothetical or assumed elements have been included.

**Identified Gaps**: 
- [MISSING COMPONENT]: CDN or Azure Front Door not explicitly configured in infrastructure templates
- [MISSING COMPONENT]: Specific CI/CD pipeline definitions (.github/workflows content not provided)

This model serves as the authoritative architecture documentation for enterprise-scale Azure Logic Apps Standard deployments, aligned with the Azure Well-Architected Framework principles of operational excellence, performance efficiency, cost optimization, and reliability.