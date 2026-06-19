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

## Prerequisites | דרישות מקדימות

Before deploying or running the solution, make sure the following are in place.

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
