#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# register-mcp-server.sh
# ---------------------------------------------------------------------------
# Registers the MCP Hotel Server as a passthrough MCP server in Azure API
# Management using the REST API (az rest).
#
# The JSON payload is read from gateway/mcp/hotel/hotel.mcp.json with a
# __BACKEND_URL__ placeholder that is substituted at runtime.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/api-management/manage-mcp-servers-rest-api
#
# Usage:
#   ./scripts/register-mcp-server.sh <resource-group>
#
# Prerequisites: az CLI logged in with permissions to manage API Management.

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Constants ---
MCP_SERVER_ID="contoso-hotel-mcp"
PRODUCT_ID="contoso-airline"
API_VERSION="2025-09-01-preview"

# --- Resolve script directory and repo root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PAYLOAD_FILE="${REPO_ROOT}/gateway/mcp/hotel/hotel.mcp.json"

# --- Arguments ---
RESOURCE_GROUP="${1:?Usage: $0 <resource-group>}"

echo -e "${CYAN}Registering MCP Hotel Server in API Management...${NC}"
echo -e "  Resource Group: ${RESOURCE_GROUP}"

# --- Auto-detect subscription ---
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "  Subscription:   ${SUBSCRIPTION_ID}"

# --- Discover APIM service name ---
echo -e "\n${CYAN}Discovering API Management service...${NC}"
APIM_NAME=$(az apim list -g "${RESOURCE_GROUP}" --query "[0].name" -o tsv)
if [[ -z "${APIM_NAME}" ]]; then
  echo -e "${RED}ERROR: No API Management service found in resource group '${RESOURCE_GROUP}'.${NC}"
  exit 1
fi
echo -e "  APIM Name:      ${APIM_NAME}"

# --- Discover Hotel MCP webapp ---
echo -e "\n${CYAN}Discovering Hotel MCP Server webapp...${NC}"
MCP_HOTEL_WEBAPP_NAME=$(az webapp list -g "${RESOURCE_GROUP}" \
  --query "[?contains(name,'mcp-hotel')].name | [0]" -o tsv)
if [[ -z "${MCP_HOTEL_WEBAPP_NAME}" ]]; then
  echo -e "${RED}ERROR: No webapp matching '*mcp-hotel*' found in resource group '${RESOURCE_GROUP}'.${NC}"
  exit 1
fi
BACKEND_URL="https://${MCP_HOTEL_WEBAPP_NAME}.azurewebsites.net"
echo -e "  Webapp:         ${MCP_HOTEL_WEBAPP_NAME}"
echo -e "  Backend URL:    ${BACKEND_URL}"

# --- Build base URI ---
BASE="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}"

# --- Load and hydrate JSON payload ---
echo -e "\n${CYAN}Loading payload from ${PAYLOAD_FILE}...${NC}"
if [[ ! -f "${PAYLOAD_FILE}" ]]; then
  echo -e "${RED}ERROR: Payload file not found: ${PAYLOAD_FILE}${NC}"
  exit 1
fi
BODY=$(sed "s|__BACKEND_URL__|${BACKEND_URL}|g" "${PAYLOAD_FILE}")

# --- 1. Create the passthrough MCP server ---
echo -e "\n${CYAN}[1/3] Creating passthrough MCP server '${MCP_SERVER_ID}'...${NC}"
az rest --method PUT \
  --uri "${BASE}/apis/${MCP_SERVER_ID}?api-version=${API_VERSION}" \
  --headers "If-Match=*" \
  --body "${BODY}"
echo -e "${GREEN}  ✓ MCP server created/updated.${NC}"

# --- 2. Attach rate-limit policy ---
echo -e "\n${CYAN}[2/3] Applying rate-limit policy...${NC}"
az rest --method PUT \
  --uri "${BASE}/apis/${MCP_SERVER_ID}/policies/policy?api-version=${API_VERSION}" \
  --headers "If-Match=*" \
  --body '{
    "properties": {
      "format": "rawxml",
      "value": "<policies><inbound><base /><rate-limit calls=\"100\" renewal-period=\"60\" /></inbound><backend><forward-request /></backend><outbound><base /></outbound></policies>"
    }
  }'
echo -e "${GREEN}  ✓ Rate-limit policy applied.${NC}"

# --- 3. Bind to product ---
echo -e "\n${CYAN}[3/3] Binding MCP server to product '${PRODUCT_ID}'...${NC}"
az rest --method PUT \
  --uri "${BASE}/products/${PRODUCT_ID}/apis/${MCP_SERVER_ID}?api-version=${API_VERSION}"
echo -e "${GREEN}  ✓ Product binding created.${NC}"

# --- Verify ---
echo -e "\n${CYAN}Verifying MCP server registration...${NC}"
az rest --method GET \
  --uri "${BASE}/apis/${MCP_SERVER_ID}?api-version=${API_VERSION}" \
  --query "{name: name, displayName: properties.displayName, path: properties.path, serviceUrl: properties.serviceUrl, transportType: properties.mcpProperties.transportType}"

echo -e "\n${GREEN}MCP Hotel Server registration complete.${NC}"