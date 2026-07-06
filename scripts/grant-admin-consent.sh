#!/usr/bin/env bash
# Grants tenant-wide admin consent for all app registrations.
# Uses Graph REST API via 'az rest' (avoids 'az ad' which hangs in some tenants).
# Prerequisites:
#   - Azure CLI must be logged in with sufficient permissions.
#   - Caller must be a Global Administrator or Privileged Role Administrator.
#   - Environment variables FLIGHT_MCP_SERVER_CLIENT_ID and
#     FOUNDRY_CONNECTION_MCP_CLIENT_ID must be set.

set -euo pipefail

# --- Helper: look up app client ID by exact display name via Graph API ---
get_app_client_id() {
    local display_name="$1"
    local encoded_name
    encoded_name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$display_name'))")
    local url="https://graph.microsoft.com/v1.0/applications?\$filter=displayName eq '${display_name}'&\$select=appId,displayName"
    az rest --method GET --url "$url" --query "value[?displayName=='${display_name}'].appId | [0]" -o tsv
}

# --- Helper: grant tenant-wide admin consent for all delegated permissions on an app ---
grant_admin_consent() {
    local app_id="$1"
    local label="$2"

    echo ""
    echo "Granting admin consent for $label ($app_id)..."

    # 1. Ensure service principal exists for this app
    local sp_url="https://graph.microsoft.com/v1.0/servicePrincipals?\$filter=appId eq '${app_id}'&\$select=id"
    local client_sp_id
    client_sp_id=$(az rest --method GET --url "$sp_url" --query "value[0].id" -o tsv 2>/dev/null || true)

    if [[ -z "$client_sp_id" || "$client_sp_id" == "None" ]]; then
        echo "  Creating service principal..."
        local body="{\"appId\":\"${app_id}\"}"
        client_sp_id=$(az rest --method POST \
            --url "https://graph.microsoft.com/v1.0/servicePrincipals" \
            --body "$body" \
            --headers "Content-Type=application/json" \
            --query "id" -o tsv)
    fi

    echo "  Service Principal ID: $client_sp_id"

    # 2. Get the app's requiredResourceAccess
    local app_url="https://graph.microsoft.com/v1.0/applications?\$filter=appId eq '${app_id}'&\$select=requiredResourceAccess"
    local app_json
    app_json=$(az rest --method GET --url "$app_url" --query "value[0].requiredResourceAccess" -o json 2>/dev/null || echo "null")

    if [[ "$app_json" == "null" || "$app_json" == "[]" ]]; then
        echo "  No requiredResourceAccess found. Skipping."
        return
    fi

    # Iterate over each resource in requiredResourceAccess
    local resource_count
    resource_count=$(echo "$app_json" | jq 'length')

    for ((i = 0; i < resource_count; i++)); do
        local resource_app_id
        resource_app_id=$(echo "$app_json" | jq -r ".[$i].resourceAppId")

        # 3. Get the resource's service principal (with its published scopes)
        local rsp_url="https://graph.microsoft.com/v1.0/servicePrincipals?\$filter=appId eq '${resource_app_id}'&\$select=id,displayName,oauth2PermissionScopes"
        local rsp_json
        rsp_json=$(az rest --method GET --url "$rsp_url" --query "value[0]" -o json 2>/dev/null || echo "null")

        if [[ "$rsp_json" == "null" ]]; then
            echo "  WARNING: No service principal found for resource $resource_app_id. Skipping."
            continue
        fi

        local resource_sp_id
        resource_sp_id=$(echo "$rsp_json" | jq -r '.id')
        local resource_display_name
        resource_display_name=$(echo "$rsp_json" | jq -r '.displayName')

        # 4. Collect only delegated (Scope) permission IDs
        local delegated_ids
        delegated_ids=$(echo "$app_json" | jq -r ".[$i].resourceAccess[] | select(.type==\"Scope\") | .id")

        if [[ -z "$delegated_ids" ]]; then
            continue
        fi

        # 5. Map permission IDs to scope value strings
        local scope_values=""
        while IFS= read -r perm_id; do
            local scope_value
            scope_value=$(echo "$rsp_json" | jq -r ".oauth2PermissionScopes[] | select(.id==\"$perm_id\") | .value")
            if [[ -n "$scope_value" ]]; then
                if [[ -n "$scope_values" ]]; then
                    scope_values="$scope_values $scope_value"
                else
                    scope_values="$scope_value"
                fi
            fi
        done <<< "$delegated_ids"

        if [[ -z "$scope_values" ]]; then
            continue
        fi

        echo "  Resource: $resource_display_name -> scopes: $scope_values"

        # 6. Create oauth2PermissionGrant (skip if already exists — POST returns conflict)
        echo "  Creating permission grant..."
        local grant_body
        grant_body=$(jq -n \
            --arg clientId "$client_sp_id" \
            --arg resourceId "$resource_sp_id" \
            --arg scope "$scope_values" \
            '{clientId: $clientId, consentType: "AllPrincipals", resourceId: $resourceId, scope: $scope}')

        if az rest --method POST \
            --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" \
            --body "$grant_body" \
            --headers "Content-Type=application/json" \
            -o none 2>/dev/null; then
            echo "  Grant created successfully."
        else
            echo "  Grant may already exist or non-fatal error. Continuing."
        fi
    done

    echo "  Admin consent granted for $label."
}

# --- Main ---

echo "Granting admin consent for all app registrations..."

# Read client IDs from environment variables
if [[ -z "${FLIGHT_MCP_SERVER_CLIENT_ID:-}" ]]; then
    echo "ERROR: FLIGHT_MCP_SERVER_CLIENT_ID environment variable is not set."
    exit 1
fi
echo "  Flight MCP Server Client ID: $FLIGHT_MCP_SERVER_CLIENT_ID"

if [[ -z "${FOUNDRY_CONNECTION_MCP_CLIENT_ID:-}" ]]; then
    echo "ERROR: FOUNDRY_CONNECTION_MCP_CLIENT_ID environment variable is not set."
    exit 1
fi
echo "  Foundry MCP Flight Server Client ID: $FOUNDRY_CONNECTION_MCP_CLIENT_ID"

# Look up remaining apps by display name
echo "Looking up Flight Agent API app registration..."
flight_api_client_id=$(get_app_client_id "Flight Agent API")
if [[ -z "$flight_api_client_id" ]]; then
    echo "ERROR: Could not find 'Flight Agent API' app registration."
    exit 1
fi
echo "  Flight Agent API Client ID: $flight_api_client_id"

echo "Looking up OpenAPI app registration..."
openapi_client_id=$(get_app_client_id "OpenAPI")
if [[ -z "$openapi_client_id" ]]; then
    echo "ERROR: Could not find 'OpenAPI' app registration."
    exit 1
fi
echo "  OpenAPI Client ID: $openapi_client_id"

echo "Looking up Front-End Chatbot Trip Reservation app registration..."
frontend_client_id=$(get_app_client_id "Front-End Chatbot Trip Reservation")
if [[ -z "$frontend_client_id" ]]; then
    echo "ERROR: Could not find 'Front-End Chatbot Trip Reservation' app registration."
    exit 1
fi
echo "  Front-End Client ID: $frontend_client_id"

# --- Grant admin consent for each app ---

grant_admin_consent "$FLIGHT_MCP_SERVER_CLIENT_ID" "Flight MCP Server"
grant_admin_consent "$FOUNDRY_CONNECTION_MCP_CLIENT_ID" "Foundry MCP Flight Server"
grant_admin_consent "$flight_api_client_id" "Flight Agent API"
grant_admin_consent "$openapi_client_id" "OpenAPI"
grant_admin_consent "$frontend_client_id" "Front-End Chatbot Trip Reservation"

echo ""
echo "Done! Admin consent has been granted for all applications."
