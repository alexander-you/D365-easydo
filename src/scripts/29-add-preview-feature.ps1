<#
  29-add-preview-feature.ps1

  Adds the "document preview before send" capability end-to-end.

  Preview model
  -------------
  easydo renders the signed PDF only AFTER a form is signed, so a true PDF cannot
  be downloaded before sending. easydo's web viewer also blocks cross-origin
  framing (frame-ancestors). The working preview therefore opens easydo's own
  document viewer (the assignee fill_url) in a new tab: it shows the real
  document with its fields, while the underlying draft form stays "incomplete"
  so NO recipient is ever notified during preview.

  Flow (Send flow preview branch): create draft form from template -> set the
  same assignees (this generates the fill_url without notifying) -> store the
  fill_url + draft form id on the request -> mark preview ready (status Draft).
  The wizard opens the fill_url for review and, on approval, performs the real
  send (a separate SendTemplate that actually notifies).

  NEW COLUMN on alex_easydosettings
  ----------------------------------
    alex_AllowPreview   (bool, default false) - master switch. When ON the send
      wizard offers a "preview before send" option.

  NEW COLUMNS on alex_signaturerequest
  ------------------------------------
    alex_PreviewUrl     (url, 500)  - easydo document viewer link for the preview.
    alex_PreviewFormId  (string)    - the easydo draft form id created for preview
      (kept so the draft can be cleaned up / cancelled later).

  REUSED (already exist):
    alex_signaturerequest.alex_isdraft            - request is in preview mode
    alex_signaturerequest.alex_ispreviewgenerated - preview link is ready

  Idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1. Allow-preview master switch on the settings singleton ------------
$s = "alex_easydosettings"
Write-Output "== $s =="
Add-DVColumn $s (New-DVBool -Schema "alex_AllowPreview" -En "Allow Preview Before Send" -He "אפשר תצוגה מקדימה לפני שליחה" `
    -DescEn "When on, the send wizard lets the user preview the rendered document before sending it for signature." `
    -DescHe "כאשר מופעל, אשף השליחה מאפשר למשתמש לצפות במסמך המעובד לפני שליחתו לחתימה." `
    -TrueEn "On" -TrueHe "דלוק" -FalseEn "Off" -FalseHe "כבוי" -Default $false)

# ---- 2. Preview link + draft form id on the request ----------------------
$q = "alex_signaturerequest"
Write-Output "== $q =="
Add-DVColumn $q (New-DVString -Schema "alex_PreviewUrl" -En "Preview Link" -He "קישור תצוגה מקדימה" -MaxLength 500 -Format "Url" `
    -DescEn "easydo document viewer link for the preview. Opened by the wizard before send; the form stays incomplete so no recipient is notified." `
    -DescHe "קישור לצפייה במסמך ב-easydo עבור התצוגה המקדימה. נפתח על-ידי האשף לפני השליחה; הטופס נשאר לא-שלם כך שאף נמען אינו מקבל התראה.")
Add-DVColumn $q (New-DVString -Schema "alex_PreviewFormId" -En "Preview Form Id" -He "מזהה טופס תצוגה" -MaxLength 100 `
    -DescEn "The easydo draft form id created for the preview, kept so the draft can be cleaned up or cancelled later." `
    -DescHe "מזהה טיוטת הטופס ב-easydo שנוצר עבור התצוגה המקדימה, נשמר לצורך ניקוי או ביטול הטיוטה בהמשך.")

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. Published."
