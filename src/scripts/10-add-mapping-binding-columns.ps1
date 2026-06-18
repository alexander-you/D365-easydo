<#
  10-add-mapping-binding-columns.ps1

  Adds the two policy columns that turn a template field mapping into a
  data binding: a Direction (prefill / read back / bidirectional) and a
  Recipient Lock flag.

  Design: the EasyDoc template designer expresses WHICH Dynamics field a form
  field maps to by writing the binding as the field's export header
  (e.g. "contact.fullname"), captured into alex_externalfieldname at sync time.
  WHETHER that field is pushed out, read back, or both — and whether the value
  is locked for the recipient — is a Dynamics-side policy set here, so a template
  designer can never cause a write back to Dynamics on their own.

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_templatefieldmapping"
Write-Output "== $t =="

Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_Direction" -En "Direction" -He "כיוון" -GlobalOptionSetName "alex_fielddirection" `
    -DescEn "Whether this mapped field is prefilled into the form before sending, read back from what the recipient entered, or both. Read back only happens when this allows it." `
    -DescHe "האם השדה הממופה ממולא מראש בטופס לפני השליחה, נקרא חזרה ממה שהנמען הזין, או שניהם. קריאה חזרה מתבצעת רק כאשר הכיוון מתיר זאת.")

Add-DVColumn $t (New-DVBool -Schema "alex_IsReadOnly" -En "Locked For Recipient" -He "נעול לנמען" `
    -TrueEn "Locked" -TrueHe "נעול" -FalseEn "Editable" -FalseHe "ניתן לעריכה" -Default $false `
    -DescEn "When enabled, the prefilled value is locked so the recipient can see it but cannot edit it (use for verified Dynamics 365 values such as ID number)." `
    -DescHe "כאשר מופעל, הערך הממולא מראש נעול כך שהנמען רואה אותו אך אינו יכול לערוך אותו (לשימוש בערכים מאומתים מ-Dynamics 365 כגון מספר תעודת זהות).")

Write-Output "Done."
