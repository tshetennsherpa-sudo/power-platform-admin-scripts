<#
.SYNOPSIS
    Reports every DLP (data) policy in the tenant: scope, default group, and which connectors sit in
    Business, Non-business, and Blocked.

.DESCRIPTION
    Read-only. Prints a summary per policy and exports one row per policy and connector to a CSV,
    which can be kept as audit evidence of what each policy allows.

    The API uses different names than the admin center:
        Confidential = Business
        General      = Non-business
        Blocked      = Blocked

.NOTES
    Requires: Microsoft.PowerApps.Administration.PowerShell module
    Run in:   PowerShell 7
    Rights:   Power Platform administrator

.EXAMPLE
    .\Get-PPDlpPolicies.ps1
#>

param(
    [string]$OutputPath = ".\PowerPlatform_DlpPolicies_$(Get-Date -Format 'yyyy-MM-dd').csv"
)

Import-Module Microsoft.PowerApps.Administration.PowerShell
Add-PowerAppsAccount

$groupNames = @{
    'Confidential' = 'Business'
    'General'      = 'Non-business'
    'Blocked'      = 'Blocked'
}

$policies = (Get-DlpPolicy).value
$rows = [System.Collections.Generic.List[object]]::new()

foreach ($policy in $policies) {
    $scope = if ($policy.environmentType -eq 'AllEnvironments') {
        'All environments'
    }
    else {
        "$($policy.environmentType): " + (($policy.environments | ForEach-Object { $_.name }) -join ', ')
    }
    $default = $groupNames[$policy.defaultConnectorsClassification]

    Write-Host "`n$($policy.displayName)" -ForegroundColor Cyan
    Write-Host "  Scope:          $scope"
    Write-Host "  Default group:  $default"

    foreach ($group in $policy.connectorGroups) {
        $groupName = $groupNames[$group.classification]
        Write-Host ("  {0,-15} {1} connectors" -f "${groupName}:", @($group.connectors).Count)

        foreach ($connector in $group.connectors) {
            $rows.Add([PSCustomObject]@{
                Policy       = $policy.displayName
                Scope        = $scope
                DefaultGroup = $default
                Group        = $groupName
                Connector    = $connector.name
                ConnectorId  = $connector.id
            })
        }
    }
}

$rows | Sort-Object Policy, Group, Connector |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "`n$($policies.Count) policies, $($rows.Count) connector rows exported to $OutputPath" -ForegroundColor Green
