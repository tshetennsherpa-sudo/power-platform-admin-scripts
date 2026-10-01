# Power Platform Admin Scripts

PowerShell scripts for common Power Platform administration tasks: inventory, finding orphaned resources after someone leaves, and reporting on DLP (data) policies.

Built and tested in a Microsoft 365 practice tenant with multiple environments, a test maker account, and two layered DLP policies.

## Scripts

| Script | What it does | Why an admin needs it |
|---|---|---|
| `Get-PPInventory.ps1` | Lists every canvas app and cloud flow in every environment, with owner and dates, and exports it to CSV. | A repeatable answer to "what has been built, where, and by whom?" The starting point for any ownership or cleanup work. |
| `Find-PPOrphans.ps1` | Reads the inventory CSV, checks each owner against Microsoft Entra ID, and exports items whose owner no longer exists. | When someone leaves, their apps and flows can stop working or become impossible to manage. This finds them. |
| `Get-PPDlpPolicies.ps1` | Reports every DLP policy: scope, default group, and which connectors are in Business, Non-business, and Blocked. | Audit evidence of what each policy allows, produced the same way every time instead of from screenshots. |

## Requirements

- **PowerShell 7.** In Windows PowerShell 5.1, the admin module loads Microsoft Graph, which exceeds the 4,096-function limit and fails.
- The `Microsoft.PowerApps.Administration.PowerShell` module:
  ```powershell
  Install-Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser
  ```
- A Power Platform administrator account.

## Usage

```powershell
# 1. Inventory of all apps and flows
.\Get-PPInventory.ps1

# 2. Find orphaned items from that inventory
.\Find-PPOrphans.ps1 -InventoryPath .\PowerPlatform_Inventory_<date>.csv -IgnoreObjectIds "<system identity id>"

# 3. DLP policy report
.\Get-PPDlpPolicies.ps1
```

If Windows blocks a downloaded script, run `Unblock-File .\<script>.ps1` first.

## Fixing orphaned items

The scripts only report. Reassigning is done with the module's own commands:

```powershell
# Canvas apps have one owner: replace it
Set-AdminPowerAppOwner -AppName <app id> -EnvironmentName <environment id> -AppOwner <new owner object id>

# Flows can have several owners: add one
Set-AdminFlowOwnerRole -EnvironmentName <environment id> -FlowName <flow id> -PrincipalType User -PrincipalObjectId <new owner object id> -RoleName CanEdit
```

Adding an owner is not the whole fix for flows. A flow's connections still run under the original owner's account, so they also need to be replaced, ideally with a service account.

## Things to know

- **System items look orphaned.** Environments with Dataverse include Microsoft's own apps and flows, owned by a system identity rather than a person. Find that ID in the inventory (it owns items like "Solution Health Hub") and pass it to `-IgnoreObjectIds`.
- **DLP names differ between the API and the admin center.** `Confidential` = Business, `General` = Non-business.
- **Dataverse appears twice** in DLP policies, under an older and a current connector ID. Both should have the same classification.
- **Never commit the CSV output.** It contains tenant IDs, object IDs, and email addresses. The `.gitignore` excludes it.

## Known limitations and next steps

- The inventory covers canvas apps and cloud flows, not model-driven apps (which live in Dataverse).
- `Find-PPOrphans.ps1` checks each flow's creator, not every current owner, so it can flag a flow that already has a working co-owner. Next step: check all owners with `Get-AdminFlowOwnerRole`.
- For flows, the inventory records the owner's object ID, not their name.
- The DLP report shows environment IDs in the scope column, not display names.
