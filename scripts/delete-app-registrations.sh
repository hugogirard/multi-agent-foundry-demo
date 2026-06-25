#!/usr/bin/env bash
# Deletes all Entra ID app registrations created during provisioning.
# Also permanently purges soft-deleted apps so the uniqueName is freed for re-provisioning.
# Intended to run as a preprovision / postdown hook with `azd`.

set -o pipefail

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
GRAY='\033[1;30m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "\n${CYAN}Deleting app registrations created by this project...${NC}"

# Delete dependents first (OpenAPI, Front-End depend on Flight Agent API; Foundry MCP depends on Flight MCP Server)
appDisplayNames=(
    "OpenAPI"
    "Front-End Chatbot Trip Reservation"
    "Foundry MCP Flight Server"
    "Flight Agent API"
    "Flight MCP Server"
)

# --- Phase 1: Delete active app registrations ---
# Uses az ad commands with exact displayName filter to avoid startsWith matching other tenant apps.

for displayName in "${appDisplayNames[@]}"; do
    echo -e "\n${YELLOW}Looking up '$displayName'...${NC}"

    apps=$(az ad app list --filter "displayName eq '$displayName'" --query "[].{id:id, appId:appId, displayName:displayName}" -o json 2>/dev/null)

    if [ -z "$apps" ] || [ "$apps" = "[]" ]; then
        echo -e "  ${GRAY}Not found in active apps - skipping.${NC}"
        continue
    fi

    appCount=$(echo "$apps" | jq length)

    for i in $(seq 0 $((appCount - 1))); do
        appId=$(echo "$apps" | jq -r ".[$i].appId")
        objectId=$(echo "$apps" | jq -r ".[$i].id")

        echo -e "  Found app with Client ID: $appId - deleting..."

        # Delete service principal first to remove dependency blocks
        sps=$(az ad sp list --filter "appId eq '$appId'" --query "[].{id:id}" -o json 2>/dev/null)

        if [ -n "$sps" ] && [ "$sps" != "[]" ]; then
            spCount=$(echo "$sps" | jq length)
            for j in $(seq 0 $((spCount - 1))); do
                spId=$(echo "$sps" | jq -r ".[$j].id")
                echo -e "  Removing service principal $spId..."
                az ad sp delete --id "$spId" 2>/dev/null
            done
        fi

        # Now delete the app registration
        if az ad app delete --id "$objectId" 2>/dev/null; then
            echo -e "  ${GREEN}Deleted '$displayName'.${NC}"
        else
            echo -e "  ${RED}WARNING: Failed to delete '$displayName' (Client ID: $appId). You may need to remove it manually.${NC}"
        fi
    done
done

# --- Phase 2: Permanently purge soft-deleted app registrations ---

echo -e "\n${CYAN}Purging soft-deleted app registrations...${NC}"

for displayName in "${appDisplayNames[@]}"; do
    echo -e "\n${YELLOW}Checking deleted items for '$displayName'...${NC}"

    url="https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application?\$filter=displayName eq '$displayName'&\$select=id,displayName"
    deletedApps=$(az rest --method GET --url "$url" --query "value" -o json 2>/dev/null)

    if [ -z "$deletedApps" ] || [ "$deletedApps" = "[]" ] || [ "$deletedApps" = "null" ]; then
        echo -e "  ${GRAY}No soft-deleted items found - skipping.${NC}"
        continue
    fi

    deletedCount=$(echo "$deletedApps" | jq length)

    for i in $(seq 0 $((deletedCount - 1))); do
        objectId=$(echo "$deletedApps" | jq -r ".[$i].id")

        echo -e "  Permanently deleting soft-deleted app (Object ID: $objectId)..."

        if az rest --method DELETE --url "https://graph.microsoft.com/v1.0/directory/deletedItems/$objectId" 2>/dev/null; then
            echo -e "  ${GREEN}Purged '$displayName'.${NC}"
        else
            echo -e "  ${RED}WARNING: Failed to purge '$displayName' (Object ID: $objectId). You may need to remove it manually from Entra ID > Deleted applications.${NC}"
        fi
    done
done

echo -e "\n${CYAN}App registration cleanup complete.${NC}"
