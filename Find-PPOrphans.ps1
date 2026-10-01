<#
.SYNOPSIS
    Finds Power Platform apps and flows whose owner no longer exists in Microsoft Entra ID.

.DESCRIPTION
    Reads the CSV produced by Get-PPInventory.ps1, checks every owner object ID against Entra ID,
    and exports the items whose owner can't be found. Those are the orphaned items an admin needs
    to reassign or retire.

.NOTES
    Requires: Microsoft.PowerApps.Administration.PowerShell module
    Run in:   PowerShell 7
    Rights:   Power Platform administrator

    Microsoft's own system flows (installed with Dataverse) are owned by a system identity, not a user,
    so they also come back as "not found". Pass that ID in -IgnoreObjectIds to leave them out.

.EXAMPLE
    .\Find-PPOrphans.ps1 -InventoryPath .\PowerPlatform_Inventory_2026-10-01.csv
    .\Find-PPOrphans.ps1 -InventoryPath .\inventory.csv -IgnoreObjectIds "7f2e9d7b-c5e6-4562-a415-fec8777a256a"
#>

param(
    [Parameter(Mandatory)]
    [string]$InventoryPath,

    [string[]]$IgnoreObjectIds = @(),

    [string]$OutputPath = ".\PowerPlatform_Orphans_$(Get-Date -Format 'yyyy-MM-dd').csv"
)

Import-Module Microsoft.PowerApps.Administration.PowerShell
Add-PowerAppsAccount

$inventory = Import-Csv -Path $InventoryPath

$ownerIds = $inventory.OwnerObjectId |
    Where-Object { $_ -and ($IgnoreObjectIds -notcontains $_) } |
    Sort-Object -Unique

# Connect to Microsoft Graph up front, so its sign-in and welcome output
# isn't mistaken for a lookup result inside the loop.
$null = Get-UsersOrGroupsFromGraph -SearchString "warmup" -ErrorAction SilentlyContinue

$missingIds = foreach ($id in $ownerIds) {
    $results = Get-UsersOrGroupsFromGraph -ObjectId $id -ErrorAction SilentlyContinue
    # Only count a result if it is actually the object we asked for.
    $found = $results | Where-Object { $_.ObjectId -eq $id -or $_.Id -eq $id }
    if (-not $found) {
        Write-Host "Owner not found in Entra ID: $id" -ForegroundColor Yellow
        $id
    }
}

$orphans = $inventory | Where-Object { $missingIds -contains $_.OwnerObjectId }

if ($orphans) {
    $orphans | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "`n$($orphans.Count) orphaned items exported to $OutputPath" -ForegroundColor Red
    $orphans | Format-Table Environment, ItemType, Name, Id -AutoSize
}
else {
    Write-Host "`nNo orphaned items found." -ForegroundColor Green
}
