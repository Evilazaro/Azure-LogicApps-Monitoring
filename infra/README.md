# Infrastructure Configuration

This folder contains Azure Bicep infrastructure-as-code (IaC) files and deployment parameters.

## Files Overview

| File | Purpose | Schema |
|------|---------|--------|
| `main.bicep` | Root deployment orchestrator | Azure Bicep |
| `main.parameters.json` | Deployment parameters with environment placeholders | [ARM Parameters Schema](https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#) |
| `types.bicep` | Shared type definitions | Azure Bicep |

## Directory Structure

```
infra/
├── main.bicep              # Root deployment file
├── main.parameters.json    # Parameter values for azd
├── types.bicep             # Shared type definitions
├── data/                   # Data-related resources
├── shared/                 # Shared infrastructure
│   ├── main.bicep          # Shared resources orchestrator
│   ├── data/               # Shared data resources
│   ├── identity/           # Managed identities
│   ├── monitoring/         # App Insights, Log Analytics
│   └── network/            # Networking resources
└── workload/               # Application workloads
    ├── main.bicep          # Workload orchestrator
    ├── logic-app.bicep     # Logic App infrastructure
    ├── messaging/          # Service Bus, queues, topics
    └── services/           # API services
```

## Parameters

### main.parameters.json

| Parameter | Description | Default/Placeholder |
|-----------|-------------|---------------------|
| `location` | Azure region for deployment | `${AZURE_LOCATION}` |
| `envName` | Environment name prefix | `${AZURE_ENV_NAME}` |
| `deployerPrincipalType` | Deployer identity type | `User` |
| `deployHealthModel` | Deploy health model resources | `true` |

### Environment Variables

These Azure Developer CLI environment variables are used:

| Variable | Description |
|----------|-------------|
| `AZURE_LOCATION` | Target Azure region |
| `AZURE_ENV_NAME` | Environment name (dev, staging, prod) |
| `DEPLOYER_PRINCIPAL_TYPE` | Identity type performing deployment |
| `DEPLOY_HEALTH_MODEL` | Enable/disable health model |

## Deployment

### Using Azure Developer CLI

```bash
# Provision infrastructure
azd provision

# Deploy application
azd deploy

# Full deploy (provision + deploy)
azd up
```

### Manual Deployment

```bash
az deployment sub create \
  --location <location> \
  --template-file main.bicep \
  --parameters main.parameters.json
```

## Related Documentation

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [ARM Template Parameters](https://learn.microsoft.com/azure/azure-resource-manager/templates/parameters)
