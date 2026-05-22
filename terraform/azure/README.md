# Azure Terraform Path

The Azure path deploys the Quantum Bank containers to Azure Container Apps.

## Provider

- `hashicorp/azurerm` pinned to the `~> 4.0` major line.

## Inputs

Set `location`, `resource_group_name`, and container image values for the target
environment. The root creates a resource group, Log Analytics workspace,
Container Apps environment, and Container Apps for backend and gateways.

The backend has no public ingress. Gateway ingress is public; the banking
gateway requires client certificates at the Container Apps ingress layer.
Environment overlays should add Key Vault references, DNS, managed certificates,
and private networking policies.
