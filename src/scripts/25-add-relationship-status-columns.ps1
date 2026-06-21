<#
  25-add-relationship-status-columns.ps1

  Adds the columns the admin center needs to track the per-table native lookup
  (alex_Related<table>Id on alex_signaturerequest) that is provisioned when an
  administrator enables a NEW table for sending.

  Creating that lookup is a metadata operation that is NOT easily reversible, so
  the admin center warns first, then calls the alex_EnsureSignatureLookup Custom
  API. These columns store the outcome so the card can show an honest status.

  New global choice:
    alex_relationshipstatus
      1 Not Created / לא נוצר   - no dedicated lookup has been provisioned yet
      2 Creating    / ביצירה    - the Custom API call is in flight
      3 Created     / נוצר       - the lookup + relationship exist
      4 Failed      / נכשל       - the last provisioning attempt failed (see message)

  New columns on alex_easydoentityconfig:
    alex_relationshipstatus      (choice)  - state of the dedicated lookup
    alex_relationshipschemaname  (string)  - schema name of the created lookup/relationship

  Idempotent (Add-DVColumn / New-DVGlobalChoice skip existing).
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1. relationship status global choice -------------------------------
New-DVGlobalChoice -Name "alex_relationshipstatus" `
    -En "Signature Lookup Status" -He "סטטוס קשר בקשת חתימה" `
    -DescEn "Tracks whether the dedicated native lookup from this table to the signature request has been provisioned." `
    -DescHe "עוקב אחר האם נוצר קשר (Lookup) ייעודי מהטבלה הזו אל בקשת החתימה." `
    -Options @(
        @{ Value = 1; En = "Not Created"; He = "לא נוצר"; DescEn = "No dedicated lookup has been provisioned for this table yet."; DescHe = "טרם נוצר קשר ייעודי עבור טבלה זו." }
        @{ Value = 2; En = "Creating";    He = "ביצירה";  DescEn = "The lookup is being provisioned in the background."; DescHe = "הקשר נוצר כעת ברקע." }
        @{ Value = 3; En = "Created";     He = "נוצר";    DescEn = "The dedicated lookup and relationship exist on the signature request."; DescHe = "הקשר הייעודי קיים על בקשת החתימה." }
        @{ Value = 4; En = "Failed";      He = "נכשל";    DescEn = "The last provisioning attempt failed; see the status message."; DescHe = "ניסיון היצירה האחרון נכשל; ראה את הודעת הסטטוס." }
    )

# ---- 2. columns ----------------------------------------------------------
$t = "alex_easydoentityconfig"
Write-Output "== extending $t =="

Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_RelationshipStatus" -En "Signature Lookup Status" -He "סטטוס קשר בקשת חתימה" -GlobalOptionSetName "alex_relationshipstatus" `
    -DescEn "State of the dedicated native lookup from this table to the signature request." `
    -DescHe "מצב הקשר הייעודי (Lookup) מטבלה זו אל בקשת החתימה.")

Add-DVColumn $t (New-DVString -Schema "alex_RelationshipSchemaName" -En "Signature Lookup Schema Name" -He "שם סכמת הקשר" -MaxLength 128 `
    -DescEn "Schema name of the dedicated lookup/relationship created for this table (e.g. alex_RelatedAccountId)." `
    -DescHe "שם הסכמה של הקשר הייעודי שנוצר עבור טבלה זו (לדוגמה alex_RelatedAccountId).")

Write-Output "Done."
