<#
  Adds a "Deleted / נמחק" status reason (statuscode) to alex_signaturetemplate,
  tied to the Inactive state (statecode = 1).

  This supports soft-delete reconciliation: when a template or envelope is
  removed from easydo, the sync flow deactivates the Dataverse row
  (statecode = 1 Inactive, statuscode = Deleted) instead of hard-deleting it.
  Already-sent signature requests keep their (RemoveLink) history; the send
  wizard already filters statecode eq 0 so deactivated rows cannot be sent.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$entity   = "alex_signaturetemplate"
$attribute = "statuscode"
$deletedValue = 626210000   # publisher option-value range; Deleted reason under Inactive

# Is the Deleted reason already present? (idempotent)
$existing = Invoke-DV GET "EntityDefinitions(LogicalName='$entity')/Attributes/Microsoft.Dynamics.CRM.StatusAttributeMetadata?`$select=LogicalName&`$expand=OptionSet"
$statusOptions = @($existing.value | Where-Object { $_.LogicalName -eq $attribute } | ForEach-Object { $_.OptionSet.Options } )
$already = $statusOptions | Where-Object { $_.Value -eq $deletedValue -or ($_.Label.UserLocalizedLabel.Label -eq 'Deleted') }

if ($already) {
    Write-Host "Deleted status reason already exists (value=$($already.Value)). Nothing to do." -ForegroundColor Yellow
}
else {
    $body = @{
        EntityLogicalName    = $entity
        AttributeLogicalName = $attribute
        Value                = $deletedValue
        StateCode            = 1   # Inactive
        Label                = (New-DVLabel -En "Deleted" -He "נמחק")
    }
    Invoke-DV POST "InsertStatusValue" -Body $body | Out-Null
    Write-Host "Added 'Deleted / נמחק' status reason (value=$deletedValue, state=1 Inactive)." -ForegroundColor Green
}

# Publish so the new status reason is available immediately.
Invoke-DV POST "PublishXml" -Body @{ ParameterXml = "<importexportxml><entities><entity>$entity</entity></entities></importexportxml>" } | Out-Null
Write-Host "Published $entity." -ForegroundColor Green
