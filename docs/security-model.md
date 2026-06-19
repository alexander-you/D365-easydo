# Security Model | מודל אבטחה

> מסמך זה מסביר **כיצד הפתרון מאובטח** — לקורא שרוצה להבין את עקרונות האבטחה,
> היכן נשמרים הסודות, מי רשאי לגשת למסמכים חתומים, וכיצד הפעילות מתועדת.

This document explains **how the solution protects data and access**. It is aimed at
anyone who wants to understand the security posture of the integration — where
secrets live, who can see signed documents, and how activity is recorded.

## 1. Where credentials live | היכן נשמרים הסודות

The easydo API token is the only secret the integration needs, and it never appears
in source control, flow definitions, or this repository.

| Aspect | How it is protected |
| --- | --- |
| Storage | The token is stored inside a Power Platform **Connection** (and the base URL inside an **Environment Variable**), both encrypted by the platform. |
| Access in flows | Flows reference the **Connection Reference** — they never read the raw token value. |
| Source control | [.gitignore](../.gitignore) blocks tokens, secrets, signed PDFs and full payloads from ever being committed. |
| Rotation | Replacing the token means updating the Connection only — no flow or code changes. Tokens are rotated before production use. |

> הטוקן של easydo הוא הסוד היחיד שהאינטגרציה צריכה. הוא נשמר אך ורק בתוך
> **Connection** מוצפן של Power Platform, וכתובת ה-API נשמרת ב-**Environment Variable**.
> ה-flows מפנים ל-Connection Reference ולעולם אינם קוראים את ערך הטוקן עצמו.

## 2. How data moves | כיצד הנתונים נעים

- **Outbound only (MVP).** Power Automate calls the easydo API; nothing calls back
  into Dynamics in the MVP, so there is no inbound endpoint to attack.
- **Encrypted in transit.** Every request to easydo uses HTTPS/TLS.
- **The connector has no compute of its own** — it is a declarative API definition,
  so there is no server-side code to exploit.

> כל התקשורת יוצאת בלבד (outbound) ומוצפנת ב-TLS. הקונקטור הוא הגדרה הצהרתית בלבד,
> ללא קוד שרת משלו.

## 3. Who can see signed documents | מי רשאי לגשת למסמכים

Access to a signed document follows the user's access to the **source record** in
Dynamics 365: a user who cannot see a Contact cannot open that Contact's signed
document. On top of standard record security, the solution defines dedicated
**security roles** so each persona gets only what it needs:

| Role | Typical permission |
| --- | --- |
| Signature User | Create and send signature requests for records they own. |
| Signature Manager | Manage requests across the team. |
| Signature Admin | Configure templates, field mappings and connections. |
| Signature Auditor | Read-only access to requests, status and audit history. |
| Signature Support | Limited troubleshooting access. |

> הגישה למסמך חתום נגזרת מהרשאת המשתמש ל**רשומת המקור** ב-Dynamics 365: מי שאינו
> רשאי לראות איש קשר, לא יוכל לפתוח את המסמך החתום שלו. בנוסף מוגדרים תפקידי אבטחה
> ייעודיים לכל סוג משתמש.

## 4. What is recorded | מה מתועד

- The **Integration Log** table records a **safe summary** of each operation —
  never full sensitive payloads or document content.
- The audit trail captures who created a request, when it was sent, to whom, which
  template and fields were used, status changes, and document return.
- **Secure Inputs / Secure Outputs** are enabled on sensitive Power Automate actions
  so that tokens and payloads do not appear in run history.

> טבלת ה-Integration Log שומרת **תקציר בטוח** של כל פעולה — לעולם לא תוכן רגיש מלא.
> מתועד מי יצר בקשה, מתי נשלחה, למי, באיזו תבנית, ושינויי סטטוס. באקשנים רגישים
> מופעל Secure Inputs/Outputs כדי שטוקנים ונתונים לא יופיעו בהיסטוריית ההרצה.

## 5. Platform governance | ממשל פלטפורמה

- **DLP policies** classify the custom connector so it cannot be combined with
  disallowed connectors.
- **Connection References** use least-privilege ownership, ideally a dedicated
  service account, with separate Dev / Test / Prod environments.
- **Azure Key Vault** is introduced only if an Azure Function is added in a later
  phase; it is not required for the MVP.

> מדיניות DLP מסווגת את הקונקטור כך שלא ניתן לשלבו עם קונקטורים אסורים. החיבורים
> מבוססים על הרשאות מינימליות ובעלות יציבה (רצוי חשבון שירות ייעודי), עם הפרדה בין
> סביבות Dev/Test/Prod.
