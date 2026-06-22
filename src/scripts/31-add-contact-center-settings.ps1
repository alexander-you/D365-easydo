<#
  31-add-contact-center-settings.ps1

  Adds the "Contact Center integration" (אינטגרציה עם Dynamics 365 Contact Center)
  settings to the global settings singleton.

  During a live Contact Center conversation (msdyn_ocliveworkitem) the agent
  generates an easydo signing link and auto-sends it to the customer over the
  same conversation channel (chat / WhatsApp / SMS), then optionally watches the
  signing result in real-time. See docs/contact-center-integration.md.

  NEW COLUMNS on alex_easydosettings
  ----------------------------------
    alex_ContactCenterEnabled (bool, default false) - master switch. Enabling it
      is what exposes the "send for signature" button inside the agent session.
    alex_CcAgentReview        (bool, default false) - send behaviour default.
      false = send the link directly to the customer (toSendBox=false);
      true  = drop it in the agent sendbox for review (toSendBox=true).
    alex_CcRealtimeResults    (bool, default false) - when on, the agent watches
      the signing result live inside the conversation session.
    alex_CcDefaultCase        (bool, default false) - default document host when
      a case is linked to the conversation. false = always the linked contact;
      true = the linked case (incident) when one exists, else the contact.

  The conversation row (msdyn_ocliveworkitem) cannot host the document, so at
  send time the agent picks a durable host: the linked contact (msdyn_customer)
  or the linked case (msdyn_issueid -> incident).

  Idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$s = "alex_easydosettings"
Write-Output "== $s =="

Add-DVColumn $s (New-DVBool -Schema "alex_ContactCenterEnabled" -En "Enable Contact Center Signing" -He "אפשר חתימה ב-Contact Center" `
    -DescEn "When on, the 'send for signature' button is exposed inside the live conversation session so the agent can send a signing link over the active channel." `
    -DescHe "כאשר מופעל, כפתור 'שליחת מסמך לחתימה' נחשף בתוך סשן השיחה החיה, כך שהנציג יכול לשלוח קישור חתימה בערוץ הפעיל." `
    -TrueEn "On" -TrueHe "דלוק" -FalseEn "Off" -FalseHe "כבוי" -Default $false)

Add-DVColumn $s (New-DVBool -Schema "alex_CcAgentReview" -En "Agent Reviews Before Send" -He "אישור נציג לפני שליחה" `
    -DescEn "Default send behaviour in a conversation. Off = send the link directly to the customer; On = place it in the agent sendbox for review before sending." `
    -DescHe "התנהגות ברירת המחדל בשליחה בשיחה. כבוי = שליחת הקישור ישירות ללקוח; דלוק = הצבתו בתיבת הנציג לאישור לפני שליחה." `
    -TrueEn "Review" -TrueHe "אישור" -FalseEn "Direct" -FalseHe "ישיר" -Default $false)

Add-DVColumn $s (New-DVBool -Schema "alex_CcRealtimeResults" -En "Real-Time Results In Conversation" -He "תוצאות בזמן אמת בשיחה" `
    -DescEn "When on, the agent watches the signing result live inside the conversation session after the link is sent." `
    -DescHe "כאשר מופעל, הנציג עוקב אחר תוצאת החתימה בזמן אמת בתוך סשן השיחה לאחר שליחת הקישור." `
    -TrueEn "On" -TrueHe "דלוק" -FalseEn "Off" -FalseHe "כבוי" -Default $false)

Add-DVColumn $s (New-DVBool -Schema "alex_CcDefaultCase" -En "Default Host To Case" -He "ברירת מחדל לשיוך לאירוע" `
    -DescEn "The conversation cannot host the document, so the request is attached to a durable record. Off = always the linked contact; On = the linked case (incident) when one exists, otherwise the contact." `
    -DescHe "השיחה לא יכולה לארח את המסמך, ולכן הבקשה משויכת לרשומה קבועה. כבוי = תמיד איש הקשר המקושר; דלוק = האירוע המקושר כשקיים, אחרת איש הקשר." `
    -TrueEn "Case" -TrueHe "אירוע" -FalseEn "Contact" -FalseHe "איש קשר" -Default $false)

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. Published."
