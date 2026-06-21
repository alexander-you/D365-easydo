<#
  16-create-entityconfig-table.ps1

  Creates the per-entity "send enablement" configuration table used by the
  Form Send feature:

    alex_easydoentityconfig
      alex_name              (primary)  - friendly configuration name
      alex_entitylogicalname (string)   - target table logical name (e.g. contact)
      alex_entitydisplayname (string)   - friendly display name of the target table
      alex_sendenabled       (bool)     - when true, the "Send easydo document"
                                          ribbon button is injected on the target
                                          table's form; when false it is removed
      alex_deploymentstatus  (choice)   - Pending / Deploying / Deployed / Removed / Failed
      alex_statusmessage     (memo)     - last operation result or error detail

  Toggling alex_sendenabled is what triggers the background ribbon injection /
  removal Custom API. This script only builds the metadata; it is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1. deployment status global choice ---------------------------------
New-DVGlobalChoice -Name "alex_buttondeploymentstatus" `
    -En "Button Deployment Status" -He "סטטוס פריסת כפתור" `
    -DescEn "Tracks the background ribbon button deployment state for an entity configuration." `
    -DescHe "עוקב אחר מצב הפריסה ברקע של כפתור הריבון עבור תצורת יישות." `
    -Options @(
        @{ Value = 1; En = "Pending";   He = "ממתין";   DescEn = "No deployment has run yet.";                       DescHe = "טרם בוצעה פריסה." }
        @{ Value = 2; En = "Deploying"; He = "בפריסה";  DescEn = "The ribbon button is being added or removed in the background."; DescHe = "כפתור הריבון מתווסף או מוסר ברקע." }
        @{ Value = 3; En = "Deployed";  He = "נפרס";    DescEn = "The ribbon button is present on the target form.";  DescHe = "כפתור הריבון מופיע בטופס היעד." }
        @{ Value = 4; En = "Removed";   He = "הוסר";    DescEn = "The ribbon button has been removed from the target form."; DescHe = "כפתור הריבון הוסר מטופס היעד." }
        @{ Value = 5; En = "Failed";    He = "נכשל";    DescEn = "The last deployment attempt failed; see the status message."; DescHe = "ניסיון הפריסה האחרון נכשל; ראה את הודעת הסטטוס." }
    )

# ---- 2. table ------------------------------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Configuration Name" -He "שם תצורה" `
        -DescEn "Friendly name identifying this entity send configuration." `
        -DescHe "שם ידידותי המזהה את תצורת השליחה של היישות."
New-DVTable -Schema "alex_EasyDoEntityConfig" `
    -En "easydo Entity Configuration" -He "תצורת יישות easydo" `
    -CollEn "easydo Entity Configurations" -CollHe "תצורות יישות easydo" `
    -DescEn "Per-table configuration that controls whether the easydo 'Send document' form button is enabled for a Dynamics table." `
    -DescHe "תצורה פר-טבלה הקובעת האם כפתור 'שליחת מסמך easydo' מופעל בטופס של טבלת Dynamics." `
    -PrimaryName $pn

# ---- 3. columns ----------------------------------------------------------
$t = "alex_easydoentityconfig"
Write-Output "== $t =="
Add-DVColumn $t (New-DVString -Schema "alex_EntityLogicalName" -En "Table Logical Name" -He "שם לוגי של טבלה" -MaxLength 128 -Required "ApplicationRequired" `
    -DescEn "Logical name of the Dynamics table to enable the easydo send button on, for example contact." `
    -DescHe "השם הלוגי של טבלת Dynamics שעליה יופעל כפתור השליחה של easydo, לדוגמה contact.")
Add-DVColumn $t (New-DVString -Schema "alex_EntityDisplayName" -En "Table Display Name" -He "שם תצוגה של טבלה" -MaxLength 200 `
    -DescEn "Friendly display name of the target table, shown to administrators." `
    -DescHe "שם תצוגה ידידותי של טבלת היעד, המוצג למנהלי מערכת.")
Add-DVColumn $t (New-DVBool -Schema "alex_SendEnabled" -En "Send Enabled" -He "שליחה מופעלת" -Default $false `
    -TrueEn "Enabled" -TrueHe "מופעל" -FalseEn "Disabled" -FalseHe "מושבת" `
    -DescEn "When enabled, the 'Send easydo document' button is added to this table's form. Disabling removes it." `
    -DescHe "כאשר מופעל, כפתור 'שליחת מסמך easydo' מתווסף לטופס הטבלה. השבתה מסירה אותו.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_DeploymentStatus" -En "Deployment Status" -He "סטטוס פריסה" -GlobalOptionSetName "alex_buttondeploymentstatus" `
    -DescEn "Current state of the background ribbon button deployment for this table." `
    -DescHe "המצב הנוכחי של פריסת כפתור הריבון ברקע עבור טבלה זו.")
Add-DVColumn $t (New-DVMemo -Schema "alex_StatusMessage" -En "Status Message" -He "הודעת סטטוס" -MaxLength 2000 `
    -DescEn "Result or error detail from the last ribbon deployment attempt." `
    -DescHe "פירוט תוצאה או שגיאה מניסיון פריסת הריבון האחרון.")

Write-Output "Done."
