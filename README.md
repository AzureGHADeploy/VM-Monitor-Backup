# Azure Virtual Machine Deployment with Insights and Backup

This Bicep template provisions an Azure Virtual Machine (VM) along with key operational features including **Azure Monitor VM Insights** and **Azure Backup**. The deployment is automated via a GitHub Actions workflow that securely retrieves the VM password from an **Azure Key Vault** created beforehand.

---

## 🚀 Features

- **Azure Virtual Machine**  
  Deploys a Linux-based Azure VM (Ubuntu 22.04 LTS) with customizable parameters for size, networking, and access.

- **Secure Credential Management**  
  The VM's administrator password is securely retrieved during deployment from an Azure Key Vault via GitHub Actions.

- **VM Insights with Azure Monitor**  
  Automatically enables performance monitoring and dependency mapping via the Azure Monitor Agent and Data Collection Rules. Logs are collected and stored in a Log Analytics Workspace.

- **Azure Backup Integration**  
  Configures daily backups of the VM using a defined backup policy, ensuring data protection and recovery options.

---

## 🛠️ Prerequisites

- Azure Subscription
- Azure CLI or PowerShell with Bicep CLI installed
- An existing **Azure Key Vault** containing the secret with the VM password (created before deployment)
- GitHub repository with an Actions workflow configured for Bicep deployment

---

## 🔐 Secret Handling

The GitHub Actions workflow retrieves the VM password from an **Azure Key Vault** secret (e.g., `vmAdminPassword`). This secret must be created manually or by a separate automation step **prior to the deployment**.

---

## 📈 Monitoring

- A **Log Analytics Workspace** is deployed to collect performance metrics.
- The **Azure Monitor Agent** is installed on the VM.
- A **Data Collection Rule (DCR)** and **DCR Association** are configured to pipe monitoring data to the workspace.

---

## 💾 Backup Policy

- A **Recovery Services Vault** is created to manage backups.
- An enhanced(V2) policy with **daily backup schedule** is configured with retention of:
  - **30 days** for daily backup points
  - **7 days** for instant recovery points

---

## 🧾 Parameters Overview

| Parameter | Description | Default |
|----------|-------------|---------|
| `location` | Azure region | resource group location |
| `vmName` | Virtual Machine name | `TestVM` |
| `adminUsername` | Admin username | `azureuser` |
| `adminPassword` | Admin password (secure) | *from Key Vault* |
| `vmSize` | VM size | `Standard_D2s_v3` |
| `logAnalyticsRetentionInDays` | Log retention | `30` |
| `instantRpRetentionRangeInDays` | Instant restore retention | `7` |
| `dailyRetentionCount` | Daily backup retention days | `30` |

---

## 📦 Resources Deployed

- Virtual Network and Subnet
- Network Interface and Public IP
- Network Security Group with SSH access
- Virtual Machine (Ubuntu)
- Log Analytics Workspace
- Data Collection Rule & Association
- Azure Monitor Agent
- Recovery Services Vault
- Backup Policy and Protected VM

