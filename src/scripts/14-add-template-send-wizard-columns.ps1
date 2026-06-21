<#
  14-add-template-send-wizard-columns.ps1

  Increment 3 (send wizard enhancements). Adds three template-level columns
  on alex_signaturetemplate that drive the in-object Send Wizard:

    alex_allowsendfromobject - whether this template may be presented for
                               sending from the source record (the wizard only
                               lists templates with this flag on). Default ON so
                               existing templates keep working.
    alex_allowprefilledit    - master toggle: may the user review/edit the
                               prefilled data inside the wizard before sending.
                               Per-field control still lives on the field
                               mapping (alex_iseditablebeforesend).
    alex_rolesjson           - cached JSON of the easydo signer roles
                               (payload.roles), populated by the sync flow.
                               The wizard renders one recipient slot per role.

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_signaturetemplate"
Write-Output "== $t =="

Add-DVColumn $t (New-DVBool -Schema "alex_AllowSendFromObject" -En "Allow Send From Record" -He "אפשר שליחה מתוך הרשומה" `
    -DescEn "When on, this template can be presented for sending from a source record via the Send Wizard." `
    -DescHe "כאשר פעיל, ניתן להציג את התבנית לשליחה מתוך רשומת מקור באמצעות אשף השליחה." `
    -Default $true)

Add-DVColumn $t (New-DVBool -Schema "alex_AllowPrefillEdit" -En "Allow Prefill Edit At Send" -He "אפשר עריכת נתונים בעת שליחה" `
    -DescEn "When on, the wizard lets the user review and edit the prefilled data before sending. Per-field editability is controlled on the field mapping." `
    -DescHe "כאשר פעיל, האשף מאפשר למשתמש לבדוק ולערוך את הנתונים המוזנים מראש לפני השליחה. עריכה ברמת שדה נשלטת במיפוי השדות." `
    -Default $false)

Add-DVColumn $t (New-DVMemo -Schema "alex_RolesJson" -En "Roles (JSON)" -He "בעלי תפקידים (JSON)" -MaxLength 8000 `
    -DescEn "Cached JSON of the easydo signer roles (payload.roles), populated by the template sync flow. Used by the wizard to render a recipient slot per role." `
    -DescHe "מטמון JSON של בעלי התפקידים מ-easydo (payload.roles), מאוכלס ע'י זרימת סנכרון התבניות. משמש את האשף להצגת משבצת נמען לכל תפקיד.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
