# ⚡ Serverless M365 User Offboarding Automation

![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)
![Microsoft Graph](https://img.shields.io/badge/Microsoft_Graph-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)

## 🚀 Overview

This repository contains a 100% serverless, zero-trust automation pipeline for Microsoft 365 user offboarding. Designed to replace manual HR offboarding checklists, this solution leverages Azure Logic Apps and Azure Automation to instantly secure the accounts of departing employees, preserve critical business data, and immediately reclaim licensing costs. 

## ⚙️ How It Works

The pipeline is built on an event-driven architecture that flows from a simple HTTP trigger to full cloud execution, completely hands-free.

1. **🔔 The Trigger:** An HR system or IT admin sends a standard JSON payload (containing the Target UPN, Manager UPN, and forwarding preferences) to an Azure Logic App Webhook.
2. **🧠 The Orchestrator:** The Logic App parses the incoming data, formats it, and signals an Azure Automation Runbook to spin up a cloud worker node.
3. **🔐 The Execution:** The PowerShell Runbook authenticates silently against Microsoft Graph and Exchange Online using a highly privileged, passwordless **System-Assigned Managed Identity**.
4. **🛑 The Decommissioning:** The script executes a rapid succession of API calls to terminate sessions, convert data structures, and strip licenses before gracefully shutting down.

## ✨ Core Capabilities

* **Zero-Trust Authentication:** Relies entirely on Managed Identities and Certificate-Based Authentication (CBA). No service account passwords or hardcoded secrets are used. 🛡️
* **Instant Containment:** Instantly disables the Entra ID account, revokes all active sign-in sessions (`Revoke-MgUserSignInSession`), and strips global admin roles. 🚫
* **Smart Data Retention:** Converts the user's mailbox to a **Shared Mailbox** *before* removing licenses, preserving all historical data and ensuring incoming emails don't bounce, all without costing a monthly fee. 🗄️
* **Seamless Handoff:** Automatically hides the user from the Global Address List (GAL), configures custom auto-replies, sets up forwarding, and grants the user's manager `FullAccess` to the historical inbox. 🤝
* **FinOps (Cost Savings):** Recursively strips all M365 user licenses (like E3/E5) returning them to the available pool to prevent billing waste. 💰
* **Simulation Mode:** Includes a `DryRun` boolean parameter allowing IT to simulate the offboarding sequence and generate logs without actually altering the user's account. 🧪

## 📂 Repository Files

These scripts power the different phases of the deployment and execution architecture:

* `automated-user-offboarding.ps1` - The core PowerShell execution script hosted inside the Azure Automation Runbook. 
* `logic-app-trigger-webhook.ps1` - A local utility script used to generate the JSON payload and fire the Logic App webhook to initiate the process.
* `managed-identity-permissions.ps1` - Infrastructure-as-Code script used to programmatically grant the required Microsoft Graph API scopes to the Automation Account's Managed Identity.
* `exchange-online-permissions-api.ps1` - A specialized script used to bypass Azure GUI limitations and forcefully inject the hidden `Exchange.ManageAsApp` API permission, allowing the Managed Identity to authenticate natively with Exchange Online.
