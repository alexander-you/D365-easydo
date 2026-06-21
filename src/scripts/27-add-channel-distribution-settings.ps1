<#
  27-add-channel-distribution-settings.ps1

  Adds the "distribution governance" layer on top of the multi-channel feature
  (script 26). This is a DECLARATION / GOVERNANCE layer, not an execution layer.

  WHY
  ----
  easydo sends ONE notification channel per recipient. When the org wants a
  signing link delivered over SMS / WhatsApp, our product does NOT actually send
  those messages - the link is generated (notify_platform null) and distribution
  is the customer's responsibility, performed through:
    - Customer Insights - Journeys (CIJ), or
    - a Power Automate Flow the organisation built.

  So when an administrator allows SMS or WhatsApp they must DECLARE how that
  channel is distributed and point at the concrete journey / flow. This makes the
  toggle a real commitment (the admin must pick an existing flow) rather than a
  meaningless checkbox.

  DESIGN DECISION (import portability)
  ------------------------------------
  A lookup to the CIJ journey table (msdynmkt_journey) would create a HARD
  dependency: the solution would fail to import on any environment without
  Customer Insights - Journeys installed. To stay portable:
    - Flow target  => real lookup to `workflow` (a core Dataverse table, always
      present). The admin center filters it to Modern cloud flows (category 5,
      type 1).
    - CIJ target   => a free-text journey name (no table dependency).

  NEW GLOBAL CHOICE
  ------------------
  alex_distributionmethod : CIJ (1) / Flow (2)

  NEW COLUMNS on alex_easydosettings (per non-fallback channel)
  -------------------------------------------------------------
  SMS:
    alex_SmsMethod        (choice alex_distributionmethod)
    alex_SmsFlowId        (lookup -> workflow)        - used when method = Flow
    alex_SmsJourneyName   (string)                    - used when method = CIJ
  WhatsApp:
    alex_WhatsAppMethod   (choice alex_distributionmethod)
    alex_WhatsAppFlowId   (lookup -> workflow)        - used when method = Flow
    alex_WhatsAppJourneyName (string)                 - used when method = CIJ

  NEW COLUMN on alex_signaturerequest
  -----------------------------------
  alex_ChannelDeclaration (memo) - JSON snapshot of the channels + distribution
    method + target name declared at send time, kept for historical audit even
    if the global settings later change.

  Email is the locked fallback channel (easydo native) and needs no distribution
  declaration.

  Idempotent (every helper checks for existence first).
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1. Distribution method global choice --------------------------------
New-DVGlobalChoice -Name "alex_distributionmethod" `
    -En "Distribution Method" -He "שיטת הפצה" `
    -DescEn "How a non-email signing-link channel is distributed by the organisation." `
    -DescHe "כיצד ערוץ הפצה (שאינו דוא""ל) של קישור החתימה מופץ על-ידי הארגון." `
    -Options @(
        @{ Value = 626210000; En = "Customer Insights - Journeys (CIJ)"; He = "מסעות לקוח (CIJ)";
           DescEn = "Distributed through a Customer Insights - Journeys journey."; DescHe = "מופץ דרך מסע ב-Customer Insights - Journeys." },
        @{ Value = 626210001; En = "Power Automate Flow"; He = "זרימת Power Automate";
           DescEn = "Distributed through a Power Automate cloud flow the organisation built."; DescHe = "מופץ דרך זרימת Power Automate שהארגון בנה." }
    )

# ---- 2. Distribution columns on the settings singleton -------------------
$s = "alex_easydosettings"
Write-Output "== $s =="

Add-DVColumn $s (New-DVPicklistGlobal -Schema "alex_SmsMethod" -En "SMS Distribution Method" -He "שיטת הפצה ל-SMS" `
    -GlobalOptionSetName "alex_distributionmethod" `
    -DescEn "How the SMS channel distributes the signing link (CIJ or Flow). Required when SMS is allowed." `
    -DescHe "כיצד ערוץ ה-SMS מפיץ את קישור החתימה (CIJ או Flow). חובה כאשר SMS מותר.")
Add-DVColumn $s (New-DVString -Schema "alex_SmsJourneyName" -En "SMS Journey Name" -He "שם מסע ל-SMS" -MaxLength 200 `
    -DescEn "Name of the Customer Insights - Journeys journey that distributes the SMS link (used when the SMS method is CIJ)." `
    -DescHe "שם המסע ב-Customer Insights - Journeys שמפיץ את קישור ה-SMS (בשימוש כאשר שיטת ה-SMS היא CIJ).")

Add-DVColumn $s (New-DVPicklistGlobal -Schema "alex_WhatsAppMethod" -En "WhatsApp Distribution Method" -He "שיטת הפצה ל-WhatsApp" `
    -GlobalOptionSetName "alex_distributionmethod" `
    -DescEn "How the WhatsApp channel distributes the signing link (CIJ or Flow). Required when WhatsApp is allowed." `
    -DescHe "כיצד ערוץ ה-WhatsApp מפיץ את קישור החתימה (CIJ או Flow). חובה כאשר WhatsApp מותר.")
Add-DVColumn $s (New-DVString -Schema "alex_WhatsAppJourneyName" -En "WhatsApp Journey Name" -He "שם מסע ל-WhatsApp" -MaxLength 200 `
    -DescEn "Name of the Customer Insights - Journeys journey that distributes the WhatsApp link (used when the WhatsApp method is CIJ)." `
    -DescHe "שם המסע ב-Customer Insights - Journeys שמפיץ את קישור ה-WhatsApp (בשימוש כאשר שיטת ה-WhatsApp היא CIJ).")

# ---- 3. Flow lookups (-> workflow, a core table that always exists) -------
New-DVLookup -Schema "alex_SmsFlowId" -En "SMS Flow" -He "Flow ל-SMS" `
    -DescEn "The Power Automate flow that distributes the SMS link (used when the SMS method is Flow)." `
    -DescHe "זרימת Power Automate שמפיצה את קישור ה-SMS (בשימוש כאשר שיטת ה-SMS היא Flow)." `
    -ReferencedTable "workflow" -ReferencingTable $s `
    -RelationshipName "alex_easydosettings_smsflow_workflow"
New-DVLookup -Schema "alex_WhatsAppFlowId" -En "WhatsApp Flow" -He "Flow ל-WhatsApp" `
    -DescEn "The Power Automate flow that distributes the WhatsApp link (used when the WhatsApp method is Flow)." `
    -DescHe "זרימת Power Automate שמפיצה את קישור ה-WhatsApp (בשימוש כאשר שיטת ה-WhatsApp היא Flow)." `
    -ReferencedTable "workflow" -ReferencingTable $s `
    -RelationshipName "alex_easydosettings_whatsappflow_workflow"

# ---- 4. Declaration snapshot on the request ------------------------------
$q = "alex_signaturerequest"
Write-Output "== $q =="
Add-DVColumn $q (New-DVMemo -Schema "alex_ChannelDeclaration" -En "Channel Declaration" -He "הצהרת ערוצים" -MaxLength 4000 `
    -DescEn "JSON snapshot of the channels and their declared distribution method / target captured at send time, kept for audit." `
    -DescHe "תמונת JSON של הערוצים ושיטת/יעד ההפצה המוצהרים שנלכדו בזמן השליחה, נשמר לתיעוד.")

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. Published."
