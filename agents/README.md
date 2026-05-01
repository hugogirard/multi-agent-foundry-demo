# Multi-Agent Travel Planner — Architecture & Guide

A multi-agent demo featuring **1 orchestrator + 3 specialized agents** that coordinate to build complete travel itineraries. Two agents use MCP servers for tool access, and one uses a standard REST API.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER REQUEST                            │
│   "Plan a 5-day trip to Paris from NYC, July, 2 people, $3000" │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR AGENT                           │
│  • Decomposes request into sub-tasks                            │
│  • Routes to specialized agents                                 │
│  • Synthesizes final itinerary                                  │
└────────┬──────────────────────┬──────────────────────┬──────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐
│  FLIGHT AGENT   │  │  HOTEL AGENT    │  │  ACTIVITIES AGENT   │
│                 │  │                 │  │                     │
│  Tool: MCP      │  │  Tool: MCP      │  │  Tool: REST API     │
│  Server:        │  │  Server:        │  │  Endpoints:         │
│  flights-server │  │  hotels-server  │  │  /api/activities    │
│                 │  │                 │  │  /api/restaurants   │
└────────┬────────┘  └────────┬────────┘  └──────────┬──────────┘
         │                    │                      │
         ▼                    ▼                      ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐
│  Mock: flights  │  │  Mock: hotels   │  │  Mock: activities   │
│  .json          │  │  .json          │  │  .json              │
└─────────────────┘  └─────────────────┘  └─────────────────────┘
```

---

## Agent Descriptions

### Orchestrator (`orchestrator.md`)

The coordinator agent. It does NOT call any external tools itself. Instead, it:
- Parses user travel requests
- Extracts key parameters (origin, destination, dates, budget, travelers)
- Splits budget across agents (~40% flights, ~35% hotels, ~25% activities)
- Delegates sub-tasks to specialized agents
- Collects all responses and synthesizes a unified day-by-day itinerary

### Flight Agent (`flight-agent.md`)

Searches for flight options using the **`flights-server` MCP server**.

- **MCP Tool**: `search_flights`
- **Inputs**: origin, destination, dates, passengers, cabin class, budget
- **Returns**: Ranked flight options with a recommendation

### Hotel Agent (`hotel-agent.md`)

Searches for accommodation using the **`hotels-server` MCP server**.

- **MCP Tool**: `search_hotels`
- **Inputs**: city, check-in/out dates, guests, budget per night, star rating, amenities
- **Returns**: Ranked hotel options with a recommendation

### Activities Agent (`activities-agent.md`)

Suggests activities and restaurants using a **standard REST API** (not MCP).

- **REST Endpoints**: `GET /api/activities/search`, `GET /api/restaurants/search`
- **Inputs**: city, interests, budget, dates, group size, cuisine preferences
- **Returns**: Daily activity/dining schedule organized by time of day

---

## Tool Types Explained

### MCP (Model Context Protocol) Servers

MCP servers expose tools that AI agents can call directly. The agent sends a structured request to a named tool, and the server returns structured data.

**Used by**: Flight Agent (`flights-server`), Hotel Agent (`hotels-server`)

```
Agent → MCP Server → Tool: search_flights → Structured JSON response
```

### REST API

Standard HTTP endpoints that the agent calls using GET/POST requests with query parameters or request bodies. This is a traditional API integration.

**Used by**: Activities Agent (`/api/activities/search`, `/api/restaurants/search`)

```
Agent → HTTP GET /api/activities/search?city=Paris&interests=art → JSON response
```

---

## Mock Data

All agents currently return **mock data** from JSON files in `mock-data/`:

| File | Contents |
|------|----------|
| `mock-data/flights.json` | 5 flight options (Air France, Delta, United, BA) NYC→Paris |
| `mock-data/hotels.json` | 5 hotels (2★ to 5★) across Paris neighborhoods |
| `mock-data/activities.json` | 8 activities + 6 restaurants in Paris |

Mock data represents a Paris trip in July 2026 for 2 people.

---

## Testing the Chaining (Step-by-Step)

### Step 1: User Input
Send this request to the Orchestrator:
> "Plan a 5-day trip to Paris from New York, July 10-15, 2 people, total budget $3000"

### Step 2: Orchestrator Decomposes
The Orchestrator extracts:
- Origin: JFK (New York)
- Destination: CDG (Paris)
- Dates: July 10–15, 2026
- Travelers: 2
- Budget split: Flights ~$1200, Hotels ~$1050, Activities ~$750

### Step 3: Orchestrator → Flight Agent
```json
{
  "agent": "flight-agent",
  "task": "Search round-trip flights",
  "parameters": {
    "origin": "JFK",
    "destination": "CDG",
    "departure_date": "2026-07-10",
    "return_date": "2026-07-15",
    "passengers": 2,
    "cabin_class": "economy",
    "max_budget_per_person": 600
  }
}
```

**Flight Agent responds** (from mock data):
- Recommended: Air France AF007, $485/person, 7.25h non-stop
- Alternatives: Delta $520, United $498, BA $410 (1 stop)
- Total for 2: $970

### Step 4: Orchestrator → Hotel Agent
```json
{
  "agent": "hotel-agent",
  "task": "Search hotels in Paris",
  "parameters": {
    "city": "Paris",
    "check_in": "2026-07-10",
    "check_out": "2026-07-15",
    "guests": 2,
    "rooms": 1,
    "max_budget_per_night": 210
  }
}
```

**Hotel Agent responds** (from mock data):
- Recommended: Hôtel Le Marais Charm, 4★, $195/night, total $975
- Alternatives: Ibis Styles $130/night, Hôtel Saint-Germain $220/night

### Step 5: Orchestrator → Activities Agent
```json
{
  "agent": "activities-agent",
  "task": "Suggest activities and restaurants",
  "parameters": {
    "city": "Paris",
    "interests": "art,history,food",
    "budget_per_person": 375,
    "date_from": "2026-07-10",
    "date_to": "2026-07-15",
    "group_size": 2
  }
}
```

**Activities Agent responds** (from mock data):
- 5-day schedule with morning activities, lunch, afternoon activities, dinner
- Highlights: Louvre, Eiffel Tower, Versailles, French Cooking Class
- Total per person: ~$340 (activities + dining)

### Step 6: Orchestrator Synthesizes

The Orchestrator combines all responses into a final itinerary:

```
═══════════════════════════════════════════════
  PARIS TRAVEL ITINERARY — July 10-15, 2026
═══════════════════════════════════════════════

✈️  FLIGHTS: Air France AF007/AF008
    NYC (JFK) → Paris (CDG)
    Depart: Jul 10, 6:30PM → Arrive: Jul 11, 7:45AM
    Return: Jul 15, 10:00AM → Arrive: Jul 15, 1:15PM
    Cost: $970 (2 passengers)

🏨  HOTEL: Hôtel Le Marais Charm ★★★★
    Le Marais, Paris | 5 nights
    Cost: $975

📅  DAY-BY-DAY:

    Day 1 (Jul 11): Arrive + Settle In
    • Morning: Check in, rest
    • Lunch: Breizh Café (crêpes, $20/pp)
    • Afternoon: Latin Quarter Evening Walk (free)
    • Dinner: Le Bouillon Chartier ($25/pp)

    Day 2 (Jul 12): Art & Culture
    • Morning: Louvre Museum ($22/pp, 3.5h)
    • Lunch: L'As du Fallafel ($12/pp)
    • Afternoon: Seine River Cruise ($18/pp, 1h)
    • Dinner: Pink Mamma ($28/pp)

    Day 3 (Jul 13): Montmartre & Heights
    • Morning: Montmartre Walking Tour ($30/pp, 2.5h)
    • Lunch: Café de Flore ($35/pp)
    • Afternoon: Musée d'Orsay ($16/pp, 2.5h)
    • Dinner: Le Comptoir de la Gastronomie ($55/pp)

    Day 4 (Jul 14): Versailles Excursion
    • Full Day: Palace of Versailles ($55/pp, 6h)
    • Dinner: Le Bouillon Chartier ($25/pp)

    Day 5 (Jul 15): Farewell
    • Morning: French Cooking Class ($85/pp, 3h)
    • Depart for airport

💰  BUDGET BREAKDOWN:
    Flights:    $970
    Hotel:      $975
    Activities: $548 (2 people)
    Dining:     $490 (2 people)
    ─────────────────
    TOTAL:      $2,983 ✓ (under $3,000 budget)
═══════════════════════════════════════════════
```

---

## File Structure

```
agents/
├── README.md                  ← You are here
├── orchestrator.md            ← Orchestrator agent system prompt
├── flight-agent.md            ← Flight agent + MCP tool definition
├── hotel-agent.md             ← Hotel agent + MCP tool definition
├── activities-agent.md        ← Activities agent + REST API definition
└── mock-data/
    ├── flights.json           ← 5 mock flight options
    ├── hotels.json            ← 5 mock hotel options
    └── activities.json        ← 8 activities + 6 restaurants
```

---

## Future Enhancements

- **Real MCP Servers**: Implement actual MCP servers (Node.js/Python) that call flight/hotel APIs
- **Real REST API**: Deploy an Azure Function or Container App for the activities endpoint
- **Azure Deployment**: Use the existing `infra/` Bicep templates to deploy MCP servers as Container Apps
- **Memory/State**: Add conversation history so the orchestrator can handle follow-up requests
- **User Preferences**: Store traveler profiles (dietary restrictions, mobility needs, interests)
- **Parallel Execution**: Have the orchestrator call all 3 agents simultaneously rather than sequentially
- **Error Recovery**: Implement fallback strategies when an agent fails or returns no results
