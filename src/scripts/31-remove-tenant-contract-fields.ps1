<#
  Property Allocation Board — removes non-essential columns from the
  alex_tenant_contract table (per request), then publishes.

  Run 30-create-tenant-contract.ps1 FIRST so the main form/views no longer
  reference these columns (an attribute referenced by a form cannot be deleted).

  Target env: EN only (demo-contact-center-en) — DV_URL from src/scripts/.env.ps1
  Web API only. Idempotent (skips columns that are already gone).
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$Table = "alex_tenant_contract"
$Drop = @(
    "alex_os_payment_method"
    "alex_m_registration_fee"
    "alex_n_billing_day"
    "alex_b_prep_program"
    "alex_m_deposit"
    "alex_b_deposit_paid"
    "alex_b_shomer_shabbat"
)

foreach ($col in $Drop) {
    $exists = $null
    try { $exists = Invoke-DV GET "EntityDefinitions(LogicalName='$Table')/Attributes(LogicalName='$col')?`$select=LogicalName" -Silent } catch { $exists = $null }
    if (-not $exists -or -not $exists.LogicalName) {
        Write-Output "  = already absent: $col"
        continue
    }
    Invoke-DV DELETE "EntityDefinitions(LogicalName='$Table')/Attributes(LogicalName='$col')" | Out-Null
    Write-Output "  - deleted: $col"
}

Write-Output "Publishing customizations..."
Invoke-DV POST "PublishAllXml" | Out-Null
Write-Output "Done. Removed $($Drop.Count) columns from $Table."
