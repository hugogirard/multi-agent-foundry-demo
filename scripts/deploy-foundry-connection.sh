#!/usr/bin/env bash
# Post-provision hook: creates a client secret for the MCP Flight Server app registration
# and deploys the Foundry MCP connection via Azure CLI REST API.
#
# Required environment variables:
#   FOUNDRY_CONNECTION_MCP_CLIENT_ID
#   AZURE_RESOURCE_GROUP
#   MCP_FLIGHT_WEBAPP_NAME
#   FOUNDRY_RESOURCE_NAME
#   PROJECT_NAME
#
# Optional (auto-detected if not set):
#   TENANT_ID
#   SUBSCRIPTION_ID

set -euo pipefail

# --- Resolve configuration ---

clientId="${FOUNDRY_CONNECTION_MCP_CLIENT_ID:?Missing FOUNDRY_CONNECTION_MCP_CLIENT_ID}"
resourceGroup="${AZURE_RESOURCE_GROUP:?Missing AZURE_RESOURCE_GROUP}"
webAppName="${MCP_FLIGHT_WEBAPP_NAME:?Missing MCP_FLIGHT_WEBAPP_NAME}"
foundryResourceName="${FOUNDRY_RESOURCE_NAME:?Missing FOUNDRY_RESOURCE_NAME}"
projectName="${PROJECT_NAME:?Missing PROJECT_NAME}"
tenantId="${TENANT_ID:-$(az account show --query tenantId -o tsv)}"
subscriptionId="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"

loginEndpoint=$(az cloud show --query endpoints.activeDirectory -o tsv)
loginEndpoint="${loginEndpoint%/}"
tokenUrl="$loginEndpoint/$tenantId/oauth2/v2.0/token"
authUrl="$loginEndpoint/$tenantId/oauth2/v2.0/authorize"
scopes="api://$webAppName/flight_reservation_information"

echo "Deploying Foundry MCP connection..."
echo "  Resource Group: $resourceGroup"
echo "  Foundry Resource: $foundryResourceName"
echo "  Project: $projectName"
echo "  MCP Web App: $webAppName"
echo "  Client ID: $clientId"
echo "  Tenant ID: $tenantId"

# --- Create/regenerate app registration secret for Foundry connection ---

# Look up the app's object ID from its appId (clientId)
appObjectId=$(az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/applications?\$filter=appId eq '$clientId'&\$select=id" \
  --query "value[0].id" -o tsv)

if [ -z "$appObjectId" ]; then
  echo "ERROR: Could not find app registration with clientId=$clientId" >&2
  exit 1
fi

echo "Creating new 'Foundry MCP Connection' credential..."
addBody='{"passwordCredential":{"displayName":"Foundry MCP Connection"}}'
addTmp=$(mktemp)
echo "$addBody" > "$addTmp"

secretValue=$(az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/applications/$appObjectId/addPassword" \
  --body "@$addTmp" \
  --headers "Content-Type=application/json" \
  --query "secretText" -o tsv)

rm -f "$addTmp"

if [ -z "$secretValue" ]; then
  echo "ERROR: Failed to create app registration secret." >&2
  exit 1
fi

# Mask secret in GitHub Actions logs
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  echo "::add-mask::$secretValue"
fi

echo "Secret created successfully."

# --- Create/update connection via REST API at project level ---

connectionName="flightserver-mcp"
connectionUrl="https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.CognitiveServices/accounts/$foundryResourceName/projects/$projectName/connections/${connectionName}?api-version=2025-06-01"

body=$(cat <<EOF
{
  "type": "Microsoft.CognitiveServices/accounts/projects/connections",
  "name": "$connectionName",
  "properties": {
    "authType": "OAuth2",
    "category": "RemoteTool",
    "target": "https://$webAppName.azurewebsites.net/mcp",
    "useWorkspaceManagedIdentity": false,
    "isSharedToAll": false,
    "credentials": {
      "clientId": "$clientId",
      "clientSecret": "$secretValue"
    },
    "metadata": {
      "type": "custom_MCP"
    },
    "tokenUrl": "$tokenUrl",
    "authorizationUrl": "$authUrl",
    "refreshUrl": "$tokenUrl",
    "scopes": ["$scopes"]
  }
}
EOF
)

tempFile=$(mktemp)
echo "$body" > "$tempFile"

echo "Creating connection via REST API..."
connectionResponse=$(az rest --method PUT \
  --url "$connectionUrl" \
  --body "@$tempFile" \
  --headers "Content-Type=application/json" \
  -o json) || { echo "ERROR: Failed to create Foundry MCP connection." >&2; rm -f "$tempFile"; exit 1; }

rm -f "$tempFile"

echo "Foundry MCP connection deployed successfully."

# --- Add redirect URL from connection response to app registration ---

# Try multiple known property paths for the redirect URL
redirectUrl=$(echo "$connectionResponse" | jq -r '
  .properties.metadata.redirectUrl //
  .properties.metadata.RedirectUrl //
  .properties.metadata.redirect_url //
  .properties.metadata.RedirectUri //
  .properties.redirectUrl //
  empty' 2>/dev/null || true)

if [ -z "$redirectUrl" ]; then
  echo "No redirectUrl found in PUT response. Fetching connection via GET..."
  getResponse=$(az rest --method GET --url "$connectionUrl" -o json)

  # Show metadata keys for debugging
  echo "  Connection metadata keys: $(echo "$getResponse" | jq -r '.properties.metadata | keys | join(", ")')"

  # Try known property names
  redirectUrl=$(echo "$getResponse" | jq -r '
    .properties.metadata.redirectUrl //
    .properties.metadata.RedirectUrl //
    .properties.metadata.redirect_url //
    .properties.metadata.RedirectUri //
    .properties.redirectUrl //
    .properties.credentials.redirectUrl //
    .properties.credentials.RedirectUrl //
    empty' 2>/dev/null || true)

  # Search metadata values for the consent URL pattern
  if [ -z "$redirectUrl" ]; then
    redirectUrl=$(echo "$getResponse" | jq -r '
      [.properties.metadata | to_entries[] |
       select(.value | type == "string" and startswith("https://global.consent.azure-apim.net/redirect/")) |
       .value] | first // empty' 2>/dev/null || true)
    if [ -n "$redirectUrl" ]; then
      echo "  Found redirect URL in metadata: $redirectUrl"
    fi
  fi

  # Search top-level properties for the consent URL pattern
  if [ -z "$redirectUrl" ]; then
    redirectUrl=$(echo "$getResponse" | jq -r '
      [.properties | to_entries[] |
       select(.value | type == "string" and startswith("https://global.consent.azure-apim.net/redirect/")) |
       .value] | first // empty' 2>/dev/null || true)
    if [ -n "$redirectUrl" ]; then
      echo "  Found redirect URL in properties: $redirectUrl"
    fi
  fi

  # Last resort: dump full response for debugging
  if [ -z "$redirectUrl" ]; then
    echo "WARNING: Could not find redirect URL in any known property. Full response:" >&2
    echo "$getResponse"
  fi
fi

if [ -n "$redirectUrl" ]; then
  echo "Redirect URL from connection: $redirectUrl"

  # Get existing web redirect URIs via Graph REST API
  existingUris=$(az rest --method GET \
    --url "https://graph.microsoft.com/v1.0/applications/${appObjectId}?\$select=web" \
    --query "web.redirectUris" -o json)

  # Build new URI list: remove stale consent URIs, add current one, deduplicate
  allUris=$(echo "$existingUris" | jq --arg new "$redirectUrl" '
    [.[] | select(startswith("https://global.consent.azure-apim.net/redirect/") | not)] + [$new] | unique')

  # Check if update is needed
  needsUpdate=$(jq -n --argjson existing "$existingUris" --argjson updated "$allUris" '
    if ($existing | sort) == ($updated | sort) then "no" else "yes" end' -r)

  if [ "$needsUpdate" = "no" ]; then
    echo "Redirect URL already present in app registration. Skipping update."
  else
    echo "Updating app registration redirect URIs (replacing stale consent URI)..."
    echo "  New URIs: $(echo "$allUris" | jq -r 'join(", ")')"

    patchPayload=$(jq -n --argjson uris "$allUris" '{"web":{"redirectUris":$uris}}')
    patchTmp=$(mktemp)
    echo "$patchPayload" > "$patchTmp"

    az rest --method PATCH \
      --url "https://graph.microsoft.com/v1.0/applications/$appObjectId" \
      --body "@$patchTmp" \
      --headers "Content-Type=application/json" || {
        echo "ERROR: Failed to update app registration with redirect URL." >&2
        rm -f "$patchTmp"
        exit 1
      }

    rm -f "$patchTmp"
    echo "App registration updated with redirect URL."
  fi
else
  echo "WARNING: Could not extract redirect URL from connection response. You may need to add it manually." >&2
fi
