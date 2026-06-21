<#
  26-create-global-send-settings.ps1

  Adds the global send settings singleton + the columns the multi-channel
  notification feature needs.

  WHY
  ----
  The admin center gets a new "Global Send Settings" panel where an administrator
  decides, org-wide:
    - master on/off bit for the multi-channel feature
    - whether SMS notifications are allowed
    - whether WhatsApp notifications are allowed
  Email is always allowed (the easydo default channel) and is exposed as a flag
  for completeness.

  The send wizard then shows per-send channel checkboxes (email / SMS / WhatsApp),
  but only the channels the global settings allow. easydo only accepts a single
  notify_platform per assignee, so when more than one channel is chosen the send
  flow generates the signing link with NO easydo notification (notify_platform
  null) and the link is distributed over every chosen channel by the client's
  own service. SMS / WhatsApp need a phone number, pulled automatically from the
  contact (mobilephone, then telephone1).

  NEW TABLE
  ----------
  alex_easydosettings (Standard, UserOwned) - a singleton; the admin center reads
  the first row and creates one if none exists.
    alex_Name                (primary)  - fixed label
    alex_MultiChannelEnabled (bool)     - master on/off for the whole feature
    alex_AllowEmail          (bool=on)  - email channel allowed
    alex_AllowSms            (bool=off) - SMS channel allowed
    alex_AllowWhatsApp       (bool=off) - WhatsApp channel allowed

  NEW COLUMNS
  ------------
  alex_signaturerecipient:
    alex_Phone               (string, Phone) - recipient phone for SMS / WhatsApp
  alex_signaturerequest:
    alex_ChannelEmail        (bool=on)  - send notification by email
    alex_ChannelSms          (bool=off) - send notification by SMS
    alex_ChannelWhatsApp     (bool=off) - send notification by WhatsApp

  Idempotent (every helper checks for existence first).
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1. Global send settings singleton table -----------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Name" -He "שם" `
        -DescEn "Name of the settings row (a single global row is used)." `
        -DescHe "שם שורת ההגדרות (נעשה שימוש בשורה גלובלית אחת)."
New-DVTable -Schema "alex_EasyDoSettings" `
    -En "easydo Settings" -He "הגדרות easydo" `
    -CollEn "easydo Settings" -CollHe "הגדרות easydo" `
    -DescEn "Global, org-wide settings for easydo sending, including which notification channels are allowed." `
    -DescHe "הגדרות גלובליות לכל הארגון עבור שליחת easydo, כולל אילו ערוצי התראה מותרים." `
    -PrimaryName $pn

$s = "alex_easydosettings"
Write-Output "== $s =="
Add-DVColumn $s (New-DVBool -Schema "alex_MultiChannelEnabled" -En "Multi-Channel Sending Enabled" -He "שליחה רב-ערוצית מופעלת" `
    -TrueEn "On" -TrueHe "דלוק" -FalseEn "Off" -FalseHe "כבוי" -Default $false `
    -DescEn "Master on/off switch for the multi-channel notification feature. When off, documents are sent only by email (the easydo default)." `
    -DescHe "מתג ראשי להפעלה/כיבוי של שליחה רב-ערוצית. כאשר כבוי, מסמכים נשלחים רק בדוא\""ל (ברירת המחדל של easydo).")
Add-DVColumn $s (New-DVBool -Schema "alex_AllowEmail" -En "Allow Email" -He "אפשר דוא\""ל" `
    -TrueEn "Allowed" -TrueHe "מותר" -FalseEn "Blocked" -FalseHe "חסום" -Default $true `
    -DescEn "Whether the email notification channel is offered in the send wizard." `
    -DescHe "האם ערוץ ההתראה בדוא\""ל מוצע באשף השליחה.")
Add-DVColumn $s (New-DVBool -Schema "alex_AllowSms" -En "Allow SMS" -He "אפשר SMS" `
    -TrueEn "Allowed" -TrueHe "מותר" -FalseEn "Blocked" -FalseHe "חסום" -Default $false `
    -DescEn "Whether the SMS notification channel is offered in the send wizard." `
    -DescHe "האם ערוץ ההתראה ב-SMS מוצע באשף השליחה.")
Add-DVColumn $s (New-DVBool -Schema "alex_AllowWhatsApp" -En "Allow WhatsApp" -He "אפשר וואטסאפ" `
    -TrueEn "Allowed" -TrueHe "מותר" -FalseEn "Blocked" -FalseHe "חסום" -Default $false `
    -DescEn "Whether the WhatsApp notification channel is offered in the send wizard." `
    -DescHe "האם ערוץ ההתראה בוואטסאפ מוצע באשף השליחה.")

# ---- 2. Recipient phone ---------------------------------------------------
$r = "alex_signaturerecipient"
Write-Output "== $r =="
Add-DVColumn $r (New-DVString -Schema "alex_Phone" -En "Phone" -He "טלפון" -MaxLength 50 -Format "Phone" `
    -DescEn "Recipient phone number used for SMS / WhatsApp notifications (pulled from the contact's mobile or business phone)." `
    -DescHe "מספר הטלפון של הנמען לשליחת התראות SMS / וואטסאפ (נשלף מהטלפון הנייד או העסקי של איש הקשר).")

# ---- 3. Request channel flags --------------------------------------------
$q = "alex_signaturerequest"
Write-Output "== $q =="
Add-DVColumn $q (New-DVBool -Schema "alex_ChannelEmail" -En "Notify By Email" -He "התראה בדוא\""ל" `
    -TrueEn "Yes" -TrueHe "כן" -FalseEn "No" -FalseHe "לא" -Default $true `
    -DescEn "Send the signing link to recipients by email." `
    -DescHe "שליחת קישור החתימה לנמענים בדוא\""ל.")
Add-DVColumn $q (New-DVBool -Schema "alex_ChannelSms" -En "Notify By SMS" -He "התראה ב-SMS" `
    -TrueEn "Yes" -TrueHe "כן" -FalseEn "No" -FalseHe "לא" -Default $false `
    -DescEn "Send the signing link to recipients by SMS." `
    -DescHe "שליחת קישור החתימה לנמענים ב-SMS.")
Add-DVColumn $q (New-DVBool -Schema "alex_ChannelWhatsApp" -En "Notify By WhatsApp" -He "התראה בוואטסאפ" `
    -TrueEn "Yes" -TrueHe "כן" -FalseEn "No" -FalseHe "לא" -Default $false `
    -DescEn "Send the signing link to recipients by WhatsApp." `
    -DescHe "שליחת קישור החתימה לנמענים בוואטסאפ.")

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. Global send settings singleton + channel columns created and published."
