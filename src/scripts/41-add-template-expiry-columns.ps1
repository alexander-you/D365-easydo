<#
  41-add-template-expiry-columns.ps1

  Document validity / expiry feature (step 1 - schema).

  easydo has NO API knob to set a form expiry (probed 2026-07-30: the /send
  body accepts only notify_emails + meta_data, and expires_at is never
  populated). So expiry is managed entirely on the Dynamics side.

  Template-level policy columns on alex_signaturetemplate (surfaced in the
  Template Field Mapping PCF settings strip, NOT as new form fields):

    alex_HasExpiry           - master on/off: does this template's document
                               have a validity period at all. Default OFF so
                               existing templates are unaffected.
    alex_ExpiryDays          - default validity in days (used when HasExpiry
                               is on). 1..3650.
    alex_AllowExpiryOverride - may the sender change the validity (days) in
                               the send wizard at send time. Default OFF.

  Request-level column on alex_signaturerequest:

    alex_ExpiresOn           - the computed UTC expiry timestamp for this
                               request (= sent-on + effective days). The daily
                               monitor flow cancels open requests past it.

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- Template-level policy --------------------------------------------
$tpl = "alex_signaturetemplate"
Write-Output "== $tpl =="

Add-DVColumn $tpl (New-DVBool -Schema "alex_HasExpiry" -En "Document Has Expiry" -He "יש תוקף למסמך" `
    -DescEn "When on, documents sent from this template have a validity period and are expired automatically once it passes." `
    -DescHe "כאשר פעיל, למסמכים שנשלחים מתבנית זו יש תקופת תוקף והם פגי-תוקף אוטומטית בסיומה." `
    -Default $false)

Add-DVColumn $tpl (New-DVInt -Schema "alex_ExpiryDays" -En "Default Validity (Days)" -He "תוקף ברירת מחדל (ימים)" `
    -DescEn "Default number of days a sent document stays valid before it expires. Applies when 'Document Has Expiry' is on." `
    -DescHe "מספר הימים שבהם מסמך שנשלח נשאר בתוקף לפני שפג. חל כאשר 'יש תוקף למסמך' פעיל." `
    -Min 1 -Max 3650)

Add-DVColumn $tpl (New-DVBool -Schema "alex_AllowExpiryOverride" -En "Allow Changing Validity At Send" -He "אפשר שינוי תוקף בעת שליחה" `
    -DescEn "When on, the sender can change the validity (days) in the send wizard. When off, the template default is always used." `
    -DescHe "כאשר פעיל, השולח יכול לשנות את התוקף (ימים) באשף השליחה. כאשר כבוי, נעשה תמיד שימוש בברירת המחדל של התבנית." `
    -Default $false)

# ---- Request-level computed expiry ------------------------------------
$req = "alex_signaturerequest"
Write-Output "== $req =="

Add-DVColumn $req (New-DVDateTime -Schema "alex_ExpiresOn" -En "Expires On" -He "פג תוקף בתאריך" `
    -DescEn "The date and time this signature request expires. Computed at send time as sent-on plus the effective validity days. Empty when the template has no expiry." `
    -DescHe "התאריך והשעה שבהם בקשת החתימה פגת-תוקף. מחושב בזמן השליחה כתאריך השליחה בתוספת ימי התוקף האפקטיביים. ריק כאשר לתבנית אין תוקף.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
