<#
.SYNOPSIS
    Exports every Power App and cloud flow in the tenant, with its owner and environment, to a CSV file.

.DESCRIPTION
    Loops through every environment the signed-in admin can see, lists all canvas apps and cloud flows,
    and writes one row per item. Use the output to find orphaned items, review ownership before someone
    leaves, or hand an inventory to a manager or auditor.

.NOTES
    Requires: Microsoft.PowerApps.Administration.PowerShell module
    Run in:   PowerShell 7 (Windows PowerShell 5.1 can hit the 4096 function limit when the module loads Microsoft Graph)
    Rights:   Power Platform administrator

.EXAMPLE
    .\Get-PPInventory.ps1
    .\Get-PPInventory.ps1 -OutputPath "C:\Reports\inventory.csv"
#>

param(
    [string]$OutputPath = ".\PowerPlatform_Inventory_$(Get-Date -Format 'yyyy-MM-dd').csv"
)

Import-Module Microsoft.PowerApps.Administration.PowerShell
Add-PowerAppsAccount

$results = [System.Collections.Generic.List[object]]::new()

foreach ($env in Get-AdminPowerAppEnvironment) {
    Write-Host "Scanning $($env.DisplayName)..." -ForegroundColor Cyan

    foreach ($app in Get-AdminPowerApp -EnvironmentName $env.EnvironmentName) {
        $results.Add([PSCustomObject]@{
            Environment   = $env.DisplayName
            ItemType      = 'App'
            Name          = $app.DisplayName
            Id            = $app.AppName
            OwnerName     = $app.Owner.displayName
            OwnerEmail    = $app.Owner.email
            OwnerObjectId = $app.Owner.id
            Enabled       = ''
            Created       = $app.CreatedTime
            LastModified  = $app.LastModifiedTime
        })
    }

    foreach ($flow in Get-AdminFlow -EnvironmentName $env.EnvironmentName) {
        $results.Add([PSCustomObject]@{
            Environment   = $env.DisplayName
            ItemType      = 'Flow'
            Name          = $flow.DisplayName
            Id            = $flow.FlowName
            OwnerName     = ''
            OwnerEmail    = ''
            OwnerObjectId = $flow.CreatedBy.objectId
            Enabled       = $flow.Enabled
            Created       = $flow.CreatedTime
            LastModified  = $flow.LastModifiedTime
        })
    }
}

$results | Sort-Object Environment, ItemType, Name |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "`nDone. $($results.Count) items exported to $OutputPath" -ForegroundColor Green
