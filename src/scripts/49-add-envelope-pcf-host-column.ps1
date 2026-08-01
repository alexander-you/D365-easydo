<#
  49-add-envelope-pcf-host-column.ps1

  Adds the anchor column that the Envelope Composition PCF control binds to.

  A field-type PCF control must be bound to a column on the form. The control
  itself does not use this column's value - it reads the open envelope-template
  record id from the form context and drives everything through context.webAPI.
  This column simply gives the maker a field to drop on the template form's
  "Envelope" tab and then "set as control" to surface the envelope composition
  editor (member documents + order + roles).

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_signaturetemplate"
Write-Output "== $t =="

Add-DVColumn $t (New-DVString -Schema "alex_EnvelopeHost" -En "Envelope Composition" -He "הרכב מעטפה" -MaxLength 100 `
    -DescEn "Anchor column for the Envelope Composition control. Drop this field on the template form's Envelope tab and set the control to surface the member-document editor." `
    -DescHe "עמודת עוגן לפקד הרכב המעטפה. הוסיפו שדה זה לטאב 'מעטפה' בטופס התבנית והגדירו את הפקד כדי להציג את עורך מסמכי המעטפה.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null

Write-Output "Done."
