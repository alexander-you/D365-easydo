<#
  Adds business columns to all tables. Lookups/relationships are created
  separately (06). The File column is added separately (07).
  Every column has English + Hebrew display name and description.
  Admin/support-only fields are described as such but kept off end-user noise.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ========================= 1) Signature Template =========================
$t = "alex_signaturetemplate"
Write-Output "== $t =="
Add-DVColumn $t (New-DVString  -Schema "alex_ExternalTemplateId" -En "EasyDoc Template Id" -He "מזהה תבנית EasyDoc" -MaxLength 100 `
    -DescEn "Identifier of the corresponding template in EasyDoc. Used by the integration to send documents; managed by administrators." `
    -DescHe "מזהה התבנית התואמת ב-EasyDoc. משמש את האינטגרציה לשליחת מסמכים; מנוהל על ידי מנהלי מערכת.")
Add-DVColumn $t (New-DVString  -Schema "alex_RelatedDynamicsTable" -En "Related Dynamics Table" -He "טבלת Dynamics משויכת" -MaxLength 100 `
    -DescEn "Logical name of the Dynamics table this template is typically used with, e.g. contact." `
    -DescHe "השם הלוגי של טבלת Dynamics שאיתה משתמשים בתבנית בדרך כלל, לדוגמה איש קשר.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_Language" -En "Language" -He "שפה" -GlobalOptionSetName "alex_language" `
    -DescEn "Default language used when this template is sent for signature." `
    -DescHe "שפת ברירת המחדל המשמשת כאשר תבנית זו נשלחת לחתימה.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_DefaultDeliveryMethod" -En "Default Delivery Method" -He "אמצעי משלוח ברירת מחדל" -GlobalOptionSetName "alex_deliverymethod" `
    -DescEn "Channel used by default to deliver signature requests created from this template." `
    -DescHe "הערוץ המשמש כברירת מחדל למשלוח בקשות חתימה שנוצרו מתבנית זו.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsActive" -En "Active" -He "פעיל" -Default $true `
    -TrueEn "Active" -TrueHe "פעיל" -FalseEn "Inactive" -FalseHe "לא פעיל" `
    -DescEn "Indicates whether this template is available for creating new signature requests." `
    -DescHe "מציין האם התבנית זמינה ליצירת בקשות חתימה חדשות.")
Add-DVColumn $t (New-DVBool -Schema "alex_SupportsPreview" -En "Supports Preview" -He "תומך בתצוגה מקדימה" `
    -DescEn "Indicates whether a draft document can be previewed before the request is sent." `
    -DescHe "מציין האם ניתן להציג טיוטת מסמך בתצוגה מקדימה לפני שליחת הבקשה.")
Add-DVColumn $t (New-DVBool -Schema "alex_SupportsMultipleSigners" -En "Supports Multiple Signers" -He "תומך במספר חותמים" `
    -DescEn "Indicates whether this template allows more than one recipient to sign." `
    -DescHe "מציין האם תבנית זו מאפשרת ליותר מנמען אחד לחתום.")
Add-DVColumn $t (New-DVString -Schema "alex_TemplateVersion" -En "Template Version" -He "גרסת תבנית" -MaxLength 50 `
    -DescEn "Version label of the template as defined in EasyDoc, for change tracking." `
    -DescHe "תווית גרסה של התבנית כפי שהוגדרה ב-EasyDoc, למעקב אחר שינויים.")
Add-DVColumn $t (New-DVMemo -Schema "alex_TemplateSummary" -En "Description" -He "תיאור" -MaxLength 2000 `
    -DescEn "Business description of what this template is for and when to use it." `
    -DescHe "תיאור עסקי של מטרת התבנית ומתי להשתמש בה.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_LastSyncedOn" -En "Last Synced On" -He "סונכרן לאחרונה בתאריך" `
    -DescEn "Date and time the template details were last refreshed from EasyDoc." `
    -DescHe "התאריך והשעה שבהם פרטי התבנית רועננו לאחרונה מ-EasyDoc.")

# ========================= 2) Signature Request =========================
$t = "alex_signaturerequest"
Write-Output "== $t =="
Add-DVColumn $t (New-DVString -Schema "alex_RelatedRecordId" -En "Related Record Id" -He "מזהה רשומה משויכת" -MaxLength 100 `
    -DescEn "Unique identifier of the Dynamics record this signature request was created for. Maintained by the integration." `
    -DescHe "מזהה ייחודי של רשומת Dynamics שעבורה נוצרה בקשת החתימה. מתוחזק על ידי האינטגרציה.")
Add-DVColumn $t (New-DVString -Schema "alex_RelatedTableName" -En "Related Table Name" -He "שם טבלה משויכת" -MaxLength 100 `
    -DescEn "Logical name of the Dynamics table that the related record belongs to, e.g. contact." `
    -DescHe "השם הלוגי של טבלת Dynamics שאליה שייכת הרשומה המשויכת, לדוגמה איש קשר.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_Status" -En "Status" -He "סטטוס" -GlobalOptionSetName "alex_signaturestatus" -Required "ApplicationRequired" `
    -DescEn "Current stage of this signature request in the signing process, from draft through completion." `
    -DescHe "השלב הנוכחי של בקשת החתימה בתהליך החתימה, מטיוטה ועד השלמה.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_Language" -En "Language" -He "שפה" -GlobalOptionSetName "alex_language" `
    -DescEn "Language used for this request and the communication sent to the recipient." `
    -DescHe "השפה המשמשת לבקשה זו ולתקשורת הנשלחת לנמען.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalFormId" -En "EasyDoc Form Id" -He "מזהה טופס EasyDoc" -MaxLength 100 `
    -DescEn "Identifier of the form created in EasyDoc for this request. Used by the integration; managed by support." `
    -DescHe "מזהה הטופס שנוצר ב-EasyDoc עבור בקשה זו. משמש את האינטגרציה; מנוהל על ידי התמיכה.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalDocumentId" -En "EasyDoc Document Id" -He "מזהה מסמך EasyDoc" -MaxLength 100 `
    -DescEn "Identifier of the document in EasyDoc associated with this request. Used by support for troubleshooting." `
    -DescHe "מזהה המסמך ב-EasyDoc המשויך לבקשה זו. משמש את התמיכה לאבחון תקלות.")
Add-DVColumn $t (New-DVString -Schema "alex_SigningLink" -En "Signing Link" -He "קישור לחתימה" -MaxLength 500 -Format "Url" `
    -DescEn "Web link the recipient can use to open and sign the document." `
    -DescHe "קישור אינטרנט שבו הנמען יכול להשתמש כדי לפתוח ולחתום על המסמך.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsDraft" -En "Preview Mode" -He "מצב תצוגה מקדימה" `
    -DescEn "When enabled, the request is prepared as a draft for preview before it is actually sent to the recipient." `
    -DescHe "כאשר מופעל, הבקשה מוכנה כטיוטה לתצוגה מקדימה לפני שהיא נשלחת בפועל לנמען.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsPreviewGenerated" -En "Preview Generated" -He "נוצרה תצוגה מקדימה" `
    -DescEn "Indicates whether a preview document has already been generated for this request." `
    -DescHe "מציין האם כבר נוצר מסמך תצוגה מקדימה עבור בקשה זו.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_SentOn" -En "Sent On" -He "נשלח בתאריך" `
    -DescEn "Date and time the signature request was sent to the recipient." `
    -DescHe "התאריך והשעה שבהם בקשת החתימה נשלחה לנמען.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_CompletedOn" -En "Completed On" -He "הושלם בתאריך" `
    -DescEn "Date and time all required recipients finished signing." `
    -DescHe "התאריך והשעה שבהם כל הנמענים הנדרשים סיימו לחתום.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_CancelledOn" -En "Cancelled On" -He "בוטל בתאריך" `
    -DescEn "Date and time the request was cancelled, if applicable." `
    -DescHe "התאריך והשעה שבהם הבקשה בוטלה, אם רלוונטי.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_LastStatusCheckOn" -En "Last Status Check On" -He "בדיקת סטטוס אחרונה בתאריך" `
    -DescEn "Date and time the integration last checked this request's status with EasyDoc. Support field." `
    -DescHe "התאריך והשעה שבהם האינטגרציה בדקה לאחרונה את סטטוס הבקשה מול EasyDoc. שדה תמיכה.")
Add-DVColumn $t (New-DVInt -Schema "alex_RetryCount" -En "Retry Count" -He "מספר ניסיונות חוזרים" -Min 0 -Max 1000 `
    -DescEn "Number of times the integration retried sending or updating this request after a transient error. Support field." `
    -DescHe "מספר הפעמים שהאינטגרציה ניסתה שוב לשלוח או לעדכן בקשה זו לאחר שגיאה זמנית. שדה תמיכה.")
Add-DVColumn $t (New-DVString -Schema "alex_ErrorCode" -En "Error Code" -He "קוד שגיאה" -MaxLength 100 `
    -DescEn "Technical error code returned for the last failed operation. Used by support." `
    -DescHe "קוד שגיאה טכני שהוחזר עבור הפעולה האחרונה שנכשלה. משמש את התמיכה.")
Add-DVColumn $t (New-DVMemo -Schema "alex_ErrorMessage" -En "Error Details" -He "פרטי שגיאה" -MaxLength 2000 `
    -DescEn "Human-readable explanation of the last error, to help support resolve issues." `
    -DescHe "הסבר קריא של השגיאה האחרונה, לסיוע לתמיכה בפתרון בעיות.")

# ========================= 3) Template Field Mapping =========================
$t = "alex_templatefieldmapping"
Write-Output "== $t =="
Add-DVColumn $t (New-DVString -Schema "alex_ExternalFieldId" -En "EasyDoc Field Id" -He "מזהה שדה EasyDoc" -MaxLength 100 `
    -DescEn "Identifier of the field within the EasyDoc template that receives the mapped value. Managed by administrators." `
    -DescHe "מזהה השדה בתבנית EasyDoc שמקבל את הערך הממופה. מנוהל על ידי מנהלי מערכת.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalFieldName" -En "EasyDoc Field Name" -He "שם שדה EasyDoc" -MaxLength 200 `
    -DescEn "Display name of the EasyDoc template field, to make the mapping easy to recognize." `
    -DescHe "שם התצוגה של שדה תבנית EasyDoc, כדי להקל על זיהוי המיפוי.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalFieldType" -En "EasyDoc Field Type" -He "סוג שדה EasyDoc" -MaxLength 100 `
    -DescEn "Data type expected by the EasyDoc field, such as text, date or signature." `
    -DescHe "סוג הנתונים שהשדה ב-EasyDoc מצפה לו, כגון טקסט, תאריך או חתימה.")
Add-DVColumn $t (New-DVString -Schema "alex_DynamicsTable" -En "Dynamics Table" -He "טבלת Dynamics" -MaxLength 100 `
    -DescEn "Logical name of the Dynamics table the source value is read from." `
    -DescHe "השם הלוגי של טבלת Dynamics שממנה נקרא ערך המקור.")
Add-DVColumn $t (New-DVString -Schema "alex_DynamicsField" -En "Dynamics Field" -He "שדה Dynamics" -MaxLength 100 `
    -DescEn "Logical name of the Dynamics column whose value is placed into the EasyDoc field." `
    -DescHe "השם הלוגי של עמודת Dynamics שערכה מוכנס לשדה ב-EasyDoc.")
Add-DVColumn $t (New-DVString -Schema "alex_DefaultValue" -En "Default Value" -He "ערך ברירת מחדל" -MaxLength 500 `
    -DescEn "Value used when the source Dynamics field is empty." `
    -DescHe "הערך המשמש כאשר שדה המקור ב-Dynamics ריק.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsRequired" -En "Required" -He "חובה" `
    -DescEn "Indicates whether this field must contain a value before the document can be sent." `
    -DescHe "מציין האם שדה זה חייב להכיל ערך לפני שניתן לשלוח את המסמך.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsEditableBeforeSend" -En "Editable Before Send" -He "ניתן לעריכה לפני משלוח" `
    -DescEn "Indicates whether a user may edit this value before the request is sent." `
    -DescHe "מציין האם משתמש רשאי לערוך ערך זה לפני שליחת הבקשה.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsVisibleToUser" -En "Visible To User" -He "גלוי למשתמש" `
    -DescEn "Indicates whether this mapped field is shown to the user preparing the request." `
    -DescHe "מציין האם השדה הממופה מוצג למשתמש המכין את הבקשה.")

# ========================= 4) Signature Recipient =========================
$t = "alex_signaturerecipient"
Write-Output "== $t =="
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_RecipientType" -En "Recipient Type" -He "סוג נמען" -GlobalOptionSetName "alex_recipienttype" `
    -DescEn "Whether this recipient is a Dynamics contact or an external person entered manually." `
    -DescHe "האם נמען זה הוא איש קשר ב-Dynamics או אדם חיצוני שהוזן ידנית.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalRecipientName" -En "External Recipient Name" -He "שם נמען חיצוני" -MaxLength 200 `
    -DescEn "Full name of the recipient when they are not a Dynamics contact." `
    -DescHe "השם המלא של הנמען כאשר הוא אינו איש קשר ב-Dynamics.")
Add-DVColumn $t (New-DVString -Schema "alex_Email" -En "Email" -He "דוא""ל" -MaxLength 200 -Format "Email" `
    -DescEn "Email address the signature request is delivered to." `
    -DescHe "כתובת הדוא""ל שאליה נשלחת בקשת החתימה.")
Add-DVColumn $t (New-DVString -Schema "alex_Phone" -En "Mobile Phone" -He "טלפון נייד" -MaxLength 50 -Format "Phone" `
    -DescEn "Mobile number used when the request is delivered by SMS." `
    -DescHe "מספר הנייד המשמש כאשר הבקשה נשלחת במסרון.")
Add-DVColumn $t (New-DVInt -Schema "alex_SigningOrder" -En "Signing Order" -He "סדר חתימה" -Min 1 -Max 100 `
    -DescEn "Order in which this recipient signs when multiple signers are required." `
    -DescHe "הסדר שבו נמען זה חותם כאשר נדרשים מספר חותמים.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_RecipientStatus" -En "Recipient Status" -He "סטטוס נמען" -GlobalOptionSetName "alex_recipientstatus" `
    -DescEn "Current signing progress of this recipient." `
    -DescHe "התקדמות החתימה הנוכחית של נמען זה.")
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_PreferredLanguage" -En "Preferred Language" -He "שפה מועדפת" -GlobalOptionSetName "alex_language" `
    -DescEn "Language used in the communication sent to this recipient." `
    -DescHe "השפה המשמשת בתקשורת הנשלחת לנמען זה.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalProfileId" -En "EasyDoc Profile Id" -He "מזהה פרופיל EasyDoc" -MaxLength 100 `
    -DescEn "Identifier of the recipient profile in EasyDoc. Used by the integration; support field." `
    -DescHe "מזהה פרופיל הנמען ב-EasyDoc. משמש את האינטגרציה; שדה תמיכה.")
Add-DVColumn $t (New-DVString -Schema "alex_RecipientSigningLink" -En "Signing Link" -He "קישור לחתימה" -MaxLength 500 -Format "Url" `
    -DescEn "Personal web link this recipient uses to open and sign the document." `
    -DescHe "קישור אינטרנט אישי שבו נמען זה משתמש כדי לפתוח ולחתום על המסמך.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_RecipientSentOn" -En "Sent On" -He "נשלח בתאריך" `
    -DescEn "Date and time the request was sent to this recipient." `
    -DescHe "התאריך והשעה שבהם הבקשה נשלחה לנמען זה.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_ViewedOn" -En "Viewed On" -He "נצפה בתאריך" `
    -DescEn "Date and time this recipient first opened the document." `
    -DescHe "התאריך והשעה שבהם נמען זה פתח את המסמך לראשונה.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_SignedOn" -En "Signed On" -He "נחתם בתאריך" `
    -DescEn "Date and time this recipient completed their signature." `
    -DescHe "התאריך והשעה שבהם נמען זה השלים את חתימתו.")

# ========================= 5) Signature Document =========================
$t = "alex_signaturedocument"
Write-Output "== $t =="
Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_DocumentType" -En "Document Type" -He "סוג מסמך" -GlobalOptionSetName "alex_documenttype" `
    -DescEn "Role of this document in the signing process: original, preview, signed or evidence." `
    -DescHe "תפקיד המסמך בתהליך החתימה: מקור, תצוגה מקדימה, חתום או ראיה.")
Add-DVColumn $t (New-DVString -Schema "alex_FileName" -En "File Name" -He "שם קובץ" -MaxLength 300 `
    -DescEn "Name of the document file as stored and presented to users." `
    -DescHe "שם קובץ המסמך כפי שהוא נשמר ומוצג למשתמשים.")
Add-DVColumn $t (New-DVString -Schema "alex_MimeType" -En "File Type" -He "סוג קובץ" -MaxLength 100 `
    -DescEn "Technical content type of the file, such as application/pdf." `
    -DescHe "סוג התוכן הטכני של הקובץ, כגון application/pdf.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalFileId" -En "EasyDoc File Id" -He "מזהה קובץ EasyDoc" -MaxLength 100 `
    -DescEn "Identifier of the file in EasyDoc this document was retrieved from. Support field." `
    -DescHe "מזהה הקובץ ב-EasyDoc שממנו הובא מסמך זה. שדה תמיכה.")
Add-DVColumn $t (New-DVBool -Schema "alex_IsSigned" -En "Signed Copy" -He "עותק חתום" `
    -DescEn "Indicates whether this document is the final signed version." `
    -DescHe "מציין האם מסמך זה הוא הגרסה החתומה הסופית.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_RetrievedOn" -En "Retrieved On" -He "הובא בתאריך" `
    -DescEn "Date and time this document was retrieved from EasyDoc and stored in Dynamics." `
    -DescHe "התאריך והשעה שבהם מסמך זה הובא מ-EasyDoc ונשמר ב-Dynamics.")

# ========================= 6) Integration Log (elastic) =========================
$t = "alex_integrationlog"
Write-Output "== $t =="
Add-DVColumn $t (New-DVString -Schema "alex_SignatureRequestRef" -En "Signature Request Reference" -He "הפניה לבקשת חתימה" -MaxLength 100 `
    -DescEn "Identifier of the related signature request. Stored as a reference because this high-volume log is an elastic table. Support field." `
    -DescHe "מזהה בקשת החתימה המשויכת. נשמר כהפניה מכיוון שיומן זה בנפח גבוה הוא טבלת Elastic. שדה תמיכה.")
Add-DVColumn $t (New-DVString -Schema "alex_EventType" -En "Event Type" -He "סוג אירוע" -MaxLength 150 `
    -DescEn "Category of the logged event, such as send, status update or document retrieval." `
    -DescHe "קטגוריית האירוע שנרשם, כגון שליחה, עדכון סטטוס או הבאת מסמך.")
Add-DVColumn $t (New-DVString -Schema "alex_OperationName" -En "Operation" -He "פעולה" -MaxLength 200 `
    -DescEn "Name of the specific operation that was performed." `
    -DescHe "שם הפעולה הספציפית שבוצעה.")
Add-DVColumn $t (New-DVString -Schema "alex_CorrelationId" -En "Correlation Id" -He "מזהה מתאם" -MaxLength 100 `
    -DescEn "Identifier used to correlate related events across Dynamics and EasyDoc. Support field." `
    -DescHe "מזהה המשמש לקישור אירועים קשורים בין Dynamics ל-EasyDoc. שדה תמיכה.")
Add-DVColumn $t (New-DVString -Schema "alex_ExternalReference" -En "EasyDoc Reference" -He "הפניית EasyDoc" -MaxLength 150 `
    -DescEn "Reference identifier returned by EasyDoc for the operation. Support field." `
    -DescHe "מזהה הפניה שהוחזר על ידי EasyDoc עבור הפעולה. שדה תמיכה.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_StartedOn" -En "Started On" -He "התחיל בתאריך" `
    -DescEn "Date and time the operation started." `
    -DescHe "התאריך והשעה שבהם הפעולה החלה.")
Add-DVColumn $t (New-DVDateTime -Schema "alex_CompletedOn" -En "Completed On" -He "הושלם בתאריך" `
    -DescEn "Date and time the operation finished." `
    -DescHe "התאריך והשעה שבהם הפעולה הסתיימה.")
Add-DVColumn $t (New-DVInt -Schema "alex_DurationMs" -En "Duration (ms)" -He "משך (מ""ש)" -Min 0 -Max 2147483647 `
    -DescEn "How long the operation took, in milliseconds. Support field for performance review." `
    -DescHe "משך הפעולה, באלפיות שנייה. שדה תמיכה לבדיקת ביצועים.")
Add-DVColumn $t (New-DVString -Schema "alex_ErrorCode" -En "Error Code" -He "קוד שגיאה" -MaxLength 100 `
    -DescEn "Technical error code if the operation failed. Support field." `
    -DescHe "קוד שגיאה טכני אם הפעולה נכשלה. שדה תמיכה.")
Add-DVColumn $t (New-DVMemo -Schema "alex_ErrorMessage" -En "Error Details" -He "פרטי שגיאה" -MaxLength 4000 `
    -DescEn "Readable description of the error to help support diagnose the problem." `
    -DescHe "תיאור קריא של השגיאה לסיוע לתמיכה באבחון הבעיה.")
Add-DVColumn $t (New-DVMemo -Schema "alex_Summary" -En "Summary" -He "תקציר" -MaxLength 4000 `
    -DescEn "Safe, human-readable summary of the event. Must not contain sensitive data or raw message content." `
    -DescHe "תקציר בטוח וקריא של האירוע. אסור שיכיל מידע רגיש או תוכן הודעה גולמי.")

# Elastic choice columns (Direction, Result) with string fallback if unsupported.
foreach ($pc in @(
    @{ Schema="alex_Direction"; En="Direction"; He="כיוון"; Set="alex_logdirection";
       DescEn="Whether this event is an outbound call to EasyDoc or an inbound update from EasyDoc.";
       DescHe="האם אירוע זה הוא קריאה יוצאת ל-EasyDoc או עדכון נכנס מ-EasyDoc." }
    @{ Schema="alex_Result"; En="Result"; He="תוצאה"; Set="alex_logresult";
       DescEn="Outcome of the operation: success, warning, failure or informational.";
       DescHe="תוצאת הפעולה: הצלחה, אזהרה, כשל או מידע." }
)) {
    try {
        Add-DVColumn $t (New-DVPicklistGlobal -Schema $pc.Schema -En $pc.En -He $pc.He -GlobalOptionSetName $pc.Set -DescEn $pc.DescEn -DescHe $pc.DescHe)
    } catch {
        Write-Output "  picklist $($pc.Schema) not supported on elastic; falling back to string."
        Add-DVColumn $t (New-DVString -Schema $pc.Schema -En $pc.En -He $pc.He -MaxLength 50 -DescEn $pc.DescEn -DescHe $pc.DescHe)
    }
}

Write-Output "All columns processed."
