#!/usr/bin/env bash
# Creates Entra ID app registrations as a post-deployment step.
# Consumes Bicep deployment outputs (webapp names) to configure correct redirect URIs and scopes.
# Workaround for: https://github.com/microsoftgraph/msgraph-bicep-types/issues/299
#
# Usage:
#   ./scripts/create-app-registrations.sh <resource-group>
#
# Prerequisites: az CLI logged in with permissions to create app registrations.

set -euo pipefail

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

RESOURCE_GROUP="${1:-rg-multi-agent-demo}"

echo -e "${CYAN}Creating app registrations (post-deployment)...${NC}"
echo -e "  Resource Group: $RESOURCE_GROUP"

# --- Discover webapp names from deployed resources ---

echo -e "\n${CYAN}Discovering webapp names from resource group...${NC}"

WEBAPPS=$(az webapp list -g "$RESOURCE_GROUP" --query "[].name" -o json)

MCP_FLIGHT_WEBAPP=$(echo "$WEBAPPS" | jq -r '.[] | select(contains("mcp-fligh-server"))' | head -1)
MCP_HOTEL_WEBAPP=$(echo "$WEBAPPS" | jq -r '.[] | select(contains("mcp-hotel"))' | head -1)
FLIGHT_API_WEBAPP=$(echo "$WEBAPPS" | jq -r '.[] | select(contains("flight-agent-api"))' | head -1)
FRONTEND_WEBAPP=$(echo "$WEBAPPS" | jq -r '.[] | select(contains("frontend"))' | head -1)

echo -e "  MCP Flight: $MCP_FLIGHT_WEBAPP"
echo -e "  MCP Hotel: $MCP_HOTEL_WEBAPP"
echo -e "  Flight API: $FLIGHT_API_WEBAPP"
echo -e "  Frontend: $FRONTEND_WEBAPP"

if [ -z "$MCP_FLIGHT_WEBAPP" ] || [ -z "$FLIGHT_API_WEBAPP" ] || [ -z "$FRONTEND_WEBAPP" ]; then
    echo -e "${RED}ERROR: Could not discover all webapp names. Ensure Bicep deployment completed.${NC}"
    exit 1
fi

# --- Helper: create or update an app registration ---

create_or_update_app() {
    local DISPLAY_NAME="$1"
    local UNIQUE_NAME="$2"
    local IDENTIFIER_URI="api://$UNIQUE_NAME"

    # Check if app already exists
    local EXISTING_APP_ID
    EXISTING_APP_ID=$(az ad app list --filter "displayName eq '$DISPLAY_NAME'" --query "[0].appId" -o tsv 2>/dev/null)

    if [ -n "$EXISTING_APP_ID" ] && [ "$EXISTING_APP_ID" != "None" ]; then
        echo -e "  ${YELLOW}App '$DISPLAY_NAME' already exists (Client ID: $EXISTING_APP_ID)${NC}"
        echo "$EXISTING_APP_ID"
        return 0
    fi

    # Create new app
    local APP_ID
    APP_ID=$(az ad app create \
        --display-name "$DISPLAY_NAME" \
        --sign-in-audience "AzureADMyOrg" \
        --identifier-uris "$IDENTIFIER_URI" \
        --query "appId" -o tsv)

    if [ -z "$APP_ID" ]; then
        echo -e "  ${RED}ERROR: Failed to create app '$DISPLAY_NAME'${NC}"
        return 1
    fi

    echo -e "  ${GREEN}Created '$DISPLAY_NAME' (Client ID: $APP_ID)${NC}"
    echo "$APP_ID"
}

# --- Helper: ensure service principal exists ---

ensure_sp() {
    local APP_ID="$1"
    local EXISTING_SP
    EXISTING_SP=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null)

    if [ -z "$EXISTING_SP" ] || [ "$EXISTING_SP" == "None" ]; then
        az ad sp create --id "$APP_ID" -o none
        echo -e "  Service principal created."
    fi
}

# --- Helper: add oauth2 permission scope ---

add_oauth2_scope() {
    local APP_ID="$1"
    local SCOPE_NAME="$2"
    local SCOPE_DESCRIPTION="$3"

    # Check if scope already exists
    local EXISTING_SCOPES
    EXISTING_SCOPES=$(az ad app show --id "$APP_ID" --query "api.oauth2PermissionScopes[?value=='$SCOPE_NAME'].value" -o tsv 2>/dev/null)

    if [ -n "$EXISTING_SCOPES" ]; then
        echo -e "  Scope '$SCOPE_NAME' already exists."
        return 0
    fi

    local SCOPE_ID
    SCOPE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || uuidgen)

    az ad app update --id "$APP_ID" \
        --set "api={\"oauth2PermissionScopes\":[{\"id\":\"$SCOPE_ID\",\"adminConsentDescription\":\"$SCOPE_DESCRIPTION\",\"adminConsentDisplayName\":\"$SCOPE_DESCRIPTION\",\"isEnabled\":true,\"type\":\"User\",\"userConsentDescription\":\"$SCOPE_DESCRIPTION\",\"userConsentDisplayName\":\"$SCOPE_DESCRIPTION\",\"value\":\"$SCOPE_NAME\"}]}" \
        -o none 2>/dev/null || true

    echo -e "  Added scope '$SCOPE_NAME'."
}

# --- Helper: set redirect URIs ---

set_web_redirect_uris() {
    local APP_ID="$1"
    shift
    local URIS=("$@")

    local URI_ARGS=""
    for uri in "${URIS[@]}"; do
        URI_ARGS="$URI_ARGS \"$uri\""
    done

    az ad app update --id "$APP_ID" \
        --web-redirect-uris ${URIS[@]} \
        -o none
}

set_spa_redirect_uris() {
    local APP_ID="$1"
    shift
    local URIS=("$@")

    az ad app update --id "$APP_ID" \
        --public-client-redirect-uris ${URIS[@]} \
        -o none 2>/dev/null || \
    az rest --method PATCH \
        --url "https://graph.microsoft.com/v1.0/applications/$(az ad app show --id $APP_ID --query id -o tsv)" \
        --body "{\"spa\":{\"redirectUris\":[$(printf '\"%s\",' "${URIS[@]}" | sed 's/,$//')]}}" \
        -o none
}

# ============================================================
# 1. Flight MCP Server
# ============================================================

echo -e "\n${CYAN}1. Flight MCP Server${NC}"
FLIGHT_MCP_CLIENT_ID=$(create_or_update_app "Flight MCP Server" "$MCP_FLIGHT_WEBAPP")
ensure_sp "$FLIGHT_MCP_CLIENT_ID"
add_oauth2_scope "$FLIGHT_MCP_CLIENT_ID" "flight_reservation_information" "Allow the application to access the flight and reservation"
set_web_redirect_uris "$FLIGHT_MCP_CLIENT_ID" \
    "https://${MCP_FLIGHT_WEBAPP}.azurewebsites.net/auth/callback" \
    "http://localhost:9000/auth/callback"

# ============================================================
# 2. Hotel MCP Server
# ============================================================

echo -e "\n${CYAN}2. Hotel MCP Server${NC}"
if [ -n "$MCP_HOTEL_WEBAPP" ] && [ "$MCP_HOTEL_WEBAPP" != "null" ]; then
    HOTEL_MCP_CLIENT_ID=$(create_or_update_app "Hotel MCP Server" "$MCP_HOTEL_WEBAPP")
    ensure_sp "$HOTEL_MCP_CLIENT_ID"
    add_oauth2_scope "$HOTEL_MCP_CLIENT_ID" "hotel_reservation_information" "Allow the application to access the hotel information"
    set_web_redirect_uris "$HOTEL_MCP_CLIENT_ID" \
        "https://${MCP_HOTEL_WEBAPP}.azurewebsites.net/auth/callback" \
        "http://localhost:9001/auth/callback"
else
    echo -e "  ${YELLOW}Hotel webapp not found - skipping.${NC}"
fi

# ============================================================
# 3. Flight Agent API
# ============================================================

echo -e "\n${CYAN}3. Flight Agent API${NC}"
FLIGHT_API_CLIENT_ID=$(create_or_update_app "Flight Agent API" "$FLIGHT_API_WEBAPP")
ensure_sp "$FLIGHT_API_CLIENT_ID"
add_oauth2_scope "$FLIGHT_API_CLIENT_ID" "user_impersonation" "Allows the app to access the API as the user"
set_web_redirect_uris "$FLIGHT_API_CLIENT_ID" \
    "https://${FLIGHT_API_WEBAPP}.azurewebsites.net" \
    "http://localhost:8000"

# ============================================================
# 4. Foundry MCP Flight Server (connection app)
# ============================================================

echo -e "\n${CYAN}4. Foundry MCP Flight Server${NC}"
# Derive the unique name using the same pattern as Bicep would
FOUNDRY_MCP_UNIQUE_NAME="foundry-mcp-flight-server-$(echo "$MCP_FLIGHT_WEBAPP" | sed 's/.*-//')"
FOUNDRY_MCP_CLIENT_ID=$(create_or_update_app "Foundry MCP Flight Server" "$FOUNDRY_MCP_UNIQUE_NAME")
ensure_sp "$FOUNDRY_MCP_CLIENT_ID"

# ============================================================
# 5. OpenAPI (Swagger UI)
# ============================================================

echo -e "\n${CYAN}5. OpenAPI${NC}"
OPENAPI_CLIENT_ID=$(create_or_update_app "OpenAPI" "openapi")
ensure_sp "$OPENAPI_CLIENT_ID"
set_spa_redirect_uris "$OPENAPI_CLIENT_ID" \
    "http://localhost:8000/oauth2-redirect" \
    "https://${FLIGHT_API_WEBAPP}.azurewebsites.net/oauth2-redirect"

# ============================================================
# 6. Front-End Chatbot Trip Reservation
# ============================================================

echo -e "\n${CYAN}6. Front-End Chatbot Trip Reservation${NC}"
FRONTEND_CLIENT_ID=$(create_or_update_app "Front-End Chatbot Trip Reservation" "$FRONTEND_WEBAPP")
ensure_sp "$FRONTEND_CLIENT_ID"
set_spa_redirect_uris "$FRONTEND_CLIENT_ID" \
    "https://${FRONTEND_WEBAPP}.azurewebsites.net" \
    "http://localhost:4200"

# ============================================================
# Summary
# ============================================================

echo -e "\n${GREEN}--- App Registration Summary ---${NC}"
echo -e "  Flight MCP Server:              $FLIGHT_MCP_CLIENT_ID"
[ -n "${HOTEL_MCP_CLIENT_ID:-}" ] && echo -e "  Hotel MCP Server:               $HOTEL_MCP_CLIENT_ID"
echo -e "  Flight Agent API:               $FLIGHT_API_CLIENT_ID"
echo -e "  Foundry MCP Flight Server:      $FOUNDRY_MCP_CLIENT_ID"
echo -e "  OpenAPI:                         $OPENAPI_CLIENT_ID"
echo -e "  Front-End Chatbot:              $FRONTEND_CLIENT_ID"
echo -e "\n${GREEN}App registration creation complete.${NC}"
