# Deployment Guide | מדריך פריסה

> מדריך פריסה. ה‑Solution נבנה כ‑Unmanaged בסביבת הפיתוח ומיוצא כ‑Managed לפריסה
> לסביבות Test ו‑Production. הפריסה משתמשת ב‑Environment Variables וב‑Connection
> References, ומומלץ לבצע אותה באמצעות PAC CLI.

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

### Cutting a release | הוצאת גרסה

Both the managed **and** unmanaged packages are produced by
[40-export-release.ps1](../src/scripts/40-export-release.ps1):

```powershell
pwsh -NoProfile -File src/scripts/40-export-release.ps1 -Version <x.y.z.0>
```

It bumps the live solution version, publishes, and writes both zips into
`deployment/releases/<version>/`. **The export is only half the job** — a folder with no
index row and no tag is invisible to anyone browsing the repo. Always also:

1. Add a row to the [releases Versions table](../deployment/releases/README.md#versions).
2. Add a `## [<version>]` entry to [release-notes.md](release-notes.md).
3. Commit and create the git tag `v<version>` (and push it).

> **עברית:** הוצאת גרסה כוללת **חבילת Managed וחבילת Unmanaged** באמצעות
> `40-export-release.ps1`, וכן **שורה בטבלת הגרסאות**, **רשומה ביומן הגרסאות** ותג Git
> `v<version>` שנדחף למאגר. ללא שלושת הפריטים האלה, הגרסה קיימת בתיקייה אך אינה מופיעה
> באינדקס הגרסאות.

> **PCF components.** The three code components (Template Field Mapping, Template Gallery,
> Envelope Composition) plus the Documents grid are part of the exported solution. During
> development they are pushed with `pac pcf push --publisher-prefix alex`; the released
> zip already contains them, so no separate push is needed on the target.

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

### התאמות בזמן ריצה ותלויות ב‑Solution מנוהל

מנהל מערכת יכול לאפשר שליחת מסמכים מכל טבלה עסקית דרך מסך **ניהול טבלאות שליחה**
במרכז הניהול. בעת הפעלת טבלה, ה‑Custom API `alex_EnsureSignatureLookup` יוצר קשר ייעודי
בין הטבלה לבין `alex_signaturerequest`. הקשר מאפשר לשייך כל בקשת חתימה לרשומת המקור
ולהציג את בקשות החתימה הקשורות אליה.

**מיקום הקשר ב‑Solution תלוי בסוג הסביבה:**

- בסביבת **Dev**, ה‑Solution הראשי `alex_d365_easydo` הוא Unmanaged. הקשר נוסף אליו
  ישירות ולכן נכלל בייצוא הבא של ה‑Solution.
- בסביבת **Test, Production או סביבת לקוח**, ה‑Solution הראשי מותקן בדרך כלל כ‑Managed
  ואי אפשר להוסיף אליו רכיבי Metadata חדשים. במקרה כזה המערכת יוצרת או משתמשת
  ב‑Solution לא‑מנוהל ייעודי בשם `alex_d365_easydo_runtime`, ומציגה למנהל המערכת אזהרה.
- כדי להעביר את ההתאמה לסביבה אחרת, יש לייצא גם את `alex_d365_easydo_runtime`. הדרך
  המומלצת היא להפעיל את הטבלה כבר בסביבת Dev, כדי שהקשר ייכלל בייצוא ה‑Managed של
  ה‑Solution הראשי.

**הפעלת טבלה עשויה ליצור תלות ב‑Solution אחר.** לדוגמה, הפעלת `account` או
`salesorder` יוצרת תלות ב‑Sales, והפעלת `incident` או `entitlement` יוצרת תלות
ב‑Service. ה‑Solution הנדרש חייב להיות מותקן בסביבת היעד; אחרת ייבוא הפתרון ייכשל.
לכן יש להפעיל רק טבלאות שקיים עבורן רישוי מתאים, ושרכיבי המוצר שלהן מותקנים בסביבות
הלקוח.

## Add the Documents PCF to a business form | הוספת פקד המסמכים לטופס עסקי

The **Documents grid** PCF is included in the released Solution, but importing the
Solution does not place it automatically on forms that belong to the customer. The
control displays the signature requests related to the current business record, with
status filters, sent and completion dates, envelope progress, navigation to the request,
and an on-demand **Check status** action. See the
[Documents PCF source](../src/pcf-documents/) and its feature summary in the
[release notes](release-notes.md#added--template-gallery--documents-experience--גלריית-תבניות-ומסך-מסמכים).

### Recommended: add it from the easydo Admin Center

1. Open **Send tables management** and enable the required business table. Wait until
  the relationship status shows that the Lookup was created successfully.
2. Select **Add to form** next to the enabled table.
3. Choose each Main Form on which the documents should appear.
4. The Admin Center adds an **easydo Documents** tab containing a related-record subgrid
  and binds `alex_EasyDo.EasyDoDocumentsGrid` to it. The form is then published.

Repeat the operation for every Main Form used by the relevant model-driven apps. Adding
the control to one form does not add it to the table's other forms.

### Manual installation in the form designer

Use this path when the form is managed separately, when the customer does not permit
automatic form changes, or when the control must be placed in an existing tab:

1. Confirm that the relationship `alex_<table>_signaturerequest` exists. If it does not,
  enable the table first in **Send tables management**.
2. Open the table's Main Form in the Power Apps form designer and add a subgrid in the
  required tab or section.
3. Configure the subgrid to show **related records only** from the
  `alex_signaturerequest` table through the `alex_<table>_signaturerequest`
  relationship. Use a view that includes `alex_name`, `alex_status`, `alex_templateid`,
  `alex_senton`, `alex_laststatuscheckon` and `alex_completedon`.
4. Add the code component `alex_EasyDo.EasyDoDocumentsGrid` to the subgrid's dataset,
  bind its `records` dataset to the subgrid and leave `language` as `auto` unless a
  fixed language is required. Enable the component for Web, Tablet and Phone.
5. Save and publish the form, then verify it from an existing business record that has
  at least one related signature request.

### הוספה מומלצת דרך מרכז הניהול של easydo

פקד ה‑PCF **מסמכי easydo** כלול ב‑Solution המופץ, אך ייבוא ה‑Solution אינו מוסיף אותו
אוטומטית לטפסים השייכים ללקוח. הפקד מציג את בקשות החתימה המקושרות לרשומה העסקית
הנוכחית, כולל סינון לפי סטטוס, תאריכי שליחה והשלמה, התקדמות חתימה במעטפה, מעבר לבקשת
החתימה ובדיקת סטטוס לפי דרישה. מידע נוסף נמצא ב[קוד המקור של הפקד](../src/pcf-documents/)
וב[תקציר היכולת ביומן הגרסאות](release-notes.md#added--template-gallery--documents-experience--גלריית-תבניות-ומסך-מסמכים).

1. פתחו את **ניהול טבלאות שליחה** והפעילו את הטבלה העסקית הרצויה. המתינו עד שסטטוס
  הקשר יציין שה‑Lookup נוצר בהצלחה.
2. לחצו על **הוסף לטופס** לצד הטבלה הפעילה.
3. בחרו כל Main Form שבו יש להציג את המסמכים.
4. מרכז הניהול מוסיף לטופס לשונית **מסמכי easydo**, ובה Subgrid של הרשומות המקושרות
  ופקד `alex_EasyDo.EasyDoDocumentsGrid`. בסיום הטופס מתפרסם אוטומטית.

יש לחזור על הפעולה עבור כל Main Form שמשמש את היישומים הרלוונטיים. הוספת הפקד לטופס
אחד אינה מוסיפה אותו אוטומטית לטפסים האחרים של אותה טבלה.

### הוספה ידנית באמצעות מעצב הטפסים

מסלול זה מתאים כאשר הטופס מנוהל בנפרד, כאשר הלקוח אינו מאפשר שינוי אוטומטי של הטופס,
או כאשר רוצים למקם את הפקד בלשונית קיימת:

1. ודאו שהקשר `alex_<table>_signaturerequest` קיים. אם הקשר אינו קיים, הפעילו תחילה את
  הטבלה במסך **ניהול טבלאות שליחה**.
2. פתחו את ה‑Main Form של הטבלה במעצב הטפסים של Power Apps והוסיפו Subgrid בלשונית או
  במקטע הרצויים.
3. הגדירו את ה‑Subgrid להצגת **רשומות קשורות בלבד** מטבלת `alex_signaturerequest`, דרך
  הקשר `alex_<table>_signaturerequest`. בחרו View הכולל את העמודות `alex_name`,
  `alex_status`, `alex_templateid`, `alex_senton`, `alex_laststatuscheckon`
  ו‑`alex_completedon`.
4. הוסיפו ל‑dataset של ה‑Subgrid את רכיב הקוד `alex_EasyDo.EasyDoDocumentsGrid`, קשרו
  את ה‑dataset בשם `records` ל‑Subgrid והשאירו את `language` בערך `auto`, אלא אם נדרשת
  שפה קבועה. הפעילו את הרכיב עבור Web, Tablet ו‑Phone.
5. שמרו ופרסמו את הטופס. לאחר מכן פתחו רשומה עסקית שיש לה לפחות בקשת חתימה מקושרת
  וודאו שהפקד מציג אותה.

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
