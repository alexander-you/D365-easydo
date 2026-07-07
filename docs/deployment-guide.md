# Deployment Guide | מדריך פריסה

> מדריך פריסה. הפתרון נבנה כ-solution לא מנוהל (unmanaged) בסביבת
> הפיתוח, ומיוצא כ-solution מנוהל (managed) לפריסה ל-Test/Production. הפריסה משתמשת
> ב-Environment Variables ו-Connection References, ומומלץ לבצעה דרך PAC CLI.

## Environments

| Stage | Environment |
| --- | --- |
| Development | Dev environment (details kept outside the repo) |
| Test | TBD |
| Production | TBD |

## Solution

| Item | Value |
| --- | --- |
| Display name | `D365 easydo` |
| Logical name | `alex_d365_easydo` |
| Publisher prefix | `alex` |

## Lifecycle

1. Develop in the **unmanaged** solution in the Dev environment.
2. Export as **managed** for Test / Production.
3. Bind Environment Variables and Connection References per target environment.
4. Import in the correct order (see [import-order.md](../deployment/import-order.md)).

## Runtime customizations & managed dependencies

Admins can enable additional **send tables** at runtime from the admin center
(`adminCenter.html`). Each enablement provisions a relationship
`alex_<table>_signaturerequest` via the `alex_EnsureSignatureLookup` Custom API. This
has two ALM consequences to plan for:

- **Where the new relationship lives.** New metadata can only be written to an
  **unmanaged** solution. In **Dev** the base `alex_d365_easydo` is unmanaged, so the
  relationship is added straight to it and travels with the next export. On a
  **Test/Prod/customer** environment the base arrives **managed**, so the plug-in
  creates/uses a dedicated unmanaged solution **`alex_d365_easydo_runtime`**
  ("D365 easydo - Runtime Customizations") and returns a warning. To carry such a
  customization between environments, **export `alex_d365_easydo_runtime`** (managed)
  in addition to the main solution, or — preferably — enable the table in Dev so it
  ships inside the main managed solution.
- **Managed dependencies are created.** Enabling a table owned by a managed
  first-party solution makes the easydo solution **depend** on it:

  | Enabled table(s) | Depends on managed solution |
  | --- | --- |
  | `account`, `salesorder` | **Sales** (`msdynce_Sales`) |
  | `incident`, `entitlement` | **Service** (`msdynce_Service`) |
  | `msevtmgt_event` | **Marketing – Event Management** |

  These dependencies are listed under the solution's **Managed solution
  dependencies**, and **import fails** if the dependency is missing in the target
  environment. Only enable tables the customer actually has licensed/installed.

> **בעברית.** הפעלת טבלת שליחה ממסך הניהול יוצרת קשר חדש דרך ה‑Custom API
> `alex_EnsureSignatureLookup`. בפיתוח הקשר נוסף ישירות ל‑`alex_d365_easydo` (לא‑מנוהל)
> ונוסע בייצוא הבא; אצל לקוח (בסיס מנוהל) הוא נוסף ל‑solution לא‑מנוהל ייעודי
> `alex_d365_easydo_runtime` שיש לייצא בנפרד — או, עדיף, להפעיל את הטבלה כבר בפיתוח כדי
> שתישלח בתוך ה‑managed הראשי. בנוסף, הפעלת טבלה בבעלות solution מנוהל (Sales / Service /
> Marketing) יוצרת **תלות מנוהלת** שחייבת להתקיים בסביבת היעד — אחרת הייבוא ייכשל. יש
> להפעיל רק טבלאות שהלקוח אכן מחזיק.

## Prerequisites | דרישות מקדימות

Before deploying or running the solution, make sure the following are in place.

> For the **full** prerequisites — including the **easydo side** (account, API access,
> where the API key comes from, free trial and contact details) with a diagram — see
> [prerequisites.md](prerequisites.md).
>
> לרשימת הדרישות **המלאה** — כולל **צד easydo** (חשבון, גישת API, מהיכן משיגים
> את המפתח, חשבון ניסיון ופרטי קשר) עם תרשים — ראה [prerequisites.md](prerequisites.md).

### Accounts & licensing | חשבונות ורישוי

- A **Power Platform environment** with Dataverse enabled (Dev, and later Test/Prod).
- A **Power Automate** plan that allows custom connectors and the Dataverse connector.
- A **dedicated service account** to own the connections (recommended for Test/Prod).
- An **easydo account** with API access enabled for the company entity.

### easydo side | בצד easydo

- An **API token** generated in the easydo portal (Company settings → API).
- At least one **template** created on the easydo website, including its fields and
  default recipients (templates are built in easydo, not in Dynamics).

### Tooling | כלים

- **Power Platform CLI (`pac`)** — see [pac-cli.md](../deployment/pac-cli.md).
- **PowerShell 7+** to run the helper scripts in [../src/scripts/](../src/scripts/).
- **Azure CLI (`az`)** for obtaining a Dataverse Web API token during setup.
- **Git** for source control.

### Configuration values | ערכי תצורה

- The **easydo API base URL** and **token**, supplied as an Environment Variable and
  a secure Connection — never committed to source control.
- The target **Dataverse environment URL** (kept outside the repo, e.g. in a local
  `.env.ps1`).

> לפני פריסה או הרצה יש לוודא: סביבת Power Platform עם Dataverse, רישוי Power Automate
> לקונקטור מותאם, חשבון שירות ייעודי לחיבורים, וחשבון easydo עם גישת API. בצד easydo
> נדרשים טוקן API ולפחות תבנית אחת עם שדות ונמענים. כלים: ‎pac CLI‏, ‎PowerShell 7+‏,
> ‎Azure CLI‏ ו-Git. ערכי הסוד (כתובת ה-API והטוקן) נשמרים ב-Environment Variable
> וב-Connection מאובטח בלבד — לעולם לא ב-Git.

> Detailed steps will be expanded as the solution components are built.
