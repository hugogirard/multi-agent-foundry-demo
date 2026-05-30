#!/usr/bin/env pwsh
# Grants tenant-wide admin consent for all app registrations.
# Uses Invoke-RestMethod with bearer token for Graph API (avoids 'az ad' and 'az rest' hangs).
# Prerequisites:
#   - azd environment must be provisioned (run `azd provision` first).
#   - Caller must be a Global Administrator or Privileged Role Administrator.

$ErrorActionPreference = 'Stop'

# --- Get Graph API bearer token once ---
$tokenJson = az account get-access-token --resource "https://graph.microsoft.com" -o json | ConvertFrom-Json
$graphToken = $tokenJson.accessToken
$graphHeaders = @{
    Authorization  = "Bearer $graphToken"
    "Content-Type" = "application/json"
}

function Invoke-Graph {
    param([string]$Method, [string]$Url, [object]$Body)
    $params = @{
        Method  = $Method
        Uri     = $Url
        Headers = $graphHeaders
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 5 -Compress)
    }
    return Invoke-RestMethod @params
}

function Invoke-GraphSafe {
    param([string]$Method, [string]$Url, [object]$Body)
    try {
        return Invoke-Graph -Method $Method -Url $Url -Body $Body
    }
    catch {
        $status = $_.Exception.Response.StatusCode.value__
        return @{ _error = $true; _status = $status; _message = $_.Exception.Message }
    }
}

# --- Helper: look up app client ID by exact display name ---
function Get-AppClientId {
    param([string]$DisplayName)
    $encodedName = [System.Uri]::EscapeDataString($DisplayName)
    $url = "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$encodedName'&`$select=appId,displayName"
    $result = Invoke-Graph -Method GET -Url $url
    $app = $result.value | Where-Object { $_.displayName -eq $DisplayName } | Select-Object -First 1
    return $app.appId
}

# --- Helper: grant tenant-wide admin consent for all delegated permissions on an app ---
function Grant-AdminConsentViaGraph {
    param([string]$AppId, [string]$Label)

    Write-Host "`nGranting admin consent for $Label ($AppId)..." -ForegroundColor Yellow

    # 1. Ensure service principal exists for this app
    $spUrl = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$AppId'&`$select=id"
    $spResult = Invoke-Graph -Method GET -Url $spUrl
    $sp = $spResult.value | Select-Object -First 1

    if (-not $sp) {
        Write-Host "  Creating service principal..."
        $sp = Invoke-Graph -Method POST -Url "https://graph.microsoft.com/v1.0/servicePrincipals" -Body @{ appId = $AppId }
    }
    $clientSpId = $sp.id

    # 2. Get the app's requiredResourceAccess
    $appUrl = "https://graph.microsoft.com/v1.0/applications?`$filter=appId eq '$AppId'&`$select=requiredResourceAccess"
    $appResult = Invoke-Graph -Method GET -Url $appUrl
    $appData = $appResult.value | Select-Object -First 1

    if (-not $appData.requiredResourceAccess) {
        Write-Host "  No requiredResourceAccess found. Skipping."
        return
    }

    foreach ($resource in $appData.requiredResourceAccess) {
        $resourceAppId = $resource.resourceAppId

        # 3. Get the resource's service principal
        $rspUrl = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$resourceAppId'&`$select=id,displayName,oauth2PermissionScopes"
        $rspResult = Invoke-Graph -Method GET -Url $rspUrl
        $rsp = $rspResult.value | Select-Object -First 1

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
            if ($match) { $scopeValues += $match.value }
        }
        if ($scopeValues.Count -eq 0) { continue }
        $scopeString = $scopeValues -join " "

        Write-Host "  Resource: $($rsp.displayName) -> scopes: $scopeString"

        # 6. Create oauth2PermissionGrant (ignore 409 = already exists)
        Write-Host "  Creating permission grant..."
        $grantBody = @{
            clientId    = $clientSpId
            consentType = "AllPrincipals"
            resourceId  = $rsp.id
            scope       = $scopeString
        }
        $result = Invoke-GraphSafe -Method POST -Url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" -Body $grantBody

        if ($result._error) {
            if ($result._status -eq 409) {
                Write-Host "  Grant already exists. Skipping."
            }
            else {
                Write-Host "  Warning: Grant returned status $($result._status). Continuing."
            }
        }
    }

    Write-Host "  Admin consent granted for $Label." -ForegroundColor Green
}

# --- Main ---

Write-Host "Granting admin consent for all app registrations..." -ForegroundColor Cyan
Write-Host "`nReading azd environment values..."

$mcpClientId = azd env get-value FLIGHT_MCP_SERVER_CLIENT_ID
if (-not $mcpClientId) {
    Write-Error "Could not read FLIGHT_MCP_SERVER_CLIENT_ID from azd env."
    exit 1
}
Write-Host "  Flight MCP Server Client ID: $mcpClientId"

Write-Host "Looking up Flight Agent API app registration..."
$flightApiClientId = Get-AppClientId -DisplayName "Flight Agent API"
if (-not $flightApiClientId) {
    Write-Error "Could not find 'Flight Agent API' app registration."
    exit 1
}
Write-Host "  Flight Agent API Client ID: $flightApiClientId"

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
$foundryMcpClientId = azd env get-value FOUNDRY_CONNECTION_MCP_CLIENT_ID
if (-not $foundryMcpClientId) {
    Write-Error "Could not read FOUNDRY_CONNECTION_MCP_CLIENT_ID from azd env."
    exit 1
}
Write-Host "  Foundry MCP Flight Server Client ID: $foundryMcpClientId"

# --- Grant admin consent for each app ---

Grant-AdminConsentViaGraph -AppId $mcpClientId         -Label "Flight MCP Server"
Grant-AdminConsentViaGraph -AppId $foundryMcpClientId   -Label "Foundry MCP Flight Server"
Grant-AdminConsentViaGraph -AppId $flightApiClientId    -Label "Flight Agent API"
Grant-AdminConsentViaGraph -AppId $openApiClientId      -Label "OpenAPI"
Grant-AdminConsentViaGraph -AppId $frontEndClientId     -Label "Front-End Chatbot Trip Reservation"

Write-Host "`nDone! Admin consent has been granted for all applications." -ForegroundColor Cyan
