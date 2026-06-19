# Connector Actions Guide | מדריך פעולות הקונקטור

> מדריך זה מסביר **בשפה פשוטה** מה עושה כל אחת מ-15 הפעולות של קונקטור easydo,
> מתי משתמשים בה, מה ממלאים בכל שדה, ומה מקבלים בחזרה. כתוב למי שבונה זרימות
> (flows) ב-Power Automate ולא בהכרח מכיר את ה-API. לכל פעולה יש מקום לצילום מסך.

This guide explains, **in plain language**, what each of the 15 easydo connector
actions does, when to use it, what you type into each field, and what you get back.
It is written for someone building flows in Power Automate — no API knowledge needed.
Screenshots are placeholders for now; replace the images under
[images/](images/) when you capture them.

> **A note about screenshots / על צילומי המסך:** the `![...](images/...)` lines below
> are placeholders. The pictures do not exist yet — add them to the `docs/images/`
> folder later and they will appear automatically.

---

## How signing works in one minute | איך זה עובד בקצרה

You build a **template** once on the easydo website (the document plus the places
people sign). After that, the everyday job is simply: pick a template, list who
should sign, and send. easydo emails each person a private signing link and reports
the status back. Most flows only need three or four of the actions below — the rest
are there for advanced scenarios.

> בונים **תבנית** פעם אחת באתר easydo (המסמך + המקומות לחתימה). לאחר מכן העבודה
> היומיומית פשוטה: בוחרים תבנית, מציינים מי צריך לחתום, ושולחים. easydo שולח לכל
> אדם קישור חתימה אישי במייל ומדווח על הסטטוס. רוב הזרימות צריכות רק שלוש-ארבע מהפעולות.

---

## The 15 actions | 15 הפעולות

The actions fall into four groups:

| # | Group | Actions |
| --- | --- | --- |
| A | Check the connection | Get entity |
| B | Look things up | Get profiles, Get templates, Get template detail, List forms |
| C | Send for signature (the main job) | Send template, Create draft form |
| D | Advanced / manual control | Create form, Set recipients, Upload file, Send form, Get status, Download document, Cancel, Delete |

---

## Group A — Check the connection | קבוצה A — בדיקת חיבור

### 1. Get entity (test connection) | אחזור ישות (בדיקת חיבור)

**Plain meaning:** "Is my easydo connection working?" This asks easydo for the
details of *your own* company account. If it answers, your token and connection are
fine.

**When to use:** Once, when setting things up, or to troubleshoot a broken connection.

**What you fill in:** Nothing.

**What you get back:** Your company's name and ID in easydo.

![Get entity action](images/01-get-entity.png)

> **בעברית:** "האם החיבור ל-easydo תקין?" הפעולה מבקשת את פרטי חשבון החברה שלך.
> אם מתקבלת תשובה — הטוקן והחיבור תקינים. לא ממלאים כלום. משתמשים בה פעם אחת בהקמה
> או לאיתור תקלות.

---

## Group B — Look things up | קבוצה B — חיפוש מידע

### 2. Get profiles / contacts | אחזור פרופילים / אנשי קשר

**Plain meaning:** Get the list of contacts (people) that already exist in your
easydo account, so you can pick a saved recipient instead of typing their email
every time.

**When to use:** When you want to send to someone already saved in easydo.

**What you fill in (all optional):**

| Field | What it really means |
| --- | --- |
| Page size | How many contacts to bring back at once (e.g. `25`). Leave it for the default. |
| Start offset | Where to start in the list — `0` is the beginning. Use it only to fetch the *next* page (e.g. set it to `25` for the second page). |
| Request counter | A technical number easydo echoes back so it can match the response to your request. You can leave it as `1`. |

**What you get back:** A list of contacts, each with a name, email and easydo ID.

![Get profiles action](images/02-get-profiles.png)

> **בעברית:** מחזירה את רשימת אנשי הקשר השמורים ב-easydo, כדי לבחור נמען שמור במקום
> להקליד מייל בכל פעם. כל השדות אופציונליים: "גודל עמוד" = כמה רשומות להביא; "היסט
> התחלה" = מהיכן להתחיל (0 = מההתחלה, 25 = העמוד הבא); "מונה בקשה" = מספר טכני שאפשר
> להשאיר 1.

### 3. Get templates from easydo | אחזור תבניות מ-easydo

**Plain meaning:** Get the list of ready-made templates you built on the easydo
website, so you can choose which document to send.

**When to use:** To let a user pick a template, or to find a template's ID.

**What you fill in:** The same three optional paging fields as above (page size,
start offset, request counter) — usually left as defaults.

**What you get back:** A list of templates, each with its name and **template ID**
(you'll need that ID to send).

![Get templates action](images/03-get-templates.png)

> **בעברית:** מחזירה את רשימת התבניות המוכנות שבנית באתר easydo, כדי לבחור איזה מסמך
> לשלוח. בכל תבנית מופיע השם ו**מזהה התבנית** (תזדקק לו כדי לשלוח). השדות זהים לפעולה
> הקודמת ובדרך כלל נשארים בברירת המחדל.

### 4. Get template detail and fields | אחזור פרטי תבנית ושדות

**Plain meaning:** Open one specific template and see what's inside it — its name,
and the list of fields people will fill in (such as "Full name" or "ID number").

**When to use:** When you need to know which fields a template contains, for example
to map them to Dynamics columns.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Template ID | The ID of the template you want to inspect (from action 3). |

**What you get back:** The template's details and the list of its fields.

![Get template detail action](images/04-get-template.png)

> **בעברית:** פותחת תבנית מסוימת ומציגה מה יש בה — שם והשדות שאנשים ימלאו (כמו "שם
> מלא" או "תעודת זהות"). ממלאים את "מזהה תבנית" (מהפעולה הקודמת). שימושי כשרוצים לדעת
> אילו שדות יש בתבנית.

### 7. List forms | אחזור רשימת טפסים

> *(Listed here with the look-ups; technically action #7 in the connector.)*

**Plain meaning:** Show the signature forms that have already been created or sent —
basically your "sent items" for signatures.

**When to use:** To check history, or to find a form you sent earlier.

**What you fill in:** Optional paging fields (page size, start offset, request
counter).

**What you get back:** A list of forms with their status (waiting, signed, etc.) and
IDs.

![List forms action](images/07-list-forms.png)

> **בעברית:** מציגה את הטפסים שכבר נוצרו או נשלחו — מעין "פריטים שנשלחו" לחתימות. בכל
> טופס מופיע הסטטוס (ממתין, נחתם וכו') והמזהה. השדות אופציונליים.

---

## Group C — Send for signature (the everyday job) | קבוצה C — שליחה לחתימה

These two actions are what most flows actually use.

### 5. Send template for signature | שליחת תבנית לחתימה ⭐

**Plain meaning:** The main action. Take a ready template, say who should sign, and
**send it**. Each recipient immediately gets an email with their personal signing
link.

**When to use:** Every time you want to send a document out for signature. This is
the action the "Send signature request" flow uses.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Template ID | Which template (document) to send — from action 3. |
| Form name | A friendly name for this specific send, e.g. "Know your customer – Dana Levi". It helps you recognise it later. |
| Recipients | The people who should sign. For each one you give a **name** and **email**, the **order** they sign in (1, 2, 3…), and mark whether they actually sign or just receive a copy. |

**What you get back:** The new form, including its **form ID** and a **signing link**
for each recipient. Save the form ID so you can track the status later.

![Send template action](images/05-send-template.png)

> **בעברית:** הפעולה המרכזית. בוחרים תבנית מוכנה, מציינים מי צריך לחתום, ו**שולחים**.
> כל נמען מקבל מיד מייל עם קישור חתימה אישי. ממלאים: "מזהה תבנית" (איזה מסמך), "שם
> הטופס" (שם ידידותי לשליחה הזו), ו"נמענים" — לכל נמען שם, מייל, סדר חתימה (1,2,3) והאם
> הוא חותם או רק מקבל עותק. בחזרה מקבלים **מזהה טופס** ו**קישור חתימה** לכל נמען. שמרו
> את מזהה הטופס כדי לעקוב אחרי הסטטוס.

### 6. Create a draft form from a template | יצירת טיוטה מתבנית

**Plain meaning:** Same as "Send", **but it does not send anything yet**. It prepares
the document as a draft so you (or the user) can review it before it goes out.

**When to use:** For a "Preview" button — create the draft, look at it, then send for
real later.

**What you fill in:** The **Template ID** (and recipients if you want to pre-fill
them). No email is sent.

**What you get back:** A draft form with an ID, ready to be reviewed or sent.

![Create draft form action](images/06-create-draft.png)

> **בעברית:** כמו "שליחה", אבל **לא שולח עדיין כלום** — מכין את המסמך כטיוטה לבדיקה
> לפני השליחה. שימושי לכפתור "תצוגה מקדימה": יוצרים טיוטה, בודקים, ואז שולחים. ממלאים
> "מזהה תבנית", ולא נשלח שום מייל.

---

## Group D — Advanced / manual control | קבוצה D — שליטה ידנית מתקדמת

You normally don't need these — "Send template" does the whole job in one step. They
exist for the manual, step-by-step way of building a signature request (upload your
own file, add signers, then send), and for managing forms after they're out.

> בדרך כלל לא צריך את אלה — "שליחת תבנית" עושה הכול בצעד אחד. הן קיימות לדרך הידנית
> צעד-אחר-צעד (העלאת קובץ משלך, הוספת חותמים, ואז שליחה) ולניהול טפסים לאחר השליחה.

### 8. Create form | יצירת טופס

**Plain meaning:** Start an **empty** signature form from scratch (not from a
template). You'll then add a file and recipients yourself in the next steps.

**When to use:** Only in the manual flow, when you don't start from a template.

**What you fill in:** Basic details for the new form (such as a name).

**What you get back:** An empty form with an ID to use in the following steps.

![Create form action](images/08-create-form.png)

> **בעברית:** מתחילה טופס חתימה **ריק** מאפס (לא מתבנית). אחר כך מוסיפים בעצמך קובץ
> ונמענים. משמשת רק בזרימה הידנית. מקבלים מזהה טופס לשלבים הבאים.

### 11. Set recipients (assignees) | קביעת נמענים

**Plain meaning:** Tell an existing form **who needs to sign it** and in what order.

**When to use:** In the manual flow, after creating a form, before sending it.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Form ID | Which form you're adding signers to (from action 8). |
| Recipients | The signers — name, email, signing order, and whether they sign or just get a copy. |

**What you get back:** Confirmation that the signers were attached to the form.

![Set recipients action](images/11-set-assignees.png)

> **בעברית:** מגדירה לטופס קיים **מי צריך לחתום** ובאיזה סדר. ממלאים "מזהה טופס" ואת
> רשימת הנמענים (שם, מייל, סדר חתימה, והאם חותם או רק מקבל עותק). משמשת בזרימה הידנית
> אחרי יצירת טופס ולפני שליחתו.

### 12. Upload file | העלאת קובץ

**Plain meaning:** Attach the actual document (a PDF) to a form that you built
manually.

**When to use:** In the manual flow, when you bring your own file instead of using a
template.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Form ID | Which form the file belongs to. |
| File | The document content to attach (usually a PDF). |

**What you get back:** Confirmation that the file is attached.

![Upload file action](images/12-upload-file.png)

> **בעברית:** מצרפת את המסמך עצמו (PDF) לטופס שבנית ידנית. ממלאים "מזהה טופס" ואת
> הקובץ. משמשת בזרימה הידנית כשמביאים קובץ משלך במקום תבנית.

### 13. Send form | שליחת טופס

**Plain meaning:** Send a form that you assembled manually (file + recipients) so the
signers get their emails. This is the manual equivalent of "Send template".

**When to use:** At the end of the manual flow, once the form has a file and signers.

**What you fill in:** The **Form ID** of the form to send.

**What you get back:** Confirmation and the signing links for the recipients.

![Send form action](images/13-send-form.png)

> **בעברית:** שולחת טופס שהורכב ידנית (קובץ + נמענים) כך שהחותמים יקבלו את המיילים.
> זו המקבילה הידנית ל"שליחת תבנית". ממלאים "מזהה טופס". משמשת בסוף הזרימה הידנית.

### 9. Get form status | בדיקת סטטוס טופס

**Plain meaning:** Check what's happening with a form you sent — is it still waiting,
viewed, signed, or declined?

**When to use:** To follow up after sending, e.g. a flow that updates Dynamics when
the document is signed.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Form ID | The form you want to check (you saved this when you sent it). |

**What you get back:** The current status and details of each signer.

![Get form status action](images/09-get-status.png)

> **בעברית:** בודקת מה קורה עם טופס שנשלח — האם עדיין ממתין, נצפה, נחתם או נדחה.
> ממלאים "מזהה טופס". שימושי למעקב לאחר שליחה (למשל זרימה שמעדכנת את Dynamics כשהמסמך
> נחתם).

### 14. Download document | הורדת מסמך

**Plain meaning:** Download the finished, signed PDF so you can store it back in
Dynamics 365.

**When to use:** Once a form is fully signed, to keep a copy on the record.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Form ID | The signed form whose PDF you want. |

**What you get back:** The signed PDF file content.

![Download document action](images/14-download.png)

> **בעברית:** מורידה את ה-PDF החתום המוגמר כדי לשמור אותו חזרה ב-Dynamics 365. ממלאים
> "מזהה טופס". משתמשים בה לאחר שהטופס נחתם במלואו.

### 15. Cancel form | ביטול טופס

**Plain meaning:** Cancel a signature request that was already sent, so it can no
longer be signed.

**When to use:** When a request was sent by mistake or is no longer relevant.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Form ID | The form you want to cancel. |

**What you get back:** Confirmation that the form was cancelled.

![Cancel form action](images/15-cancel-form.png)

> **בעברית:** מבטלת בקשת חתימה שכבר נשלחה, כך שלא ניתן יותר לחתום עליה. ממלאים "מזהה
> טופס". משמשת כשבקשה נשלחה בטעות או אינה רלוונטית עוד.

### 10. Delete form | מחיקת טופס

**Plain meaning:** Permanently remove a form — usually a leftover draft you no longer
need.

**When to use:** To clean up drafts or test forms. Be careful: this is permanent.

**What you fill in:**

| Field | What it really means |
| --- | --- |
| Form ID | The form to delete. |

**What you get back:** Confirmation that the form was deleted.

![Delete form action](images/10-delete-form.png)

> **בעברית:** מוחקת טופס לצמיתות — בדרך כלל טיוטה שכבר לא צריך. ממלאים "מזהה טופס".
> זהירות: הפעולה בלתי הפיכה. שימושי לניקוי טיוטות או טפסי בדיקה.

---

## Quick reference | טבלת תמצית

| # | Action | One-line purpose |
| --- | --- | --- |
| 1 | Get entity | Test that the connection works. |
| 2 | Get profiles | List saved contacts in easydo. |
| 3 | Get templates | List your ready-made templates. |
| 4 | Get template detail | See a template's fields. |
| 5 | **Send template** ⭐ | Send a template for signature (main action). |
| 6 | Create draft form | Prepare a draft without sending (preview). |
| 7 | List forms | See forms already created/sent. |
| 8 | Create form | Start an empty form (manual flow). |
| 9 | Get form status | Check if a form is signed yet. |
| 10 | Delete form | Permanently remove a form. |
| 11 | Set recipients | Add signers to a manual form. |
| 12 | Upload file | Attach a PDF to a manual form. |
| 13 | Send form | Send a manually built form. |
| 14 | Download document | Get the signed PDF. |
| 15 | Cancel form | Stop a sent request. |

> ⭐ = the action used by the everyday "Send signature request" flow.
