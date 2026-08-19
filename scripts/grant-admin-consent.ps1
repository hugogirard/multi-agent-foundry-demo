#!/usr/bin/env pwsh
# Grants tenant-wide admin consent for all app registrations.
# Uses Graph REST API via 'az rest' (avoids 'az ad' which hangs in some tenants).
# Prerequisites:
#   - azd environment must be provisioned (run `azd provision` first).
#   - Caller must be a Global Administrator or Privileged Role Administrator.

$ErrorActionPreference = 'Stop'

# --- Helper: look up app client ID by exact display name via Graph API ---
function Get-AppClientId {
    param([string]$DisplayName)
    $encodedName = [System.Uri]::EscapeDataString($DisplayName)
    $url = "https://graph.microsoft.com/v1.0/applications?" + '$filter' + "=displayName eq '$encodedName'&" + '$select' + "=appId,displayName"
    $result = az rest --method GET --url $url --query "value[?displayName=='$DisplayName'].appId | [0]" -o tsv
    return $result
}

# --- Helper: grant tenant-wide admin consent for all delegated permissions on an app ---
function Grant-AdminConsentViaGraph {
    param([string]$AppId, [string]$Label)

    Write-Host "`nGranting admin consent for $Label ($AppId)..." -ForegroundColor Yellow

    # 1. Ensure service principal exists for this app
    $spUrl = "https://graph.microsoft.com/v1.0/servicePrincipals?" + '$filter' + "=appId eq '$AppId'&" + '$select' + "=id"
    $sp = az rest --method GET --url $spUrl --query "value[0]" -o json | ConvertFrom-Json

    if (-not $sp) {
        Write-Host "  Creating service principal..."
        $body = @{ appId = $AppId } | ConvertTo-Json -Compress
        $tmp = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tmp, $body)
        $sp = az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals" --body "@$tmp" --headers "Content-Type=application/json" -o json | ConvertFrom-Json
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
    $clientSpId = $sp.id

    # 2. Get the app's requiredResourceAccess
    $appUrl = "https://graph.microsoft.com/v1.0/applications?" + '$filter' + "=appId eq '$AppId'&" + '$select' + "=requiredResourceAccess"
    $app = az rest --method GET --url $appUrl --query "value[0]" -o json | ConvertFrom-Json

    if (-not $app.requiredResourceAccess) {
        Write-Host "  No requiredResourceAccess found. Skipping."
        return
    }

    foreach ($resource in $app.requiredResourceAccess) {
        $resourceAppId = $resource.resourceAppId

        # 3. Get the resource's service principal (with its published scopes)
        $rspUrl = "https://graph.microsoft.com/v1.0/servicePrincipals?" + '$filter' + "=appId eq '$resourceAppId'&" + '$select' + "=id,displayName,oauth2PermissionScopes"
        $rsp = az rest --method GET --url $rspUrl --query "value[0]" -o json | ConvertFrom-Json

        if (-not $rsp) {
            Write-Host "  WARNING: No service principal found for resource $resourceAppId. Skipping."
            continue
        }

        # 4. Collect only delegated (Scope) permission IDs
        $delegatedIds = @($resource.resourceAccess | Where-Object { $_.type -eq "Scope" } | ForEach-Object { $_.id })
        if ($delegatedIds.Count -eq 0) { continue }

        # 5. Map permission IDs to scope value strings
        $scopeValues = @()
        foreach ($permId in $delegatedIds) {
            $match = $rsp.oauth2PermissionScopes | Where-Object { $_.id -eq $permId }
            if ($match) {
                $scopeValues += $match.value
            }
        }
        if ($scopeValues.Count -eq 0) { continue }
        $scopeString = $scopeValues -join " "

        Write-Host "  Resource: $($rsp.displayName) -> scopes: $scopeString"

        # 6. Create oauth2PermissionGrant (skip if already exists — POST returns 409)
        Write-Host "  Creating permission grant..."
        $grantBody = @{
            clientId    = $clientSpId
            consentType = "AllPrincipals"
            resourceId  = $rsp.id
            scope       = $scopeString
        } | ConvertTo-Json -Compress
        $tmp = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tmp, $grantBody)

        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $grantResult = az rest --method POST --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" --body "@$tmp" --headers "Content-Type=application/json" -o json 2>&1
        $grantExit = $LASTEXITCODE
        $ErrorActionPreference = $prevPref
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue

        if ($grantExit -ne 0) {
            Write-Host "  WARNING: Grant failed (exit code $grantExit)." -ForegroundColor Red
            Write-Host "  Response: $grantResult" -ForegroundColor Red
        }
        else {
            Write-Host "  Grant created successfully." -ForegroundColor Green
        }
    }

    Write-Host "  Admin consent granted for $Label." -ForegroundColor Green
}

# --- Main ---

Write-Host "Granting admin consent for all app registrations..." -ForegroundColor Cyan
Write-Host "`nReading client IDs..."

$mcpClientId = if ($env:FLIGHT_MCP_SERVER_CLIENT_ID) { $env:FLIGHT_MCP_SERVER_CLIENT_ID } else { azd env get-value FLIGHT_MCP_SERVER_CLIENT_ID }
if (-not $mcpClientId) {
    Write-Error "Could not read FLIGHT_MCP_SERVER_CLIENT_ID from env or azd env."
    exit 1
}
Write-Host "  Flight MCP Server Client ID: $mcpClientId"

Write-Host "Looking up Conversation API app registration..."
$conversationApiClientId = Get-AppClientId -DisplayName "Conversation API"
if (-not $conversationApiClientId) {
    Write-Error "Could not find 'Conversation API' app registration."
    exit 1
}
Write-Host "  Conversation API Client ID: $conversationApiClientId"

Write-Host "Looking up OpenAPI app registration..."
$openApiClientId = Get-AppClientId -DisplayName "OpenAPI"
if (-not $openApiClientId) {
    Write-Error "Could not find 'OpenAPI' app registration."
    exit 1
}
Write-Host "  OpenAPI Client ID: $openApiClientId"

Write-Host "Looking up Front-End Chatbot Trip Reservation app registration..."
$frontEndClientId = Get-AppClientId -DisplayName "Front-End Chatbot Trip Reservation"
if (-not $frontEndClientId) {
    Write-Error "Could not find 'Front-End Chatbot Trip Reservation' app registration."
    exit 1
}
Write-Host "  Front-End Client ID: $frontEndClientId"

Write-Host "Looking up Foundry MCP Flight Server app registration..."
$foundryMcpClientId = if ($env:FOUNDRY_CONNECTION_MCP_CLIENT_ID) { $env:FOUNDRY_CONNECTION_MCP_CLIENT_ID } else { azd env get-value FOUNDRY_CONNECTION_MCP_CLIENT_ID }
if (-not $foundryMcpClientId) {
    Write-Error "Could not read FOUNDRY_CONNECTION_MCP_CLIENT_ID from env or azd env."
    exit 1
}
Write-Host "  Foundry MCP Flight Server Client ID: $foundryMcpClientId"

Write-Host "Looking up Foundry MCP Hotel Server app registration..."
$foundryHotelMcpClientId = if ($env:FOUNDRY_CONNECTION_HOTEL_MCP_CLIENT_ID) { $env:FOUNDRY_CONNECTION_HOTEL_MCP_CLIENT_ID } else { azd env get-value FOUNDRY_CONNECTION_HOTEL_MCP_CLIENT_ID }
if (-not $foundryHotelMcpClientId) {
    Write-Error "Could not read FOUNDRY_CONNECTION_HOTEL_MCP_CLIENT_ID from env or azd env."
    exit 1
}
Write-Host "  Foundry MCP Hotel Server Client ID: $foundryHotelMcpClientId"

Write-Host "Looking up Hotel MCP Server app registration..."
$hotelMcpClientId = if ($env:HOTEL_MCP_SERVER_CLIENT_ID) { $env:HOTEL_MCP_SERVER_CLIENT_ID } else { azd env get-value HOTEL_MCP_SERVER_CLIENT_ID }
if (-not $hotelMcpClientId) {
    Write-Error "Could not read HOTEL_MCP_SERVER_CLIENT_ID from env or azd env."
    exit 1
}
Write-Host "  Hotel MCP Server Client ID: $hotelMcpClientId"

# --- Grant admin consent for each app ---

Grant-AdminConsentViaGraph -AppId $mcpClientId         -Label "Flight MCP Server"
Grant-AdminConsentViaGraph -AppId $hotelMcpClientId    -Label "Hotel MCP Server"
Grant-AdminConsentViaGraph -AppId $foundryMcpClientId   -Label "Foundry MCP Flight Server"
Grant-AdminConsentViaGraph -AppId $foundryHotelMcpClientId -Label "Foundry MCP Hotel Server"
Grant-AdminConsentViaGraph -AppId $conversationApiClientId    -Label "Conversation API"
Grant-AdminConsentViaGraph -AppId $openApiClientId      -Label "OpenAPI"
Grant-AdminConsentViaGraph -AppId $frontEndClientId     -Label "Front-End Chatbot Trip Reservation"

Write-Host "`nDone! Admin consent has been granted for all applications." -ForegroundColor Cyan

# Ensure script exits with 0 — the az rest calls above may leave $LASTEXITCODE = 1
# from 409 conflict responses (grant already exists), which is expected/non-fatal.
exit 0
