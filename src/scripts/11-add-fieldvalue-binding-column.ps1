<#
  11-add-fieldvalue-binding-column.ps1

  Adds the binding-expression column to the per-request field value table so
  read-back rows are usable by the customer's implementer.

  The read-back flow already knows each field's easydo export header
  (e.g. "contact.fullname"). Storing it on the row means the implementer reads
  "contact.fullname = alex" directly and can build their own write-back Flow,
  instead of seeing only the opaque technical name "custom_field".

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_signaturefieldvalue"
Write-Output "== $t =="

Add-DVColumn $t (New-DVString -Schema "alex_ExternalFieldName" -En "Binding Expression" -He "ביטוי קישור" -MaxLength 200 `
    -DescEn "The easydo field export header, used as the data binding expression (e.g. contact.fullname). Lets an implementer map this read-back value to a Dynamics 365 column." `
    -DescHe "כותרת הייצוא של שדה easydo, המשמשת כביטוי קישור לנתונים (לדוגמה contact.fullname). מאפשרת למיישם למפות את הערך החוזר לעמודה ב-Dynamics 365.")

Write-Output "Publishing..."
Invoke-DV POST "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
