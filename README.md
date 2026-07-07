# Multi-Agent Travel Planner — Microsoft Foundry Demo

This repository demonstrates a **multi-agent architecture** built on [Microsoft Foundry](https://learn.microsoft.com/azure/ai-services/agents/) for travel planning. An orchestrator agent coordinates specialized sub-agents — each responsible for a distinct domain — to produce comprehensive travel itineraries.

## Architecture Overview

```
┌──────────────┐         ┌─────────────────────────────┐
│   Angular    │  HTTP   │      Flight Agent API        │
│   Frontend   │────────▶│  (FastAPI + Foundry SDK)     │
└──────────────┘         └──────────┬──────────────────┘
                                    │ On-Behalf-Of flow
                                    ▼
                         ┌─────────────────────────────┐
                         │   Foundry Agent Service      │
                         │  ┌───────────────────────┐  │
                         │  │  Orchestrator Agent    │  │
                         │  └───┬───────┬───────┬───┘  │
                         │      │       │       │      │
                         │      ▼       ▼       ▼      │
                         │  Flight   Hotel  Activities  │
                         │  Agent    Agent    Agent     │
                         └────┬────────────────────────┘
                              │ MCP (OAuth 2.0)
                              ▼
                    ┌─────────────────────────┐
                    │  Flight MCP Server      │
                    │  (FastMCP + CosmosDB)   │
                    └─────────────────────────┘
```

## Agents

| Agent | Role | Tool Integration |
|-------|------|------------------|
| **Orchestrator** | Decomposes travel requests, delegates to sub-agents, synthesizes a final itinerary | Routes to specialized agents |
| **Flight Agent** | Searches and recommends flights between Canadian cities and European destinations | MCP Server (OAuth-secured) |
| **Hotel Agent** | Finds accommodation options based on city, dates, and preferences | MCP Server |
| **Activities Agent** | Suggests attractions, tours, and restaurants | REST API |

## Key Components

- **`infra/`** — Bicep IaC templates provisioned via `azd up` (Foundry project, Cosmos DB, App Service, ACR, AI Search, VNet, RBAC)
- **`src/mcp/flight-server/`** — A [FastMCP](https://github.com/jlowin/fastmcp) server exposing flight search/reservation tools, secured with Entra ID OAuth 2.0 + JWT validation
- **`src/api/flight-api/`** — FastAPI backend that proxies chat requests to the Foundry agent using On-Behalf-Of credential flow and streams responses to the frontend
- **`src/frontend/`** — Angular chat UI for interacting with the travel planner
- **`agents/`** — Agent definitions (system prompts + JSON configs) deployed to Microsoft Foundry
- **`documents/`** — Knowledge base documents (cancellation policies, loyalty program tiers) indexed via AI Search for grounding
- **`utility/`** — Scripts for loading flight data into Cosmos DB and indexing knowledge base documents

## Current Status

> **Deployed:** Flight Agent with its MCP server (flight search & reservations).  
> **Planned:** Hotel Agent, Activities Agent, and the Orchestrator that ties them together.

## Prerequisites

- Azure subscription with access to Microsoft Foundry (Azure AI Services)
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- Python 3.11+
- Node.js 18+

## Getting Started

```bash
azd auth login
azd up
```

This provisions all Azure infrastructure, builds and deploys the containers, registers the Foundry agent, loads flight data into Cosmos DB, and grants the required admin consent for OAuth flows.