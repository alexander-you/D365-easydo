# Troubleshooting | פתרון תקלות

מדריך מעשי לאבחון תקלות נפוצות באינטגרציה בין Dynamics 365 ל-easydo.
לפני שינוי נתונים בסביבת ייצור, יש לקבל את אישור הלקוח ולתעד את ערכי הרשומה
המקוריים.

## הבקשה מסומנת "הושלם", אבל אין PDF ב-Timeline

### תסמין

בקשת חתימה נמצאת בסטטוס **הושלם** (`alex_status = 626210006`), אך אחד או יותר
מהפרטים הבאים חסרים:

- `alex_signednoteid` ריק.
- `alex_completedon` ריק.
- אין הערה עם PDF חתום ב-Timeline של הרשומה העסקית הראשית.
- לא נוצרו ערכי Read Back בטבלת `alex_signaturefieldvalue`.

התקלה אומתה בחבילת 2.0.0.9. גם הגדרת ה-Flow הנוכחית במאגר עדיין כוללת את תנאי
הסינון שגורם לה.

### אילו בקשות Read Signature Results בודק?

ה-Flow המתוזמן רץ כל חמש דקות. עבור מסמך יחיד הוא בוחר רק רשומות שעומדות בכל
התנאים הבאים:

| שדה | ערך נדרש |
| --- | --- |
| `alex_status` | נשלח (`626210002`), נמסר (`626210003`), נצפה (`626210004`) או בתהליך (`626210005`) |
| `alex_externalformid` | אינו ריק |
| `alex_realtimesessionactive` | אינו `true` |

תנאי ה-OData בפועל:

```text
(alex_status eq 626210002 or alex_status eq 626210003 or
 alex_status eq 626210004 or alex_status eq 626210005)
and alex_externalformid ne null
and alex_realtimesessionactive ne true
```

עבור מעטפה התנאים זהים, אך נדרש `alex_externalenvelopeid` במקום
`alex_externalformid`.

### למה הרשומה יכולה להיתקע?

לאחר `GetFormStatus`, ה-Flow מעדכן את הרשומה ל**הושלם** כאשר easydo מחזירה
`status = signed` או `has_data = true`. פעולות ה-Read Back, הורדת ה-PDF והצירוף
ל-Timeline מתבצעות רק כאשר `has_data = true`.

לכן התרחיש הבא אפשרי:

1. easydo מחזירה `status = signed`, אך `has_data = false`.
2. הרשומה מתעדכנת לסטטוס הושלם.
3. פעולות ה-Read Back והורדת ה-PDF אינן מתבצעות באותה ריצה.
4. בריצה הבאה הרשומה כבר אינה נבחרת, מפני שסטטוס הושלם (`626210006`) אינו כלול
   בשאילתה.

אותו מצב יכול להיווצר אם הריצה נכשלה לאחר עדכון הסטטוס ולפני צירוף ה-PDF.

### מה המשמעות של alex_signednoteid?

לאחר הורדת ה-PDF מ-easydo, הפעולה `alex_AttachSignedPdf` יוצרת הערה עם הקובץ
ב-Timeline של הרשומה העסקית הראשית. רק לאחר יצירת ההערה בהצלחה, המזהה שלה נשמר
בשדה `alex_signednoteid` של בקשת החתימה.

- שדה מלא: קיימת הפניה להערת ה-Timeline שנוצרה עבור ה-PDF החתום.
- שדה ריק: אין הוכחה שה-PDF צורף בהצלחה.

### מה לבקש מלקוח כאשר אין גישה לסביבה?

יש לבקש את המידע הבא, ללא תוכן ה-PDF וללא ערכי Base64:

1. Run History של `Check Signature Status` ושל `Read Signature Results` סביב מועד
   התקלה.
2. Inputs/Outputs של `Get_the_form`, ובמיוחד `status` ו-`has_data`.
3. תוצאת התנאי `Check_if_the_recipient_submitted` והסטטוס של פעולות
   `Download_the_signed_PDF` ו-`Attach_the_signed_PDF_to_the_Timeline`.
4. Audit History המציג מי עדכן את `alex_status` ל-`626210006` ובאיזו שעה.
5. הערכים הנוכחיים של `alex_externalformid`, `alex_realtimesessionactive`,
   `alex_completedon`, `alex_signednoteid`, `alex_laststatuscheckon`,
   `alex_errorcode` ו-`alex_errormessage`.

### בדיקת אימות מבוקרת

יש להעדיף סביבת בדיקות. בסביבת ייצור יש לבצע את הבדיקה רק באישור הלקוח ולאחר
תיעוד הערכים המקוריים.

1. ודא ש-`alex_externalformid` מלא וש-`alex_realtimesessionactive` אינו `true`.
2. תעד את הסטטוס, `alex_completedon`, `alex_signednoteid` ומספר רשומות ה-Read Back
   הקיימות עבור הבקשה.
3. שנה זמנית את `alex_status` ל**נצפה** (`626210004`). ערך זה משמש רק כדי להכניס
   את הרשומה לשאילתת ה-Flow; easydo נשארת מקור האמת למצב החתימה.
4. המתן לריצה הבאה של `Read Signature Results` ובדוק את ה-Run History.

| תוצאה | משמעות אפשרית |
| --- | --- |
| נוצר PDF, `alex_signednoteid` התמלא ו-`alex_completedon` עודכן | easydo מחזירה כעת `has_data = true`, והעיבוד החוזר הצליח |
| הסטטוס חזר להושלם אך אין PDF | easydo עדיין החזירה `has_data = false`, או שהריצה דילגה על ענף ה-Read Back |
| הריצה ניסתה להוריד או לצרף ונכשלה | יש לבדוק את הודעת השגיאה בפעולה שנכשלה |
| הרשומה לא הופיעה בפלט השאילתה | אחד מתנאי הבחירה אינו מתקיים |

הבדיקה אינה שולחת עותק ללקוח. היא קוראת את המצב מ-easydo, מורידה את ה-PDF
ומצרפת אותו ל-Dataverse.

### סיכונים בבדיקה ידנית

- `alex_completedon` עלול להתעדכן לזמן הבדיקה במקום למועד ההשלמה המקורי.
- ערכי Read Back נוצרים כרשומות חדשות ולא כ-Upsert. אם חלקם נוצרו בריצה קודמת,
  ניסיון חוזר עלול ליצור כפילויות.
- שינוי הסטטוס והתיקון יופיעו ב-Audit History.
- הצלחת הבדיקה תיצור הערת Timeline עם PDF, שהיא מטרת ההתאוששות.

### תיקון קבוע מוצע

יש לכלול בשאילתת `Read Signature Results` גם בקשות בסטטוס הושלם, ורק כאשר עדיין
אין להן הפניה ל-PDF חתום:

```text
(alex_status eq 626210002 or alex_status eq 626210003 or
 alex_status eq 626210004 or alex_status eq 626210005 or
 alex_status eq 626210006)
and alex_signednoteid eq null
and alex_externalformid ne null
and alex_realtimesessionactive ne true
```

יש להחיל עיקרון זה גם על מסלול המעטפות. בנוסף, לפני עיבוד חוזר יש להביא בחשבון
ערכי Read Back שנוצרו בריצה חלקית, כדי שלא ליצור רשומות כפולות.

> התיקון המתואר בסעיף זה הוא המלצה ואינו מיושם עדיין ב-Flow שבמאגר.