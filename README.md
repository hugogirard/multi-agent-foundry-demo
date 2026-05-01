# Multi-Agent Travel Planner on Azure AI Foundry

A multi-agent orchestration demo built on **Azure AI Foundry** that coordinates specialized AI agents to create complete travel itineraries. An orchestrator agent delegates tasks to flight, hotel, and activities specialists, then synthesizes their responses into a unified travel plan.

## Architecture

### Infrastructure

```mermaid
graph TB
    subgraph RG["Azure Resource Group"]
        subgraph VNet["Virtual Network (192.168.0.0/16)"]
            subgraph Subnet["Agent Subnet (192.168.1.0/24)"]
                FoundryAccount["Azure AI Foundry Account<br/>(S0 - AI Services)"]
            end
        end

        subgraph Project["Foundry Project: Travel Planner"]
            Orchestrator["Orchestrator Agent"]
            FlightAgent["Flight Agent"]
            HotelAgent["Hotel Agent"]
            ActivitiesAgent["Activities Agent"]
        end

        Storage["Azure Storage Account<br/>(Standard_GRS)"]
        CosmosDB["Azure Cosmos DB<br/>(Thread Storage)"]
        AISearch["Azure AI Search<br/>(Basic - Vector Store)"]
        LogAnalytics["Log Analytics Workspace"]
        Identity["User-Assigned<br/>Managed Identity"]
        NSG["Network Security Group"]
    end

    FoundryAccount --> Project
    Project --> Storage
    Project --> CosmosDB
    Project --> AISearch
    FoundryAccount --> LogAnalytics
    Subnet --> NSG
    Identity -.-> FoundryAccount

    classDef ai fill:#4A90D9,stroke:#2E6BA6,color:#fff
    classDef data fill:#50B748,stroke:#3A8A35,color:#fff
    classDef network fill:#F5A623,stroke:#C4841C,color:#fff
    classDef monitor fill:#9B59B6,stroke:#7D3C98,color:#fff

    class FoundryAccount,Project,Orchestrator,FlightAgent,HotelAgent,ActivitiesAgent ai
    class Storage,CosmosDB,AISearch data
    class VNet,Subnet,NSG network
    class LogAnalytics,Identity monitor
```

### Agent Interaction Flow

```mermaid
sequenceDiagram
    participant User
    participant Orchestrator
    participant FlightAgent as Flight Agent<br/>(MCP Server)
    participant HotelAgent as Hotel Agent<br/>(MCP Server)
    participant ActivitiesAgent as Activities Agent<br/>(REST API)

    User->>Orchestrator: Travel request (destination, dates, budget)
    
    Note over Orchestrator: Extracts parameters & splits budget<br/>~40% flights | ~35% hotels | ~25% activities

    par Delegate to specialists
        Orchestrator->>FlightAgent: search_flights(origin, dest, dates, budget)
        Orchestrator->>HotelAgent: search_hotels(city, dates, guests, budget)
        Orchestrator->>ActivitiesAgent: GET /api/activities/search & /api/restaurants/search
    end

    FlightAgent-->>Orchestrator: Ranked flight options + recommendation
    HotelAgent-->>Orchestrator: Ranked hotel options + recommendation
    ActivitiesAgent-->>Orchestrator: Daily activity schedule

    Orchestrator-->>User: Complete travel itinerary
```

## What Is Deployed

| Resource | SKU / Tier | Purpose |
|----------|-----------|---------|
| **Azure AI Foundry Account** | S0 (AI Services) | Hosts the multi-agent project with network injection on the agent subnet |
| **Foundry Project** | — | "Travel Planner" project containing all 4 agents and their connections |
| **Azure AI Search** | Basic | Vector store for agent knowledge retrieval (1 partition, 1 replica) |
| **Azure Cosmos DB** | GlobalDocumentDB | Thread and conversation history storage (AAD auth, 10,000 RU limit) |
| **Azure Storage Account** | Standard_GRS | Blob storage for project artifacts and vector data |
| **Virtual Network** | — | `192.168.0.0/16` with agent subnet `192.168.1.0/24` delegated to `Microsoft.App/environments` |
| **Network Security Group** | — | Applied to agent subnet (default rules) |
| **Log Analytics Workspace** | PerGB2018 | Centralized logging (30-day retention, 10 GB/day cap) |
| **User-Assigned Managed Identity** | — | Identity for Foundry resource access |
| **RBAC Role Assignments** | — | Storage Blob Data Contributor/Owner, Search Index/Service Contributor, Cosmos DB Operator |

> **Note:** This deployment uses dev/test SKUs (Basic AI Search, S0 AI Services) with public network access enabled. It is not intended for production workloads.

## Agent Architecture

| Agent | Tool Type | Tool / Endpoint | Description |
|-------|-----------|-----------------|-------------|
| **Orchestrator** | None (coordinator) | — | Decomposes travel requests, extracts parameters, splits budget, delegates to specialists, and synthesizes the final itinerary |
| **Flight Agent** | MCP Server | `flights-server` → `search_flights` | Searches flights by origin/destination, dates, cabin class, and budget. Returns ranked options with pricing |
| **Hotel Agent** | MCP Server | `hotels-server` → `search_hotels` | Searches hotels by city, dates, star rating, amenities, and budget. Returns ranked options with ratings |
| **Activities Agent** | REST API | `GET /api/activities/search`<br/>`GET /api/restaurants/search` | Searches activities and restaurants by city, interests, and budget. Returns a daily schedule organized by time of day |

All agents currently use **mock data** from `agents/mock-data/` (flights.json, hotels.json, activities.json) for demonstration purposes.

## Prerequisites

Install the following tools on your machine before deploying:

| Tool | Version | Install |
|------|---------|---------|
| **Azure Developer CLI (`azd`)** | v1.x+ | [Install azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| **Azure CLI (`az`)** | Latest | [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| **PowerShell 7+** (`pwsh`) | 7.x+ | [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| **Git** | Latest | [Install Git](https://git-scm.com/downloads) |

**Azure requirements:**
- An Azure subscription with **Contributor** or **Owner** role
- A region that supports Azure AI Foundry (e.g., East US, West US 2, Sweden Central, West Europe)

## Deployment

### 1. Clone the repository

```bash
git clone https://github.com/<your-org>/multi-agent-foundry-demo.git
cd multi-agent-foundry-demo
```

### 2. Authenticate

```bash
azd auth login
```

### 3. Deploy infrastructure and agents

```bash
azd up
```

You will be prompted for:
- **Environment name** — a unique name for this deployment (used in resource naming)
- **Azure subscription** — the target subscription
- **Azure location** — the region to deploy to (must support Azure AI Foundry)

This command will:
1. Provision all Azure resources defined in `infra/main.bicep`
2. Run the **post-provision hook** (`scripts/postprovision.ps1`) which configures the project-level capability host with:
   - Vector store connection → Azure AI Search
   - Storage connection → Azure Storage Account
   - Thread storage → Azure Cosmos DB

### 4. Verify deployment

Once complete, navigate to [Azure AI Foundry Studio](https://ai.azure.com) and open the **Travel Planner** project to interact with the agents.

## Clean Up

To delete all deployed resources:

```bash
azd down
```

Or use the included cleanup script to remove resource groups matching the environment pattern:

```powershell
./cleanup-resource-groups.ps1
```

## Project Structure

```
├── azure.yaml                  # Azure Developer CLI project configuration
├── infra/
│   ├── main.bicep              # Main infrastructure template
│   ├── main.parameters.json    # Parameter definitions
│   └── core/
│       ├── ai/                 # Foundry account, project, capability hosts
│       ├── identity/           # User-assigned managed identity
│       ├── monitoring/         # Log Analytics workspace
│       ├── networking/         # VNet, subnet, NSG
│       └── rbac/               # Role assignments
├── agents/
│   ├── orchestrator.md         # Orchestrator agent instructions
│   ├── flight-agent.md         # Flight specialist instructions
│   ├── hotel-agent.md          # Hotel specialist instructions
│   ├── activities-agent.md     # Activities specialist instructions
│   └── mock-data/              # Sample data for agent tools
└── scripts/
    └── postprovision.ps1       # Post-deployment capability host setup
```

## License

See [LICENSE](LICENSE) for details.
