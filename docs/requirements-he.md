# מסמך דרישות עסקיות וטכניות לפתרון חתימה דיגיטלית מתוך Dynamics 365

## 1. מטרת הפתרון

המטרה היא לבנות יכולת חתימה דיגיטלית מלאה, נוחה ודינמית מתוך Dynamics 365, כך שמשתמש עסקי יוכל לשלוח מסמך לחתימה מתוך רשומת CRM קיימת, לעקוב אחר סטטוס החתימה, ולקבל את המסמך החתום בחזרה להקשר העסקי הנכון.

הפתרון צריך לאפשר חוויית עבודה דומה למערכות חתימה מובילות, שבה המשתמש רואה תהליך ברור ומונחה:

1. בחירת תבנית
2. סקירת המסמך
3. בדיקה ומילוי שדות
4. בחירת נמענים
5. שליחה לחתימה
6. מעקב סטטוס
7. החזרת המסמך החתום ל-Dynamics 365

החוויה חייבת להיות פשוטה להפעלה, קלה להקמה, מאובטחת כברירת מחדל, ותומכת בעברית ובאנגלית באופן טבעי.

---

## 2. צורך עסקי

כיום תהליכי חתימה דיגיטלית מתבצעים לעיתים מחוץ ל-Dynamics 365, דבר שיוצר פערים תפעוליים:

* משתמשים נדרשים לעבור למערכת חיצונית.
* פרטי לקוח מוקלדים ידנית.
* אין מעקב מלא אחרי סטטוס החתימה מתוך רשומת הלקוח.
* מסמכים חתומים לא תמיד נשמרים במקום הנכון.
* קשה לדעת מי שלח, למי נשלח, מתי נחתם ומה הסטטוס הנוכחי.
* אין חוויית עבודה אחידה למשתמשים עסקיים.
* קשה לאכוף הרשאות, Audit, Retention ותהליכי בקרה.

הפתרון נדרש להפוך את Dynamics 365 לנקודת ההפעלה והמעקב המרכזית של תהליך החתימה.

---

## 3. עקרונות מנחים

## 3.1 פשטות הפעלה והקמה

הפתרון חייב להיות פשוט לפריסה, הפעלה ותחזוקה.

יש להעדיף יכולות מובנות של Power Platform לפני הוספת רכיבי Azure או קוד מותאם אישית מורכב.

רכיבי MVP מועדפים:

* Dataverse
* Power Automate
* Custom Connector
* Model-driven App
* Command Bar
* Custom Page
* PCF     עשיר 
* SharePoint או Dataverse File לאחסון מסמכים

Azure Function לא צריך להיות תנאי חובה ל-MVP. יש לשקול אותו רק אם קיימת דרישה ממשית ל-callback מאובטח, ניהול token מתקדם, נפחים גבוהים, טיפול בקבצים גדולים או הפרדה חזקה בין Dynamics 365 לבין שירות החתימה.

## 3.2 אבטחה במקום הראשון

הפתרון חייב להיות מתוכנן מתוך תפיסה של Security by Design.

אין לשמור סיסמאות, tokens, client secrets, קבצי PDF רגישים או payloads מלאים בצורה גלויה.

יש להקפיד על:

* שימוש ב-Connection References
* שימוש ב-Environment Variables
* הפרדת הרשאות לפי תפקידים
* הפעלת Secure Inputs ו-Secure Outputs בפעולות רגישות
* מניעת חשיפת מידע רגיש ב-Flow Run History
* הגבלת גישה למסמכים חתומים
* Audit מלא על פעולות עסקיות
* שמירת לוגים טכניים בצורה מצומצמת ובטוחה
* התאמה למדיניות DLP של הארגון

## 3.3 פתרון דינמי ולא קשיח

הפתרון לא צריך להיות מבוסס על hardcoding של תבניות, שדות, נמענים או טבלאות.

מנהל מערכת צריך להיות מסוגל להגדיר:

* אילו טבלאות ב-Dynamics 365 תומכות בשליחה לחתימה
* אילו תבניות זמינות לכל סוג רשומה
* אילו שדות מתוך Dynamics 365 ממופים לשדות במסמך
* מי הנמענים האפשריים
* האם התהליך הוא חותם יחיד או כמה חותמים
* האם החתימה היא סדרתית או מקבילה
* היכן נשמר המסמך החתום
* מהי תדירות סנכרון סטטוס
* אילו משתמשים מורשים לשלוח מסמך לחתימה

## 3.4 חוויית משתמש טבעית מתוך Dynamics 365

המשתמש העסקי לא צריך להכיר מונחים טכניים כגון API, TemplateId, TaskGuid, Payload, JSON או Signature Positions.

החוויה צריכה להיות עסקית וברורה:

* בחר תבנית
* בדוק פרטים
* בחר חותם
* צפה במסמך
* שלח לחתימה
* עקוב אחרי סטטוס
* פתח מסמך חתום

---

## 4. תמיכה דו לשונית בעברית ואנגלית

הפתרון חייב להיבנות מראש כפתרון דו לשוני מלא.

עברית ואנגלית חייבות להיות נתמכות ברמת:

* כפתורים
* טפסים
* הודעות שגיאה
* הודעות הצלחה
* סטטוסים
* שמות שדות
* תיאורי תבניות
* Custom Pages
* PCF Controls
* Flow notifications
* תיעוד
* מסמכים למשתמש
* מסמכי התקנה

עברית חייבת לכלול תמיכת RTL אמיתית, ולא רק תרגום טקסטואלי.

יש לבדוק:

* יישור שדות
* סדר עמודות
* מיקום כפתורים
* Progress bar
* Preview של מסמך בעברית
* שילוב טקסט עברי ואנגלי
* הצגת טלפונים ודוא״ל
* תאריכים ומספרים
* הודעות מערכת
* חוויית משתמש במסכים צרים

הפתרון צריך להשתמש ביכולות תרגום מובנות של Power Platform ככל האפשר, כולל תרגום labels, choices, forms, views, command bar ו-resources.

---

## 5. תרחיש משתמש עיקרי

המשתמש פותח רשומה עסקית ב-Dynamics 365, לדוגמה תיק שירות, לקוח, איש קשר, הזדמנות או הצעת מחיר.

מתוך הרשומה הוא לוחץ על כפתור:

**Send for Signature**

לאחר מכן נפתח מסך מונחה שבו המשתמש:

1. בוחר תבנית רלוונטית.
2. רואה את פרטי המסמך.
3. רואה את השדות הדינמיים שהמערכת זיהתה.
4. רואה אילו נתונים נמשכים אוטומטית מתוך Dynamics 365.
5. יכול לערוך שדות שמוגדרים כניתנים לעריכה.
6. בוחר או מאשר את הנמען.
7. רואה תצוגה מקדימה של המסמך, אם נתמך.
8. שולח את הבקשה לחתימה.
9. חוזר לרשומת המקור ורואה סטטוס חתימה.
10. לאחר השלמת החתימה, רואה קישור או קובץ של המסמך החתום.

---

## 6. דרישות עסקיות

## 6.1 בחירת תבנית

המערכת חייבת לאפשר בחירת תבנית מתוך רשימה דינמית.

התבניות צריכות להיות מסוננות לפי:

* סוג רשומה
* תהליך עסקי
* שפה
* סטטוס פעיל או לא פעיל
* הרשאות משתמש
* סוג חתימה נדרש
* סוג מסמך

לדוגמה:

* תבניות לתיק שירות
* תבניות להצעת מחיר
* תבניות להסכם
* תבניות לטופס הצטרפות
* תבניות לאישור לקוח

## 6.2 מיפוי שדות דינמי

המערכת חייבת לאפשר מיפוי בין שדות המסמך לבין שדות Dynamics 365.

דוגמאות:

* שם לקוח
* שם איש קשר
* דוא״ל
* טלפון
* מספר תיק
* מספר הצעה
* סכום
* תאריך
* כתובת
* מזהה לקוח
* שדות מותאמים אישית

המיפוי צריך להישמר ב-Dataverse ולא בקוד.

## 6.3 מילוי שדות לפני שליחה

המערכת צריכה למלא אוטומטית שדות במסמך לפי נתונים קיימים ב-Dynamics 365.

יש לאפשר:

* שדות חובה
* שדות אופציונליים
* ערכי ברירת מחדל
* שדות ניתנים לעריכה
* שדות לקריאה בלבד
* שדות שמחושבים בזמן אמת
* שדות ידניים שהמשתמש ממלא לפני השליחה

## 6.4 בחירת נמענים

המערכת צריכה לתמוך בנמען יחיד ובתשתית עתידית לכמה נמענים.

עבור כל נמען יש לנהל:

* שם
* דוא״ל
* טלפון
* סוג נמען
* סדר חתימה
* סטטוס חתימה
* תאריך שליחה
* תאריך חתימה
* קשר לרשומת Contact או Account, אם קיים

יש לתמוך גם בנמען שאינו קיים עדיין ב-Dynamics 365.

## 6.5 תצוגה מקדימה של מסמך

הפתרון צריך לתמוך בשלב Review לפני שליחה.

הדרישה העסקית היא שהמשתמש יוכל לראות את המסמך לפני שהוא נשלח לחותם.

יש לבדוק טכנית מול שירות החתימה האם ניתן:

* לקבל PDF של תבנית לפני יצירת בקשת חתימה
* ליצור בקשת טיוטה ללא שליחה
* לקבל PDF לאחר יצירת טיוטה
* לשלוח את אותה טיוטה רק לאחר אישור המשתמש
* למחוק טיוטה אם המשתמש ביטל את הפעולה

אם השירות אינו תומך בתצוגה מקדימה אמיתית לפני שליחה, יש לבנות חלופה:

* הצגת PDF מקור מתוך מאגר פנימי
* ציור שכבת שדות על גבי המסמך
* הצגת Preview סכמטי
* הצגת סיכום שדות ונמענים במקום PDF מלא

אין להחזיק שתי גרסאות של אותו מסמך אם ניתן להימנע מכך. יש להעדיף שימוש בשירות החתימה כמקור האמת למסמך ולתבנית.

## 6.6 שליחה לחתימה

המערכת חייבת לאפשר שליחה לחתימה מתוך Dynamics 365.

לפני השליחה יש לבצע בדיקות:

* קיימת תבנית פעילה
* קיימים נמענים
* קיימים פרטי קשר תקינים
* כל שדות החובה מולאו
* אין בקשת חתימה פעילה כפולה לאותה רשומה ותבנית
* המשתמש מורשה לשלוח
* הרשומה במצב עסקי שמאפשר שליחה

## 6.7 מעקב סטטוס

המערכת חייבת לשמור ולעדכן סטטוס חתימה.

סטטוסים מוצעים:

* Draft
* Ready to Send
* Sent
* Delivered
* Viewed
* In Progress
* Completed
* Failed
* Cancelled
* Expired
* Deleted
* Pending Retry

יש לאפשר רענון סטטוס אוטומטי וגם רענון ידני למשתמש מורשה.

## 6.8 החזרת מסמך חתום ל-Dynamics 365

המסמך החתום חייב לחזור להקשר העסקי ב-Dynamics 365.

המסמך יכול להישמר באחת מהאפשרויות:

* SharePoint
* Dataverse File Column
* Azure Blob Storage בשלב מתקדם
* קישור מאובטח למסמך במערכת החיצונית, אם עומד בדרישות אבטחה ו-retention

ל-MVP, ההמלצה היא SharePoint או Dataverse File Column.

המשתמש צריך לראות מתוך הרשומה:

* סטטוס חתימה
* תאריך השלמה
* שם המסמך
* קישור למסמך החתום
* פרטי החותמים
* היסטוריית אירועים
* הודעת שגיאה אם ההחזרה נכשלה

## 6.9 ביטול, שליחה חוזרת וניסיון חוזר

הפתרון צריך לתמוך בתרחישים הבאים:

* ביטול בקשת חתימה
* שליחה חוזרת לנמען
* רענון סטטוס
* ניסיון חוזר להורדת מסמך חתום
* מחיקת טיוטה
* טיפול בבקשה שנכשלה
* מניעת כפילות

---

## 7. דרישות UX

## 7.1 מבנה חוויית המשתמש

החוויה המומלצת היא מסך מונחה שלבים:

1. Select Template
2. Review Document
3. Fill Fields
4. Select Recipients
5. Send

יש להציג Progress bar ברור בראש המסך.

בכל שלב יש להציג:

* שם השלב
* הסבר קצר
* סטטוס השלמה
* הודעות ולידציה
* כפתורי המשך וחזרה

## 7.2 PCF או Custom Page

ל-MVP ניתן להתחיל עם Custom Page אם החוויה פשוטה.

PCF מתאים אם נדרשת חוויה עשירה יותר, למשל:

* הצגת PDF בתוך הפקד
* ציור שכבות שדות על גבי מסמך
* drag and drop
* הצגת חתימות ומיקומים
* עבודה בתוך טופס רשומה קיים
* אינטראקציה עשירה עם נתוני Dataverse

אפשרות מומלצת:

* MVP: Custom Page
* שלב מתקדם: PCF עבור Preview ו-field overlay

## 7.3 תצוגת מסמך

אם קיימת אפשרות לקבל PDF מהשירות לפני שליחה, יש להציג אותו במסך Review.

אם לא קיימת אפשרות כזו, יש להציג אחת מהחלופות:

* Preview סכמטי
* PDF מקור ממאגר פנימי
* PDF עם שכבת שדות שנבנית בצד הלקוח
* Summary עסקי של השדות והנמענים

המשתמש חייב להבין בבירור מה יישלח לחותם לפני השליחה.

## 7.4 ולידציה ידידותית

המערכת צריכה להציג הודעות ברורות, לא טכניות.

לדוגמה:

* חסר דוא״ל לנמען
* חסר מספר טלפון
* לא נבחרה תבנית
* חסר שדה חובה במסמך
* קיימת כבר בקשת חתימה פעילה
* לא ניתן לשלוח מסמך במצב הרשומה הנוכחי

---

## 8. מבנה נתונים מוצע ב-Dataverse

## 8.1 Signature Request

טבלה מרכזית לניהול בקשת חתימה.

שדות מוצעים:

* Name
* Related Record
* Related Table Name
* Request Type
* Template
* Status
* External Task Id
* External Document Id
* External Group Id
* Sent On
* Completed On
* Cancelled On
* Created By
* Last Status Check On
* Error Code
* Error Message
* Retry Count
* Storage Location
* Signed Document
* Signed Document URL
* Language
* Delivery Method
* Is Draft
* Is Preview Generated

## 8.2 Signature Template

טבלה לניהול תבניות.

שדות מוצעים:

* Template Name
* External Template Id
* Related Dynamics Table
* Template Type
* Language
* Active
* Supports Single Signer
* Supports Multiple Signers
* Supports Preview
* Requires File Upload
* Default Delivery Method
* Description
* Template Version
* Last Synced On

## 8.3 Template Field Mapping

טבלה למיפוי שדות.

שדות מוצעים:

* Template
* External Field Id
* External Field Name
* External Field Type
* Page
* X
* Y
* Width
* Height
* Dynamics Table
* Dynamics Field
* Default Value
* Required
* Editable Before Send
* Visible to User
* Transformation Rule
* Sender Prefill
* Recipient Editable

## 8.4 Signature Recipient

טבלה לניהול חותמים.

שדות מוצעים:

* Signature Request
* Recipient Type
* Contact
* Account
* External Name
* Email
* Phone
* Signing Order
* External Client Id
* Status
* Sent On
* Viewed On
* Signed On
* Delivery Error
* Preferred Language

## 8.5 Signature Document

טבלה לניהול מסמכים.

שדות מוצעים:

* Signature Request
* Document Type
* File Name
* Mime Type
* Storage Type
* Dataverse File
* SharePoint URL
* External File Id
* Retrieved On
* Version
* Is Signed
* Is Original
* Is Evidence File

## 8.6 Integration Log

טבלה לניהול לוגים ואירועים.

שדות מוצעים:

* Signature Request
* Event Type
* Operation Name
* Direction
* Status
* Started On
* Completed On
* Correlation Id
* Error Code
* Error Message
* Safe Payload Summary

אין לשמור payload מלא עם מידע רגיש אלא אם יש דרישה מפורשת ומנגנון הגנה מתאים.

---

## 9. רכיבי Power Platform נדרשים

## 9.1 Dataverse

Dataverse ישמש לניהול:

* תבניות
* מיפויים
* בקשות חתימה
* נמענים
* מסמכים
* סטטוסים
* לוגים
* הרשאות

## 9.2 Custom Connector

יש לבנות Custom Connector ייעודי לשירות החתימה.

אין להשתמש ב-HTTP Action רגיל בתוך Power Automate כפתרון קבוע.

ה-Custom Connector צריך לכלול פעולות עסקיות ברורות:

* Authenticate
* Get Templates
* Get Template Details
* Create Draft Request
* Create Signature Request
* Send Signature Request
* Get Request Status
* Get Document
* Get Signed Document
* Cancel Request
* Delete Draft
* Resend Request

## 9.3 Power Automate

Flows מוצעים:

* Send Signature Request
* Create Draft Signature Request
* Refresh Signature Status
* Retrieve Signed Document
* Sync Templates
* Retry Failed Request
* Cancel Signature Request
* Delete Draft Request
* Notify Owner on Failure

יש להשתמש ב-Solution-aware flows בלבד.

## 9.4 Command Bar

יש להוסיף כפתור מקצועי מתוך הרשומות הרלוונטיות.

שם לדוגמה:

**Send for Signature**

הכפתור צריך להופיע רק כאשר:

* המשתמש מורשה
* הרשומה נשמרה
* קיימת תבנית פעילה
* קיימים נתוני לקוח תקינים
* אין בקשה פעילה כפולה
* סטטוס הרשומה מאפשר שליחה

יש להעדיף Modern Commanding ככל האפשר.

## 9.5 Custom Page

Custom Page תשמש למסך מונחה לשליחה.

היא תכלול:

* בחירת תבנית
* הצגת שדות
* מילוי שדות
* בחירת נמענים
* תצוגה מקדימה
* סיכום
* שליחה

## 9.6 PCF

PCF יישקל כאשר נדרשת חוויית Preview מתקדמת.

שימושים אפשריים:

* הצגת PDF
* ציור שדות על גבי PDF
* הצגת progress stepper
* הצגת מיפוי שדות
* ולידציה בזמן אמת
* תמיכה טובה יותר ב-RTL

## 9.7 Environment Variables

יש להשתמש ב-Environment Variables עבור:

* Base URL
* Sandbox / Production mode
* Default language
* Storage mode
* SharePoint site
* Status polling interval
* Feature flags
* Debug mode
* Callback URL, אם רלוונטי

## 9.8 Connection References

כל החיבורים צריכים להיות מנוהלים דרך Connection References.

יש להגדיר ownership ברור לחיבורים.

המלצה:

* Service Account ייעודי
* הרשאות מינימליות
* בעלות יציבה על flows
* הפרדה בין Dev, Test ו-Prod

---

## 10. אבטחה והרשאות

## 10.1 Security Roles

יש להגדיר Security Roles ייעודיים:

* Signature User
* Signature Manager
* Signature Admin
* Signature Auditor
* Signature Support

## 10.2 הרשאות למסמכים

הגישה למסמכים חתומים חייבת להיות מוגבלת לפי הרשאות Dynamics 365 והרשאות אחסון.

משתמש שאינו מורשה לראות את הרשומה המקורית לא צריך להיות מסוגל לפתוח את המסמך החתום.

## 10.3 Secrets

אין לשמור secrets בטבלאות רגילות.

יש להשתמש במנגנוני platform מתאימים.

אם יוחלט בהמשך על Azure Function, יש לשקול Key Vault.

## 10.4 DLP

יש לבדוק מראש את השפעת DLP Policies על:

* Custom Connector
* Power Automate
* SharePoint
* Dataverse
* חיבורים חיצוניים
* HTTP triggers, אם יהיו

## 10.5 Audit

יש לתעד:

* מי יצר בקשת חתימה
* מתי נשלחה
* לאיזה נמען
* איזו תבנית נבחרה
* אילו שדות מולאו
* מתי הסטטוס השתנה
* מתי המסמך החתום חזר
* מי פתח או הוריד מסמך, ככל שניתן

---

## 11. Preview ודילמת המסמך המקורי

אחת הדרישות החשובות היא להציג למשתמש מסמך אמיתי לפני שליחה.

יש לבדוק מול API של שירות החתימה האם קיימת אחת מהיכולות הבאות:

* קבלת קובץ תבנית לפי Template Id
* קבלת Preview של תבנית
* יצירת טיוטה ללא שליחה
* קבלת PDF מטיוטה
* שליחה מאוחרת של טיוטה
* מחיקת טיוטה אם המשתמש ביטל

אם קיימת תמיכה בטיוטה, זהו המסלול המועדף.

תהליך רצוי:

1. המשתמש בוחר תבנית.
2. המערכת יוצרת טיוטה ללא שליחה.
3. המערכת מקבלת מזהה טיוטה.
4. המערכת מושכת PDF לתצוגה.
5. המשתמש מאשר.
6. המערכת שולחת את אותה טיוטה.
7. אם המשתמש מבטל, הטיוטה נמחקת.

אם אין תמיכה בכך, יש לשקול חלופה שבה נשמר PDF מקור לצורך Preview בלבד.

עם זאת, יש להימנע ככל האפשר מניהול שתי גרסאות של אותו מסמך.

---

## 12. החזרת מסמך חתום

המערכת חייבת לכלול מנגנון להחזרת המסמך החתום ל-Dynamics 365.

האפשרויות:

## 12.1 Polling

Flow מתוזמן בודק סטטוס מול השירות החיצוני.

יתרונות:

* פשוט ל-MVP
* לא דורש endpoint חיצוני
* פחות מורכב אבטחתית

חסרונות:

* לא בזמן אמת
* תלוי בתדירות הרצה
* עלול לצרוך יותר קריאות API

## 12.2 Callback

השירות החיצוני קורא ל-endpoint כאשר יש שינוי סטטוס.

יתרונות:

* קרוב לזמן אמת
* יעיל יותר
* מתאים יותר לייצור מתקדם

חסרונות:

* דורש endpoint מאובטח
* דורש בדיקות אבטחה
* עשוי להצדיק Azure Function או API Management

ל-MVP מומלץ להתחיל ב-Polling, אלא אם קיימת דרישה ברורה לעדכון בזמן אמת.

---

## 13. Azure Function

Azure Function אינה חובה לשלב MVP.

יש לשקול Azure Function כאשר מתקיים אחד או יותר מהתנאים הבאים:

* דרוש callback מאובטח
* יש נפחים גבוהים
* יש צורך ב-token cache
* יש צורך בלוגיקה מורכבת
* יש טיפול בקבצים גדולים
* יש צורך ב-retry מתקדם
* יש צורך ב-idempotency קשיח
* יש צורך בהפרדת secrets מ-Power Automate
* יש צורך ב-Application Insights
* יש צורך ב-API Management

הפתרון צריך להיות מתוכנן כך שניתן יהיה להתחיל עם Power Platform בלבד, ובהמשך להחליף את שכבת האינטגרציה ב-Azure Function מבלי לשנות את חוויית המשתמש ואת מודל הנתונים.

---

## 14. ALM ופריסה

הפתרון חייב להיות Solution-aware.

יש להחזיק לפחות שלוש סביבות:

* Development
* Test
* Production

יש להשתמש ב:

* Managed Solution לפרודקשן
* Unmanaged Solution לפיתוח
* Publisher Prefix ייחודי
* Environment Variables
* Connection References
* Deployment guide
* Release notes
* Rollback plan

יש להימנע משינויים ישירים בסביבת Production.

---

## 15. תיעוד Git

הפתרון חייב להיות מתועד בצורה מלאה ב-Git.

התיעוד צריך לאפשר ללקוח קצה, שותף או צוות פרויקט להתקין, לפרוס, להגדיר ולתחזק את הפתרון ללא תלות מלאה במפתח המקורי.

מבנה מומלץ:

```text
/docs
  business-requirements.md
  technical-architecture.md
  data-model.md
  security-model.md
  deployment-guide.md
  configuration-guide.md
  operations-runbook.md
  troubleshooting.md
  release-notes.md

/src
  power-platform-solution
  custom-connector
  pcf-control
  custom-pages
  scripts

/deployment
  environment-variables.md
  connection-references.md
  pac-cli.md
  import-order.md

/tests
  uat-scenarios.md
  test-matrix.md
```

אין לשמור ב-Git:

* סיסמאות
* tokens
* client secrets
* מסמכים חתומים
* נתוני לקוח
* payloads אמיתיים
* קבצי ייצור רגישים

---

## 16. הערות קוד

הקוד צריך לכלול הערות בסיסיות, מקצועיות וברורות.

אנגלית תהיה השפה הראשית להערות טכניות.

עברית יכולה להופיע כאשר מדובר בהקשר עסקי מקומי, RTL, לוגיקה תפעולית בעברית או מונח עסקי שהלקוח משתמש בו.

דוגמה:

```csharp
// EN: Prevent duplicate active signature requests for the same source record and template.
// HE: מניעת בקשת חתימה פעילה כפולה עבור אותה רשומת מקור ואותה תבנית.
```

אין להעמיס הערות מיותרות. ההערות צריכות להסביר למה נעשית פעולה, לא לתאר פעולה ברורה מאליה.

גם Power Automate flows צריכים להיות מתועדים באמצעות:

* שמות פעולות ברורים
* scopes לוגיים
* תיאורי flow
* שמות משתנים ברורים
* טיפול שגיאות מסודר

---

## 17. כפתורים והתאמות ב-Dynamics 365

הוספת כפתורים ל-Dynamics 365 צריכה להתבצע בזהירות.

יש להימנע מדריסה של התאמות לקוח קיימות.

עקרונות:

* שימוש ב-Modern Commanding
* הוספת כפתור חדש ולא שינוי כפתורים קיימים
* שימוש ב-prefix ייחודי
* visibility rules ברורים
* בדיקת הרשאות
* בדיקת מצב רשומה
* בדיקת קיום תבנית
* בדיקת כפילות
* פריסה דרך solution בלבד

יש להימנע משינויים כבדים בטפסים קיימים.

עדיף להוסיף:

* כפתור Command Bar
* Subgrid של Signature Requests
* Related tab
* Custom Page נפרד

ולא לשנות משמעותית את טופס הלקוח הקיים.

---

## 18. MVP מוצע

## 18.1 כלול ב-MVP

ה-MVP צריך לכלול:

* שליחה מתוך רשומה אחת או שתיים ב-Dynamics 365
* בחירת תבנית
* חותם יחיד
* מיפוי שדות בסיסי
* מילוי שדות מתוך Dataverse
* Custom Page לשליחה
* Custom Connector
* Power Automate
* שמירת בקשת חתימה ב-Dataverse
* סטטוס בסיסי
* Polling לסטטוס
* החזרת מסמך חתום
* אחסון ב-SharePoint או Dataverse
* הרשאות בסיסיות
* תיעוד התקנה
* תמיכה בעברית ואנגלית

## 18.2 לא כלול ב-MVP

לא לכלול בשלב ראשון:

* עורך תבניות מלא בתוך Dynamics 365
* drag and drop של שדות חתימה
* multi-signer מתקדם
* חתימה סדרתית ומקבילה אם אינה קריטית
* Azure Function, אלא אם נדרש
* API Management
* Blob Storage
* callback מתקדם
* PCF מורכב, אלא אם Preview מחייב זאת
* תהליכי Legal Evidence מורכבים
* מערכת ניטור מתקדמת

---

## 19. שלבים מוצעים

## 19.1 שלב ראשון

* מחקר API מלא
* בדיקת authentication
* בדיקת template retrieval
* בדיקת draft mode
* בדיקת preview document
* בדיקת send
* בדיקת status
* בדיקת signed document retrieval

## 19.2 שלב שני

* בניית מודל Dataverse
* בניית Custom Connector
* בניית flows
* בניית Custom Page
* הוספת Command Bar
* בדיקת הרשאות

## 19.3 שלב שלישי

* בניית Preview
* בדיקת Hebrew RTL
* בדיקת English LTR
* בדיקת שדות דינמיים
* בדיקת שגיאות
* בדיקת החזרת מסמך חתום

## 19.4 שלב רביעי

* UAT
* תיעוד
* אריזת solution
* פריסה לסביבת Test
* תיקונים
* פריסה ל-Production

---

## 20. שאלות פתוחות למחקר API

יש לבדוק:

* האם ניתן לקבל רשימת תבניות
* האם ניתן לקבל פרטי תבנית ושדות
* האם ניתן לקבל PDF של תבנית
* האם ניתן ליצור טיוטה ללא שליחה
* האם ניתן לקבל PDF מטיוטה
* האם ניתן לשלוח טיוטה קיימת
* האם ניתן למחוק טיוטה
* האם יש callback
* האם ניתן לבצע polling לסטטוס
* האם ניתן לקבל מסמך חתום
* האם ניתן לקבל evidence file
* האם יש תמיכה בכמה נמענים
* האם יש חתימה סדרתית ומקבילה
* האם יש תמיכה בעברית ו-RTL
* האם יש מגבלות גודל קובץ
* האם יש מגבלות API rate limit
* האם יש sandbox
* האם יש OpenAPI מלא
* האם יש Postman collection
* האם יש סביבת בדיקות
* האם יש מודל תמחור לפי API או מסמך
* האם יש Data Residency רלוונטי
* האם יש דרישות חוקיות או רגולטוריות מיוחדות

---

## 21. קריטריוני הצלחה

הפתרון ייחשב מוצלח כאשר:

* משתמש יכול לשלוח מסמך לחתימה מתוך Dynamics 365 ללא מעבר ידני למערכת חיצונית
* הנתונים נמשכים אוטומטית מהרשומה
* המשתמש רואה סטטוס ברור
* המסמך החתום חוזר לרשומה הנכונה
* התהליך עובד בעברית ובאנגלית
* אין חשיפת secrets או מידע רגיש
* ניתן לפרוס את הפתרון מסביבה לסביבה
* ניתן לתחזק את הפתרון דרך הגדרות ולא דרך קוד
* קיימת תשתית להרחבה עתידית

---

## 22. סיכום

הפתרון צריך לספק שכבת חתימה דיגיטלית עסקית, מאובטחת ודינמית מתוך Dynamics 365, תוך שימוש מירבי ביכולות Power Platform מובנות.

הגישה המומלצת היא להתחיל ב-MVP פשוט:

* Dataverse
* Custom Connector
* Power Automate
* Custom Page
* Command Bar
* Polling
* אחסון מסמך חתום ב-SharePoint או Dataverse

יש להימנע ממורכבות מיותרת בשלב הראשון, אך לתכנן את הארכיטקטורה כך שתוכל לתמוך בעתיד ב-Azure Function, callback, PCF מתקדם, multi-signer ונפחים גבוהים.

"עליך לחקור את API של easydoc ולבנות תוכנית פעולה ברת ביצוע"
