<#
  Creates the 6 tables of the D365 easydo data model (table + primary name only).
  Columns and relationships are added by later scripts.
  - 5 standard business tables
  - alex_integrationlog as an ELASTIC table (high-volume append-only telemetry)
  All tables are added to the alex_d365_easydo solution with bilingual labels.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# 1) Signature Template -----------------------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Template Name" -He "שם תבנית" `
        -DescEn "Friendly name that identifies this signature template to users." `
        -DescHe "שם ידידותי המזהה את תבנית החתימה עבור המשתמשים."
New-DVTable -Schema "alex_SignatureTemplate" `
    -En "Signature Template" -He "תבנית חתימה" `
    -CollEn "Signature Templates" -CollHe "תבניות חתימה" `
    -DescEn "Reusable EasyDoc template configuration that defines how a type of document is prepared and sent for signature." `
    -DescHe "תצורת תבנית EasyDoc לשימוש חוזר המגדירה כיצד מסמך מסוג מסוים מוכן ונשלח לחתימה." `
    -PrimaryName $pn

# 2) Signature Request ------------------------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Request Name" -He "שם בקשה" `
        -DescEn "Auto- or user-generated name identifying this signature request." `
        -DescHe "שם שנוצר אוטומטית או ידנית המזהה את בקשת החתימה."
New-DVTable -Schema "alex_SignatureRequest" `
    -En "Signature Request" -He "בקשת חתימה" `
    -CollEn "Signature Requests" -CollHe "בקשות חתימה" `
    -DescEn "A single request to obtain a digital signature on a document for a related Dynamics record." `
    -DescHe "בקשה בודדת לקבלת חתימה דיגיטלית על מסמך עבור רשומת Dynamics משויכת." `
    -PrimaryName $pn -HasNotes $true

# 3) Template Field Mapping -------------------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Mapping Name" -He "שם מיפוי" `
        -DescEn "Name identifying this field mapping between Dynamics and an EasyDoc template field." `
        -DescHe "שם המזהה את מיפוי השדה בין Dynamics לשדה בתבנית EasyDoc."
New-DVTable -Schema "alex_TemplateFieldMapping" `
    -En "Template Field Mapping" -He "מיפוי שדות תבנית" `
    -CollEn "Template Field Mappings" -CollHe "מיפויי שדות תבנית" `
    -DescEn "Defines how a Dynamics field value is mapped into a field of an EasyDoc template before sending." `
    -DescHe "מגדיר כיצד ערך שדה ב-Dynamics ממופה לשדה בתבנית EasyDoc לפני השליחה." `
    -PrimaryName $pn

# 4) Signature Recipient ----------------------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Recipient Name" -He "שם נמען" `
        -DescEn "Display name of the person who is required to sign." `
        -DescHe "שם התצוגה של האדם הנדרש לחתום."
New-DVTable -Schema "alex_SignatureRecipient" `
    -En "Signature Recipient" -He "נמען לחתימה" `
    -CollEn "Signature Recipients" -CollHe "נמענים לחתימה" `
    -DescEn "A person who must sign a signature request, linked to a Dynamics contact or entered as an external recipient." `
    -DescHe "אדם הנדרש לחתום על בקשת חתימה, המקושר לאיש קשר ב-Dynamics או שהוזן כנמען חיצוני." `
    -PrimaryName $pn

# 5) Signature Document -----------------------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Document Name" -He "שם מסמך" `
        -DescEn "Display name of the stored document file." `
        -DescHe "שם התצוגה של קובץ המסמך השמור."
New-DVTable -Schema "alex_SignatureDocument" `
    -En "Signature Document" -He "מסמך חתימה" `
    -CollEn "Signature Documents" -CollHe "מסמכי חתימה" `
    -DescEn "A document file associated with a signature request, such as the original, a preview, or the final signed copy." `
    -DescHe "קובץ מסמך המשויך לבקשת חתימה, כגון המקור, תצוגה מקדימה או העותק החתום הסופי." `
    -PrimaryName $pn -HasNotes $true

# 6) Integration Log (ELASTIC) ---------------------------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Log Title" -He "כותרת יומן" `
        -DescEn "Short title summarizing the logged integration event." `
        -DescHe "כותרת קצרה המסכמת את אירוע האינטגרציה שנרשם."
New-DVTable -Schema "alex_IntegrationLog" `
    -En "Integration Log" -He "יומן אינטגרציה" `
    -CollEn "Integration Logs" -CollHe "יומני אינטגרציה" `
    -DescEn "High-volume telemetry record capturing each call and status update exchanged with EasyDoc, used for support and troubleshooting." `
    -DescHe "רשומת טלמטריה בנפח גבוה התופסת כל קריאה ועדכון סטטוס מול EasyDoc, לשימוש תמיכה ואבחון תקלות." `
    -PrimaryName $pn -TableType "Elastic"

Write-Output "All tables processed."
