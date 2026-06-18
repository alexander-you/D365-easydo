<#
  12-add-template-pcf-host-column.ps1

  Adds the anchor column that the Template Field Mapping PCF control binds to.

  A field-type PCF control must be bound to a column on the form. The control
  itself does not really use this column's value - it reads the open template
  record id from the form context and drives everything through context.webAPI.
  This column simply gives the maker a field to drop on the template form and
  then "set as control" to surface the mapping wizard.

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_signaturetemplate"
Write-Output "== $t =="

Add-DVColumn $t (New-DVString -Schema "alex_PcfHost" -En "Field Mapping" -He "מיפוי שדות" -MaxLength 100 `
    -DescEn "Anchor column for the Template Field Mapping wizard control. Drop this field on the template form and set the control to surface the mapping editor." `
    -DescHe "עמודת עוגן לפקד אשף מיפוי השדות. הוסיפו שדה זה לטופס התבנית והגדירו את הפקד כדי להציג את עורך המיפוי.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null

Write-Output "Done."
