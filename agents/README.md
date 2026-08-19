# Foundry Agent Definitions

Deploys prompt agents to Microsoft Foundry via the REST API.

## Agents

| Agent | Definition | MCP Connection |
|-------|-----------|----------------|
| FlightBookingAgent | `definitions/flight-agent.json` | `flightserver-mcp` |
| HotelSearchAgent | `definitions/hotel-agent.json` | `hotelserver-mcp` |

## How It Works

`main.py` iterates over each agent definition, injects the model name and MCP server URL at runtime, and POSTs a new agent version to the Foundry project endpoint.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `FOUNDRY_PROJECT_ENDPOINT` | Foundry project URL |
| `AZURE_OPENAI_MODEL` | Model deployment name |
| `MCP_FLIGHT_SERVER_URL` | Flight MCP server endpoint |
| `MCP_HOTEL_SERVER_URL` | Hotel MCP server endpoint |

## Adding a New Agent

1. Create a JSON definition in `definitions/` (see existing files for the schema).
2. Add an entry to the `AGENTS` list in `main.py` with the definition path, env var name, and output key.
3. Add the corresponding `MCP_*_SERVER_URL` env var to `.github/workflows/deploys-agents.yaml`.
