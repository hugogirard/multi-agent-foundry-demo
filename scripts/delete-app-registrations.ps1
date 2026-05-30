#!/usr/bin/env pwsh
# Deletes all Entra ID app registrations created during provisioning.
# Also permanently purges soft-deleted apps so the uniqueName is freed for re-provisioning.
# Intended to run as a preprovision / postdown hook with `azd`.

$ErrorActionPreference = 'Continue'

Write-Host "`nDeleting app registrations created by this project..." -ForegroundColor Cyan

# Delete dependents first (OpenAPI, Front-End depend on Flight Agent API; Foundry MCP depends on Flight MCP Server)
$appDisplayNames = @(
    "OpenAPI"
    "Front-End Chatbot Trip Reservation"
    "Foundry MCP Flight Server"
    "Flight Agent API"
    "Flight MCP Server"
)

# --- Phase 1: Delete active app registrations ---
# Uses Graph API with exact displayName filter to avoid startsWith matching other tenant apps.

foreach ($displayName in $appDisplayNames) {
    Write-Host "`nLooking up '$displayName'..." -ForegroundColor Yellow

    $filterUrl = "https://graph.microsoft.com/v1.0/applications?" + '$filter' + "=displayName eq '$displayName'&" + '$select' + "=id,appId,displayName"
    $apps = az rest --method GET --url $filterUrl --query "value" -o json 2>$null | ConvertFrom-Json

    if (-not $apps -or $apps.Count -eq 0) {
        Write-Host "  Not found in active apps - skipping." -ForegroundColor DarkGray
        continue
    }

    foreach ($app in $apps) {
        Write-Host "  Found app with Client ID: $($app.appId) - deleting..."

        # Delete service principal first to remove dependency blocks
        $spUrl = "https://graph.microsoft.com/v1.0/servicePrincipals?" + '$filter' + "=appId eq '$($app.appId)'&" + '$select' + "=id"
        $sps = az rest --method GET --url $spUrl --query "value" -o json 2>$null | ConvertFrom-Json
        foreach ($sp in $sps) {
            Write-Host "  Removing service principal $($sp.id)..."
            az rest --method DELETE --url "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.id)" 2>$null
        }

        # Now delete the app registration
        az rest --method DELETE --url "https://graph.microsoft.com/v1.0/applications/$($app.id)" 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Deleted '$displayName'." -ForegroundColor Green
        }
        else {
            Write-Warning "  Failed to delete '$displayName' (Client ID: $($app.appId)). You may need to remove it manually."
        }
    }
}

# --- Phase 2: Permanently purge soft-deleted app registrations ---

Write-Host "`nPurging soft-deleted app registrations..." -ForegroundColor Cyan

foreach ($displayName in $appDisplayNames) {
    Write-Host "`nChecking deleted items for '$displayName'..." -ForegroundColor Yellow

    $url = "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application?" + '$filter' + "=displayName eq '$displayName'&" + '$select' + "=id,displayName"
    $deletedApps = az rest --method GET --url $url --query "value" -o json 2>$null | ConvertFrom-Json

    if (-not $deletedApps -or $deletedApps.Count -eq 0) {
        Write-Host "  No soft-deleted items found - skipping." -ForegroundColor DarkGray
        continue
    }

    foreach ($app in $deletedApps) {
        Write-Host "  Permanently deleting soft-deleted app (Object ID: $($app.id))..."
        az rest --method DELETE --url "https://graph.microsoft.com/v1.0/directory/deletedItems/$($app.id)" 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Purged '$displayName'." -ForegroundColor Green
        }
        else {
            Write-Warning "  Failed to purge '$displayName' (Object ID: $($app.id)). You may need to remove it manually from Entra ID > Deleted applications."
        }
    }
}

Write-Host "`nApp registration cleanup complete." -ForegroundColor Cyan
