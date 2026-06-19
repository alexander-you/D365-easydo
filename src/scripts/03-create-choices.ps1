<#
  Creates the Global Choices (option sets) used across the D365 easydo data model.
  All choices use the alex_ prefix and are added to the alex_d365_easydo solution.
  Every choice and every option carries an English + Hebrew label and description.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# 1) Signature request lifecycle status
New-DVGlobalChoice -Name "alex_signaturestatus" `
    -En "Signature Status" -He "סטטוס חתימה" `
    -DescEn "Lifecycle stage of a signature request as it moves from creation through delivery, signing and completion." `
    -DescHe "שלב במחזור החיים של בקשת חתימה מרגע היצירה ועד למשלוח, חתימה והשלמה." `
    -Options @(
        @{ En="Draft";          He="טיוטה";        DescEn="The request has been created in Dynamics but not yet sent to easydo."; DescHe="הבקשה נוצרה ב-Dynamics אך טרם נשלחה ל-easydo." }
        @{ En="Ready to Send";   He="מוכן למשלוח";  DescEn="The request and its recipients are validated and ready to be sent for signature."; DescHe="הבקשה והנמענים אומתו ומוכנים לשליחה לחתימה." }
        @{ En="Sent";            He="נשלח";          DescEn="The request was successfully sent to the recipient through easydo."; DescHe="הבקשה נשלחה בהצלחה לנמען דרך easydo." }
        @{ En="Delivered";       He="נמסר";          DescEn="easydo confirmed the signature request reached the recipient."; DescHe="easydo אישר שבקשת החתימה הגיעה לנמען." }
        @{ En="Viewed";          He="נצפה";          DescEn="The recipient opened and viewed the document."; DescHe="הנמען פתח וצפה במסמך." }
        @{ En="In Progress";     He="בתהליך";        DescEn="One or more recipients are in the process of signing."; DescHe="נמען אחד או יותר נמצאים בתהליך חתימה." }
        @{ En="Completed";       He="הושלם";         DescEn="All required recipients have signed and the process finished successfully."; DescHe="כל הנמענים הנדרשים חתמו והתהליך הושלם בהצלחה." }
        @{ En="Declined";        He="נדחה";          DescEn="A recipient declined to sign the document."; DescHe="נמען סירב לחתום על המסמך." }
        @{ En="Failed";          He="נכשל";          DescEn="The request failed due to a delivery or processing error."; DescHe="הבקשה נכשלה עקב שגיאת משלוח או עיבוד." }
        @{ En="Cancelled";       He="בוטל";          DescEn="The request was cancelled before completion."; DescHe="הבקשה בוטלה לפני השלמתה." }
        @{ En="Expired";         He="פג תוקף";       DescEn="The request expired before all recipients signed."; DescHe="תוקף הבקשה פג לפני שכל הנמענים חתמו." }
        @{ En="Pending Retry";   He="ממתין לניסיון חוזר"; DescEn="A transient error occurred and the operation is queued to be retried."; DescHe="אירעה שגיאה זמנית והפעולה ממתינה לניסיון חוזר." }
    )

# 2) Recipient signing status (mirrors easydo assignee states)
New-DVGlobalChoice -Name "alex_recipientstatus" `
    -En "Recipient Status" -He "סטטוס נמען" `
    -DescEn "Signing progress of an individual recipient on a signature request." `
    -DescHe "התקדמות החתימה של נמען בודד בבקשת חתימה." `
    -Options @(
        @{ En="Waiting";     He="ממתין";   DescEn="The recipient has not yet started signing."; DescHe="הנמען טרם החל בחתימה." }
        @{ En="In Progress"; He="בתהליך";  DescEn="The recipient has opened the document and started signing."; DescHe="הנמען פתח את המסמך והחל בחתימה." }
        @{ En="Viewed";      He="נצפה";    DescEn="The recipient viewed the document but has not signed."; DescHe="הנמען צפה במסמך אך טרם חתם." }
        @{ En="Signed";      He="חתם";     DescEn="The recipient completed their signature."; DescHe="הנמען השלים את חתימתו." }
        @{ En="Declined";    He="סירב";    DescEn="The recipient declined to sign."; DescHe="הנמען סירב לחתום." }
    )

# 3) Recipient type
New-DVGlobalChoice -Name "alex_recipienttype" `
    -En "Recipient Type" -He "סוג נמען" `
    -DescEn "Whether the recipient is a Dynamics contact or an ad-hoc external person entered manually." `
    -DescHe "האם הנמען הוא איש קשר ב-Dynamics או אדם חיצוני שהוזן ידנית." `
    -Options @(
        @{ En="Contact";          He="איש קשר";   DescEn="The recipient is linked to an existing Dynamics 365 contact record."; DescHe="הנמען מקושר לרשומת איש קשר קיימת ב-Dynamics 365." }
        @{ En="External Person";  He="אדם חיצוני"; DescEn="The recipient is an ad-hoc person whose details were entered manually."; DescHe="הנמען הוא אדם חיצוני שפרטיו הוזנו ידנית." }
    )

# 4) Document type
New-DVGlobalChoice -Name "alex_documenttype" `
    -En "Document Type" -He "סוג מסמך" `
    -DescEn "The role of a stored document within the signature process." `
    -DescHe "תפקיד המסמך השמור בתהליך החתימה." `
    -Options @(
        @{ En="Original";  He="מקור";      DescEn="The original document prepared for signature."; DescHe="המסמך המקורי שהוכן לחתימה." }
        @{ En="Preview";   He="תצוגה מקדימה"; DescEn="A draft preview generated before the request is sent."; DescHe="תצוגה מקדימה של טיוטה שנוצרה לפני שליחת הבקשה." }
        @{ En="Signed";    He="חתום";      DescEn="The final signed document returned after completion."; DescHe="המסמך החתום הסופי שהוחזר לאחר ההשלמה." }
        @{ En="Evidence";  He="ראיה";      DescEn="A signing audit/evidence file documenting the signature event."; DescHe="קובץ ראיה/ביקורת המתעד את אירוע החתימה." }
    )

# 5) Delivery method
New-DVGlobalChoice -Name "alex_deliverymethod" `
    -En "Delivery Method" -He "אמצעי משלוח" `
    -DescEn "The channel used to deliver the signature request to the recipient." `
    -DescHe "הערוץ שדרכו נשלחת בקשת החתימה לנמען." `
    -Options @(
        @{ En="Email";       He="דוא""ל";       DescEn="The request is delivered by email."; DescHe="הבקשה נשלחת בדוא""ל." }
        @{ En="SMS";         He="מסרון";        DescEn="The request is delivered by SMS text message."; DescHe="הבקשה נשלחת במסרון." }
        @{ En="Public Link"; He="קישור ציבורי"; DescEn="The request is shared through a public signing link."; DescHe="הבקשה משותפת באמצעות קישור חתימה ציבורי." }
    )

# 6) Document language
New-DVGlobalChoice -Name "alex_language" `
    -En "Language" -He "שפה" `
    -DescEn "The language used for the signature request and recipient communication." `
    -DescHe "השפה המשמשת לבקשת החתימה ולתקשורת עם הנמען." `
    -Options @(
        @{ En="Hebrew";  He="עברית";   DescEn="Hebrew language and right-to-left presentation."; DescHe="שפה עברית ותצוגה מימין לשמאל." }
        @{ En="English"; He="אנגלית";  DescEn="English language and left-to-right presentation."; DescHe="שפה אנגלית ותצוגה משמאל לימין." }
    )

# 7) Integration log direction
New-DVGlobalChoice -Name "alex_logdirection" `
    -En "Direction" -He "כיוון" `
    -DescEn "Whether an integration event represents an outbound call to easydo or an inbound update from easydo." `
    -DescHe "האם אירוע האינטגרציה מייצג קריאה יוצאת ל-easydo או עדכון נכנס מ-easydo." `
    -Options @(
        @{ En="Outbound"; He="יוצא"; DescEn="A request sent from Dynamics to easydo."; DescHe="בקשה שנשלחה מ-Dynamics ל-easydo." }
        @{ En="Inbound";  He="נכנס"; DescEn="A status update or callback received from easydo."; DescHe="עדכון סטטוס או קריאה חוזרת שהתקבלו מ-easydo." }
    )

# 8) Integration log result
New-DVGlobalChoice -Name "alex_logresult" `
    -En "Result" -He "תוצאה" `
    -DescEn "The outcome of an integration operation recorded in the log." `
    -DescHe "תוצאת פעולת האינטגרציה שנרשמה ביומן." `
    -Options @(
        @{ En="Success";  He="הצלחה";   DescEn="The operation completed successfully."; DescHe="הפעולה הושלמה בהצלחה." }
        @{ En="Warning";  He="אזהרה";   DescEn="The operation completed with a non-blocking warning."; DescHe="הפעולה הושלמה עם אזהרה שאינה חוסמת." }
        @{ En="Failure";  He="כשל";     DescEn="The operation failed and may require attention or retry."; DescHe="הפעולה נכשלה ועשויה לדרוש טיפול או ניסיון חוזר." }
        @{ En="Info";     He="מידע";    DescEn="An informational event with no error condition."; DescHe="אירוע מידע ללא מצב שגיאה." }
    )

Write-Output "All global choices processed."
