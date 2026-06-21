<#
  28-add-primary-channel.ps1

  Evolves the channel model (scripts 26 + 27) into a "primary + additional"
  shape, confirmed with the customer:

    * PRIMARY easydo channel  - exactly ONE of email / sms / whatsapp. easydo
      notifies the recipient NATIVELY on this channel (notify_platform = the
      chosen value). No CIJ / Flow declaration is required for it.
    * ADDITIONAL channels      - any of the OTHER channels the org also wants the
      signing link distributed over. These are self-distributed (declarative)
      through CIJ or a Power Automate Flow, exactly like script 27 already does
      for SMS / WhatsApp. Email can now ALSO be an additional channel, so it gets
      its own distribution columns for symmetry.

  NEW GLOBAL CHOICE
  ------------------
  alex_easydochannel : Email (626210000) / SMS (626210001) / WhatsApp (626210002)

  NEW COLUMNS on alex_easydosettings
  ----------------------------------
    alex_EasydoChannel      (choice alex_easydochannel)  - the primary channel
    alex_EmailMethod        (choice alex_distributionmethod) - when email is additional
    alex_EmailJourneyName   (string)                         - CIJ journey for email
    alex_EmailFlowId        (lookup -> workflow)             - Flow for email

  NEW COLUMN on alex_signaturerequest
  -----------------------------------
    alex_EasydoChannel      (choice alex_easydochannel)  - primary channel snapshot
      captured at send time, mapped to notify_platform by the Send flow.

  Idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1. Primary channel global choice ------------------------------------
New-DVGlobalChoice -Name "alex_easydochannel" `
    -En "easydo Channel" -He "ערוץ easydo" `
    -DescEn "The single channel easydo uses to natively notify the recipient (maps to notify_platform)." `
    -DescHe "הערוץ היחיד ש-easydo משתמש בו כדי להודיע לנמען באופן נייטיב (ממופה ל-notify_platform)." `
    -Options @(
        @{ Value = 626210000; En = "Email"; He = "דוא""ל";
           DescEn = "easydo notifies the recipient by email."; DescHe = "easydo מודיע לנמען בדוא""ל." },
        @{ Value = 626210001; En = "SMS"; He = "SMS";
           DescEn = "easydo notifies the recipient by SMS."; DescHe = "easydo מודיע לנמען ב-SMS." },
        @{ Value = 626210002; En = "WhatsApp"; He = "WhatsApp";
           DescEn = "easydo notifies the recipient by WhatsApp."; DescHe = "easydo מודיע לנמען ב-WhatsApp." }
    )

# ---- 2. Primary channel on the settings singleton ------------------------
$s = "alex_easydosettings"
Write-Output "== $s =="

Add-DVColumn $s (New-DVPicklistGlobal -Schema "alex_EasydoChannel" -En "Primary easydo Channel" -He "ערוץ easydo ראשי" `
    -GlobalOptionSetName "alex_easydochannel" `
    -DescEn "The single channel easydo notifies the recipient on natively. The remaining channels can be added as additional (declarative) channels." `
    -DescHe "הערוץ היחיד ש-easydo מודיע עליו לנמען באופן נייטיב. שאר הערוצים ניתנים להוספה כערוצים נוספים (הצהרתיים).")

# ---- 3. Email distribution columns (email as an additional channel) ------
Add-DVColumn $s (New-DVPicklistGlobal -Schema "alex_EmailMethod" -En "Email Distribution Method" -He "שיטת הפצה לדוא""ל" `
    -GlobalOptionSetName "alex_distributionmethod" `
    -DescEn "How the email channel distributes the signing link (CIJ or Flow) when email is an additional channel." `
    -DescHe "כיצד ערוץ הדוא""ל מפיץ את קישור החתימה (CIJ או Flow) כאשר הדוא""ל הוא ערוץ נוסף.")
Add-DVColumn $s (New-DVString -Schema "alex_EmailJourneyName" -En "Email Journey Name" -He "שם מסע לדוא""ל" -MaxLength 200 `
    -DescEn "Name of the Customer Insights - Journeys journey that distributes the email link (used when the email method is CIJ)." `
    -DescHe "שם המסע ב-Customer Insights - Journeys שמפיץ את קישור הדוא""ל (בשימוש כאשר שיטת הדוא""ל היא CIJ).")
New-DVLookup -Schema "alex_EmailFlowId" -En "Email Flow" -He "Flow לדוא""ל" `
    -DescEn "The Power Automate flow that distributes the email link (used when the email method is Flow)." `
    -DescHe "זרימת Power Automate שמפיצה את קישור הדוא""ל (בשימוש כאשר שיטת הדוא""ל היא Flow)." `
    -ReferencedTable "workflow" -ReferencingTable $s `
    -RelationshipName "alex_easydosettings_emailflow_workflow"

# ---- 4. Primary channel snapshot on the request --------------------------
$q = "alex_signaturerequest"
Write-Output "== $q =="
Add-DVColumn $q (New-DVPicklistGlobal -Schema "alex_EasydoChannel" -En "Primary easydo Channel" -He "ערוץ easydo ראשי" `
    -GlobalOptionSetName "alex_easydochannel" `
    -DescEn "The primary easydo channel captured at send time. The Send flow maps it to notify_platform." `
    -DescHe "ערוץ ה-easydo הראשי שנלכד בזמן השליחה. זרימת השליחה ממפה אותו ל-notify_platform.")

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. Published."
