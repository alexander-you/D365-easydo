<#
  Adds the per-request field value table that powers prefill (and later read-back).

  alex_SignatureFieldValue holds, for a single signature request, the concrete
  value that should be pushed into (Prefill) or read back from (Read Back) an
  individual easydo form field. The send flow reads the Prefill rows and builds
  the prefill_data array sent to easydo; Read Back rows capture what the
  recipient entered.

  Idempotent: every helper checks for existence first. All components are added
  to the alex_d365_easydo solution and published at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ----- 1) Global choice: field value direction ----------------------------
New-DVGlobalChoice -Name "alex_fielddirection" `
    -En "Field Value Direction" -He "כיוון ערך שדה" `
    -DescEn "Whether this field value is pushed into the form before sending (prefill) or captured from what the recipient entered (read back)." `
    -DescHe "האם ערך השדה מוזרק לטופס לפני השליחה (מילוי מקדים) או נקלט ממה שהנמען הזין (קריאה חזרה)." `
    -Options @(
        @{ Value=626210000; En="Prefill";   He="מילוי מקדים"; DescEn="The value is sent to easydo to pre-fill the field before the recipient opens the form."; DescHe="הערך נשלח ל-easydo כדי למלא מראש את השדה לפני שהנמען פותח את הטופס." }
        @{ Value=626210001; En="Read Back"; He="קריאה חזרה"; DescEn="The value captured from the field after the recipient filled and submitted the form."; DescHe="הערך שנקלט מהשדה לאחר שהנמען מילא ושלח את הטופס." }
        @{ Value=626210002; En="Bidirectional"; He="דו-כיווני"; DescEn="The value is both prefilled into the form before sending and read back afterwards, so an edit by the recipient updates Dynamics 365."; DescHe="הערך גם ממולא מראש בטופס לפני השליחה וגם נקרא חזרה לאחר מכן, כך שעריכה של הנמען מעדכנת את Dynamics 365." }
    )

# ----- 2) Table: Signature Field Value ------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Field Value Name" -He "שם ערך שדה" `
        -DescEn "Name identifying this field value row (usually the field label)." `
        -DescHe "שם המזהה את שורת ערך השדה (בדרך כלל תווית השדה)."
New-DVTable -Schema "alex_SignatureFieldValue" `
    -En "Signature Field Value" -He "ערך שדה חתימה" `
    -CollEn "Signature Field Values" -CollHe "ערכי שדה חתימה" `
    -DescEn "A concrete value for a single easydo form field on a specific signature request, used to prefill the field before sending or to record what the recipient entered." `
    -DescHe "ערך מוחשי לשדה טופס בודד ב-easydo עבור בקשת חתימה מסוימת, המשמש למילוי מקדים של השדה לפני השליחה או לתיעוד מה שהנמען הזין." `
    -PrimaryName $pn

# ----- 3) Columns ----------------------------------------------------------
$t = "alex_signaturefieldvalue"
Write-Output "== $t =="
Add-DVColumn $t (New-DVString -Schema "alex_FieldName" -En "easydo Field Name" -He "שם שדה easydo" -MaxLength 100 -Required "ApplicationRequired" `
    -DescEn "Technical name of the easydo form field this value targets (matches the easydo Field Id on the template field mapping, e.g. custom_field_6a32cedc7ede2)." `
    -DescHe "השם הטכני של שדה הטופס ב-easydo שאליו מכוון הערך (תואם למזהה שדה easydo במיפוי שדות התבנית, לדוגמה custom_field_6a32cedc7ede2).")
Add-DVColumn $t (New-DVString -Schema "alex_FieldLabel" -En "Field Label" -He "תווית שדה" -MaxLength 200 `
    -DescEn "Human-readable label of the field, shown to make the value easy to recognize." `
    -DescHe "תווית קריאה של השדה, המוצגת כדי להקל על זיהוי הערך.")
Add-DVColumn $t (New-DVMemo -Schema "alex_Value" -En "Value" -He "ערך" -MaxLength 4000 `
    -DescEn "The value to prefill into the field, or the value read back from it. For a checkbox use 'checked' or 'unchecked'." `
    -DescHe "הערך למילוי מקדים בשדה, או הערך שנקרא ממנו. עבור תיבת סימון השתמש ב-'checked' או 'unchecked'.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_Direction" -En "Direction" -He "כיוון" -GlobalOptionSetName "alex_fielddirection" -Required "ApplicationRequired" `
    -DescEn "Whether this row is used to prefill the field before sending or to record the value read back after signing." `
    -DescHe "האם שורה זו משמשת למילוי מקדים של השדה לפני השליחה או לתיעוד הערך שנקרא לאחר החתימה.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsReadOnly" -En "Lock For Recipient" -He "נעול לנמען" `
    -TrueEn "Locked" -TrueHe "נעול" -FalseEn "Editable" -FalseHe "ניתן לעריכה" `
    -DescEn "When enabled, the prefilled value is locked so the recipient cannot edit it (use for values that came from Dynamics 365)." `
    -DescHe "כאשר מופעל, הערך שמולא מראש נעול כך שהנמען לא יכול לערוך אותו (לשימוש עבור ערכים שהגיעו מ-Dynamics 365).")

# ----- 4) Relationship: Signature Request (1) -> Field Value (N) -----------
New-DVLookup -Schema "alex_SignatureRequestId" -En "Signature Request" -He "בקשת חתימה" `
    -DescEn "The signature request this field value belongs to." `
    -DescHe "בקשת החתימה שאליה שייך ערך שדה זה." `
    -ReferencedTable "alex_signaturerequest" -ReferencingTable "alex_signaturefieldvalue" `
    -RelationshipName "alex_signaturerequest_signaturefieldvalue" -Required "ApplicationRequired"

Write-Output "All field value components processed."
