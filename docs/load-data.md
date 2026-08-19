# Load Data

After the infrastructure is deployed, seed the Cosmos DB database with sample flight and hotel data by running the **Load data in CosmosDB** workflow.

> **Prerequisite:** The `infra.yaml` pipeline must have completed successfully. The workflow reads `COSMOS_DB_NAME` and `AZURE_RESOURCE_GROUP` from the auto-populated repository secrets.

## What gets loaded

![Load data pipeline](../images/load-data-pipeline.excalidraw)

The `utility/data_loader.py` script loads two JSON files from `data/` into the **ContosoAgency** Cosmos DB database:

| Container | Partition Key | Documents | Source File |
|-----------|--------------|-----------|-------------|
| `flight` | `/originCountry` | 24 | `data/flights.json` |
| `hotel` | `/city` | 30 | `data/hotels.json` |

### Flights (24 documents)

Routes from Canadian cities to European destinations:

| Origin | Destinations |
|--------|-------------|
| Montreal (YUL) | Paris, London, Rome, Frankfurt, Zurich, Barcelona, Amsterdam, Lisbon |
| Toronto (YYZ) | Paris, London, Rome |

Each flight includes outbound + return flight details, pricing (CAD), cabin class, and available seats.

### Hotels (30 documents — 3 per city)

Hotels across 10 cities with a range of star ratings (3-5 stars):

Paris, London, Rome, Frankfurt, Zurich, Barcelona, Amsterdam, Lisbon, Montreal, Toronto

Each hotel includes star rating, neighborhood, price per night, guest rating, amenities, and cancellation policy.

## Processing steps

1. **Delete existing items** — Removes all documents from both containers for idempotent re-runs
2. **Shift flight dates** — Adjusts all departure/arrival times so the earliest flight departs 3 weeks from the current date (keeps the demo data always in the future)
3. **Assign UUIDs & insert** — Generates a new `id` (UUID) for each document and inserts it into Cosmos DB

## Run the pipeline

Trigger the **Load data in CosmosDB** workflow from the **Actions** tab. It uses `workflow_dispatch` (manual trigger only).

The workflow:
1. Checks out the repo
2. Sets up Python 3.11 + [uv](https://docs.astral.sh/uv/)
3. Installs dependencies from `utility/pyproject.toml`
4. Logs into Azure and retrieves the Cosmos DB connection string
5. Runs `data_loader.py`
