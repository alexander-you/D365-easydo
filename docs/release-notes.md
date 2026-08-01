# Release Notes | יומן גרסאות

> יומן גרסאות ושלבי התקדמות הפרויקט.

All notable changes to this project are documented here.

## [2.0.0.0] — envelopes (multi-document packages), recipient authentication (PIN/OTP), template gallery & on-demand status (2026-08-01)

> **Major release.** This version turns the solution from single-document signing into a
> full **multi-document envelope** platform, adds **recipient authentication** (PIN / OTP),
> a redesigned **Template Gallery** and **Documents** experience, real-time signing for
> envelopes, and on-demand status refresh. Two new tables, seven new connector operations,
> two new PCF controls and one new flow. Managed **and** unmanaged packages shipped.
>
> **גרסה מרכזית.** גרסה זו הופכת את הפתרון מחתימה על מסמך בודד ל**מעטפות רב‑מסמכיות**
> מלאות, מוסיפה **אימות נמען** (PIN / OTP), גלריית תבניות ומסך מסמכים מחודשים, חתימה בזמן
> אמת למעטפות, ורענון סטטוס לפי דרישה. שתי טבלאות חדשות, שבע פעולות קונקטור, שני פקדי PCF
> וזרימה אחת חדשה. נשלחו חבילות מנוהלת **וגם** לא‑מנוהלת.

### Added — Envelopes (multi-document packages) | מעטפות

- **Send several documents as one signing package.** A template can now be an
  **envelope** (`alex_signaturetemplate.alex_isenvelope = true`) that bundles several
  document templates. The composition is defined by the new
  **`alex_envelopetemplateitem`** table (one row per member document: name, order,
  external template id, default role), kept in sync from easydo.
- **Two new tables.**
  - **`alex_envelopetemplateitem`** — the envelope **definition** (which documents make
    up an envelope template), created by
    [45/46 scripts](../src/scripts/46-create-envelope-template-item-table.ps1) and
    populated by [51-sync-envelope-members.ps1](../src/scripts/51-sync-envelope-members.ps1)
    and the template-sync flows.
  - **`alex_signaturerequestitem`** — the **runtime** per-document row inside a sent
    envelope (sequence, `alex_externalformid`, `alex_fillurl`, `alex_itemstatus`,
    `alex_signedon`), created by
    [45-create-envelope-item-table.ps1](../src/scripts/45-create-envelope-item-table.ps1)
    with a read-only form and two views
    ([57-create-item-form.ps1](../src/scripts/57-create-item-form.ps1)).
- **Per-document status choice.** New global choice **`alex_envelopeitemstatus`**:
  Pending (626220000), Waiting For Signature (626220001), Signed (626220002),
  Declined (626220003), Expired (626220004), Error (626220005).
- **Envelope columns on the request/template.** `alex_signaturerequest` gained
  `alex_ismultidocument`, `alex_externalenvelopeid`, `alex_envelopefillurl`;
  `alex_signaturetemplate` gained `alex_isenvelope` and `alex_envelopehost` (the anchor
  for the Envelope Composition PCF); `alex_signaturefieldvalue` gained an
  `alex_templateid` lookup so read-back values are attributed to the **right member
  document** in an envelope.
- **Envelope Composition PCF + tab.** New field-type control
  ([src/pcf-envelope/](../src/pcf-envelope/)) hosted on a dedicated **envelope** tab of
  the template form; [50-place-envelope-pcf-and-tabs.ps1](../src/scripts/50-place-envelope-pcf-and-tabs.ps1)
  and [envelopeTabToggle.js](../src/webresources/envelopeTabToggle.js) show exactly one
  tab (document mapping **or** envelope composition) based on `alex_isenvelope`.
- **Seven new connector operations.** `GetEnvelopeTemplates`, `CreateEnvelope`,
  `GetEnvelope`, `UpdateEnvelope`, `DeleteEnvelope`, `SendEnvelope`, `DownloadEnvelope`
  (see [custom-connector.md](custom-connector.md)).

> **בעברית.** אפשר עכשיו לשלוח **כמה מסמכים כחבילת חתימה אחת (מעטפה)**. תבנית יכולה להיות
> **מעטפה** שמאגדת כמה תבניות מסמך. נוספו שתי טבלאות: **`alex_envelopetemplateitem`**
> (הגדרת המעטפה — אילו מסמכים מרכיבים אותה) ו**`alex_signaturerequestitem`** (שורת ריצה
> לכל מסמך בתוך מעטפה שנשלחה, עם סטטוס וקישור חתימה פר‑מסמך). נוסף מצב פר‑מסמך
> (`alex_envelopeitemstatus`), עמודות מעטפה על הבקשה/התבנית, ופקד **הרכב מעטפה** (PCF)
> בטאב ייעודי שמתחלף אוטומטית לפי אם התבנית היא מעטפה. בקונקטור נוספו **שבע פעולות מעטפה**.

### Added — Recipient authentication: PIN & OTP | אימות נמען

- **Templates can require the signer to authenticate.** New authentication settings on
  `alex_signaturetemplate` ([47](../src/scripts/47-add-template-auth-columns.ps1),
  [54](../src/scripts/54-add-otp-columns.ps1)): **authentication method**
  (`alex_authmethod` — None / PIN / OTP-SMS), **PIN mode** (`alex_pinmode` — No PIN /
  Fixed PIN / Variable PIN from a field), fixed `alex_pinvalue`, `alex_pinsourcefield`,
  `alex_otpphonesource`, and per-send override switches
  (`alex_pinallowsendoverride`, `alex_otpallowsendoverride`).
- **The effective value is stamped on each request.** New
  `alex_signaturerequest.alex_effectiveauthmethod` and `alex_effectivepin`
  ([48](../src/scripts/48-add-request-effective-auth-columns.ps1)) record exactly what
  authentication was applied for that send.
- **Connector supports it end-to-end.** `SendTemplate`, `SendEnvelope` and
  `UpdateEnvelope` gained an `auth_method` field (`''` / `pin` / `otp`) plus `pin`.

> **בעברית.** תבנית יכולה עכשיו **לדרוש מהחותם לאמת את עצמו**: שיטת אימות (ללא / PIN /
> OTP ב‑SMS), מצב PIN (ללא / קבוע / משתנה משדה), ערך/שדה מקור ל‑PIN וטלפון ל‑OTP, ומתגי
> **דריסה לכל שליחה**. הערך שהוחל בפועל נחתם על הבקשה (`alex_effectiveauthmethod`,
> `alex_effectivepin`). הקונקטור תומך בכך מקצה לקצה דרך שדה `auth_method` בפעולות השליחה.

### Added — Template Gallery & Documents experience | גלריית תבניות ומסך מסמכים

- **Template Gallery PCF.** A new Apple-style **card gallery**
  ([src/pcf-template-gallery/](../src/pcf-template-gallery/), `EasyDoTemplateGallery`)
  replaces the flat template list: cards distinguish **envelope** vs single **document**,
  show an active/inactive/deleted status pill and the primary table, with toolbar filters,
  live search, sort and an animated side panel (sync / binding / auth / roles / members).
- **Documents grid + on-demand status check.** The Documents PCF
  ([src/pcf-documents/](../src/pcf-documents/)) gained a **"Check status"** action that
  stamps `alex_statuscheckrequestedon`, triggering the new **Check Signature Status**
  flow to re-poll easydo immediately instead of waiting for the 5-minute cycle. Backing
  columns `alex_statuscheckrequestedon` / `alex_statuschecklastrunon` /
  `alex_statuscheckstatus` ([56](../src/scripts/56-add-statuscheck-columns.ps1)).
- **Document viewer** enhancements for envelopes and per-document state.

> **בעברית.** נוספה **גלריית תבניות** (PCF בסגנון כרטיסיות) שמחליפה את הרשימה השטוחה —
> מבחינה בין מעטפה למסמך בודד, מציגה סטטוס וטבלה ראשית, עם סינון/חיפוש/מיון ופאנל צדדי
> מונפש. פקד **המסמכים** קיבל פעולת **"בדיקת סטטוס"** לפי דרישה, שמפעילה מיד את זרימת
> **Check Signature Status** במקום להמתין למחזור ה‑5 דקות.

### Added — Real-time signing for envelopes | חתימה בזמן אמת למעטפות

- **The live signing panel now understands envelopes.** When an envelope is sent in
  real-time mode, [realtimeSession.html](../src/webresources/realtimeSession.html) shows a
  **per-document checklist** with live Signed / Declined / Pending indicators, and loads
  the **combined signed PDF** once every document is complete.
- **The poll flow handles envelope sessions.** A new additive branch in
  [realtime-session-poll.flow.json](../src/flows/realtime-session-poll.flow.json) polls
  `GetEnvelope`, updates each `alex_signaturerequestitem`, lights the request status
  (Sent → Viewed → Completed / Declined), reads back all member fields, downloads the
  package via `DownloadEnvelope` and attaches it to the business record.

> **בעברית.** פאנל החתימה החי **מזהה עכשיו מעטפות**: מוצגת **רשימת מסמכים** עם חיווי חי
> נחתם / נדחה / ממתין, וה‑PDF המאוחד נטען עם סיום כל המסמכים. זרימת ה‑polling קיבלה ענף
> ייעודי למעטפות שמעדכן כל פריט, מדליק את הסטטוס, קורא חזרה את השדות ומצרף את החבילה
> החתומה לרשומה העסקית.

### Added — Copy-link governance | ממשל העתקת קישור

- **Control whether agents may copy a raw signing link.** New global switch
  `alex_easydosettings.alex_allowcopylink` and per-template override
  `alex_signaturetemplate.alex_copylinkmode` (Inherit / Allow / Block)
  ([60](../src/scripts/60-add-copylink-columns.ps1)); the Admin Center settings drawer
  exposes the global default.

> **בעברית.** נוסף ממשל **העתקת קישור חתימה**: מתג גלובלי (`alex_allowcopylink`) ודריסה
> פר‑תבנית (`alex_copylinkmode` — ברירת מחדל / מותר / חסום), עם מתג במרכז הניהול.

### Changed | שינויים

- **Admin Center refresh.** Connections + required flows merged into one health card with
  an inline progress bar and an overall status pill; a separate **optional flows** card
  (copy/SharePoint flows) that does **not** gate readiness; flows are now discovered live
  from the solution instead of a hard-coded list.
- **Read-only main forms + bilingual associated views.** All nine data tables now render
  their main form **read-only** (records are system-maintained), and each table's
  associated view was rebuilt with meaningful columns and a bilingual name
  ([59-lockdown-forms-and-assoc-views.ps1](../src/scripts/59-lockdown-forms-and-assoc-views.ps1)).
- **Template soft-delete.** Templates removed from easydo are deactivated with a new
  **Deleted** status reason (`626210000`) instead of being hard-deleted
  ([55](../src/scripts/55-add-template-deleted-status.ps1)); the gallery shows a red
  *deleted* pill.

> **בעברית.** **מרכז הניהול** רוענן (כרטיס תקינות אחד, זרימות אופציונליות שאינן חוסמות,
> גילוי זרימות חי). כל **תשעת** הטפסים הראשיים הם עכשיו **לקריאה בלבד** והתצוגות המשויכות
> נבנו מחדש עם שמות דו‑לשוניים. תבניות שנמחקו ב‑easydo מושבתות עם סיבת סטטוס **נמחק**
> במקום מחיקה קשיחה, והגלריה מציגה תווית אדומה.

### Fixed | תוקן

- **Envelope name showed a GUID.** Envelope requests now resolve the envelope
  template's real name (via `WizardIntakePlugin.ResolveTemplate`) instead of
  `easydo - <guid>`.
- **Real-time panel RTL layout.** The progress-rail connector line and a stray white side
  strip were an RTL bug in [realtimeSession.html](../src/webresources/realtimeSession.html)
  (`.edo-rt-line` drawn on the wrong physical side); fixed with an RTL-specific rule plus
  `overflow` clipping.

> **בעברית.** **שם המעטפה** הציג GUID — עכשיו נפתר לשם התבנית האמיתי. תוקן באג **RTL**
> בפאנל בזמן אמת (קו המחבר בפס ההתקדמות ורצועה לבנה בצד).

## [1.3.0.0] — document validity / expiry (auto-cancel overdue signature requests) (2026-07-30)

### Added

- **Document expiry per signature template.** Three new settings live **inside** the
  Template Field Mapping PCF config strip (no extra form clutter): **has-expiry**
  (`alex_hasexpiry`), **validity days** (`alex_expirydays`, 1–3650) and **allow
  per-send override** (`alex_allowexpiryoverride`). When enabled, the **Send Signature
  Request** flow stamps a computed **`alex_expireson`** on the request at send time
  (`addDays(utcNow(), effectiveDays)`).
- **Per-send validity override in the wizard.** When a template allows it,
  [sendWizard.html](../src/webresources/sendWizard.html) shows a validity-days input in
  the settings step and carries the chosen value through `alex_wizardpayload`; the send
  flow prefers the override and falls back to the template default.
- **Daily auto-cancel of overdue requests.** New **Expire Overdue Requests** flow
  ([expire-overdue-requests.flow.json](../src/flows/expire-overdue-requests.flow.json))
  runs once a day, lists open requests whose `alex_expireson` has passed, cancels the
  easydo form (`CancelForm`) and marks the request **Expired** (`alex_status` = 626210010,
  `alex_cancelledon`).

> **בעברית.** נוסף פיצ'ר **תוקף מסמך** לכל תבנית חתימה. שלוש הגדרות חדשות יושבות **בתוך**
> רצועת ההגדרות של ה‑PCF (בלי להעמיס על הטופס): הפעלת תוקף, מספר ימי תוקף (1–3650), והרשאת
> **דריסה לכל שליחה**. כשמופעל, זרימת **Send Signature Request** מחשבת וממלאת
> **`alex_expireson`** ברגע השליחה. בוויזרד ניתן לדרוס את מספר ימי התוקף לשליחה בודדת
> (עובר דרך `alex_wizardpayload`). זרימה חדשה **Expire Overdue Requests** רצה **פעם ביום**,
> מאתרת בקשות פתוחות שפג תוקפן, מבטלת את הטופס ב‑easydo ומסמנת את הבקשה כ‑**פג תוקף**.

## [1.2.0.0] — multi-page read-back (signed-value write-back across all pages) (2026-07-30)

### Fixed

- **Read-back now processes every page of a signed document, not just the first.**
  The **Read Signature Results** flow ([read-signature-results.flow.json](../src/flows/read-signature-results.flow.json))
  previously read only `first(payload.data)` — i.e. page 0 of the returned form —
  because the original test templates were single-page. On a real multi-page contract
  (easydo returns `payload.data` as **one array element per PDF page**), every field on
  pages 1..N (e.g. **payment currency** on page 23) was silently skipped, so no
  `alex_signaturefieldvalue` row was created and the write-back plugin had nothing to
  write. The flow now wraps the value extraction in a `Process_each_page` loop over the
  full `payload.data`, so **all fields on all pages** are captured. Values are still read
  from the flat top-level `data[header]` object. Handles an unlimited number of pages and
  fields (both loops run with `concurrency.repetitions = 1` to avoid Dataverse throttling).
  New implementer guide: [multipage-readback-fix.md](multipage-readback-fix.md).

> **בעברית.** זרימת קריאת התוצאות קראה בעבר רק את **העמוד הראשון** של המסמך החתום
> (`first(payload.data)`), כי תבניות הבדיקה המקוריות היו בנות עמוד אחד. במסמך אמיתי
> רב‑עמודים easydo מחזירה את `payload.data` כמערך **לפי עמוד**, ולכן כל שדה בעמודים
> 1..N (למשל **מטבע התשלום** בעמוד 23) דולג בשקט ולא נכתב חזרה ל‑Dynamics. הזרימה עוטפת
> עכשיו את חילוץ הערכים בלולאת `Process_each_page` על כל העמודים — כך **כל השדות מכל
> העמודים** נקראים. הערכים עדיין נשאבים מהאובייקט השטוח `data[header]`. תומך בכמות עמודים
> ושדות בלתי‑מוגבלת (שתי הלולאות רצות סדרתית למניעת חניקה). נוסף מדריך מיישם ייעודי.

## [1.1.0.0] — field description, signature hiding & contact prefill in the wizard (2026-07-07)

### Added

- **Field description vs. export name — documented.** Every synced template field now
  carries two clearly separated names: **`alex_externalfieldname`** (the human **field
  description**, from easydo `label`) and **`alex_externalexportname`** (the machine
  **export name**, from easydo `export.header`, the binding key used by auto‑mapping). A
  new bilingual guide explains the business and technical meaning of each:
  [field-description-vs-export-name.md](field-description-vs-export-name.md).
- **Signature fields hidden by default in the mapping grid.** The Template Field Mapping
  PCF now hides fields whose type contains `signature` (they are never mapped to a
  Dynamics column), with an opt‑in **"Show signature fields"** checkbox to reveal them.
- **Contact (lookup‑hop) fields resolve in the send wizard preview.** `sendWizard.html`
  now follows lookup hops **client‑side** — e.g. contract → `alex_id_student` → contact —
  so related‑record values (first name, last name, email, address…) are shown in the
  **Data** step, not just direct columns on the launch record. One extra retrieve per
  distinct lookup, guarded and batched with `Promise.all`.

### Changed

- **Mapping display uses the real description.** The template sync now writes
  `alex_externalfieldname` from easydo **`label`** (`coalesce(label, header, name)`)
  instead of `placeholderLabel`, which was only a **generic field‑type name** ("Text
  field", "Date") rather than an actual description.

> **בעברית.** כל שדה תבנית מסתנכרן עכשיו עם שני שמות נפרדים: **תיאור שדה**
> (`alex_externalfieldname`, מ‑`label` של easydo — לבני אדם) ו**שם ייצוא**
> (`alex_externalexportname`, מ‑`export.header` — מפתח הקישור לאוטומציה). נוסף מדריך
> דו‑לשוני שמסביר את המשמעות העסקית והטכנית של כל אחד. פקד מיפוי השדות **מסתיר שדות חתימה**
> כברירת מחדל (עם תיבת סימון "הצג שדות חתימה"). אשף השליחה **פותר עכשיו שדות איש‑קשר** (קפיצת
> lookup) בצד הלקוח, כך שערכי הרשומה הקשורה מוצגים בשלב "נתונים" ולא רק עמודות ישירות. תצוגת
> המיפוי משתמשת כעת ב‑`label` (התיאור האמיתי) במקום ב‑`placeholderLabel` (שם‑סוג גנרי).

## Backlog | לטיפול בהמשך

- **Abandoned preview cleanup | ניקוי תצוגות מקדימות שננטשו.** When a user generates a
  preview but decides **not** to send, the signature request stays in **Draft**
  (`alex_status=626210000`, `alex_ispreviewgenerated=true`, `alex_previewformid`/
  `alex_previewurl` set) and the easydo draft form (status `incomplete`) is left
  **orphaned**. Need a cleanup path — e.g. a scheduled flow that deletes easydo draft
  forms (`DeleteForm`) for requests still in Draft with a generated preview older than
  N days and clears the preview columns, and/or a "discard preview" action in the
  wizard that calls `DeleteForm` and resets the request. Not yet implemented.

## [Unreleased] — decline reason capture & comprehensive status sync (2026-06-27)

### Added

- **Decline reason captured.** New multiline column **`alex_declinereason`** on
  `alex_signaturerequest` (`src/scripts/36-add-declinereason-column.ps1`). When easydo
  reports a declined form, the read-back flow stores the recipient's typed reason
  (easydo assignee `decline_reason`) into this column, and `documentViewer.html` shows
  it on the side panel for declined requests.
- **Comprehensive status sync.** The read-back flow's `Record_the_status_check` step
  now maps the **full** easydo lifecycle to `alex_status` on every poll, not only
  completion: `decline` → **Declined** (626210007), `expired` → **Expired** (626210010),
  `canceled`/`deleted_at` → **Cancelled** (626210009), `signed`/`has_data` →
  **Completed** (626210006), a `view` engagement-log event → **Viewed** (626210004);
  otherwise the current status is preserved. Existing-record-safe (the trigger picks up
  any request still in an open status).
- **Failed-send timestamp.** The Send flow now stamps **`alex_senton`** with `utcNow()`
  when a send fails (alongside status **Failed** 626210008 and the error message), so a
  failed attempt has a meaningful timestamp in the grid/side panel.

### Documented

- **Connector `GetFormStatus` fully described.** The swagger response for
  `GET /entity/me/forms/{formId}` was a bare `200 OK`; it now carries a full inline
  schema — form-level `status` enum (`waiting/signed/decline/expired/canceled`),
  `has_data`, timestamps, plus the `assignees[]` array including per-assignee `status`,
  **`decline_reason`** and the engagement `log[]`. Re-deployed to the EN connector.

### Decisions

- **No `delivered` signal.** Empirically, easydo exposes only the engagement-log
  actions `attachment, decline, fill, view` and no delivery receipt, so **Delivered**
  (626210003) is intentionally **not** auto-set. **Viewed** is the earliest reliable
  signal after sending.

> **בעברית.** נוספה לכידת **סיבת דחייה** (`alex_declinereason`) — סיבת הסירוב שהלקוח
> הקליד ב‑easydo נשמרת ומוצגת בפאנל הצדדי. זרימת ה‑polling מסנכרנת עכשיו את **כל**
> מחזור החיים (נדחה / פג‑תוקף / בוטל / הושלם / נצפה) ולא רק הושלם, וגם רשומות עבר
> נתפסות. בכישלון שליחה נחתם `alex_senton`. ה‑swagger של `GetFormStatus` תועד במלואו
> (כולל `decline_reason`) ונפרס מחדש לקונקטור. אין ל‑easydo אות "נמסר" אמין, לכן
> **נמסר** לא נקבע אוטומטית — **נצפה** הוא האות הראשון האמין.

## [Unreleased] — send-table enablement survives managed solutions (2026-06-26)

### Fixed

- **Enabling a send table no longer fails on a managed (customer) environment.**
  The admin center "Send tables management" screen (`adminCenter.html`) calls the
  `alex_EnsureSignatureLookup` Custom API (`EnsureSignatureLookupPlugin`) to
  provision, on demand, a native N:1 relationship `alex_<table>_signaturerequest`
  (lookup `alex_related<table>id`) between the business table and
  `alex_signaturerequest`. The plug-in previously always added that new relationship
  to the hard-coded `alex_d365_easydo` solution and **swallowed** the error if that
  solution was **managed**. On a customer org this raised *"Cannot update a managed
  solution"*; because the exception was caught and ignored, the platform aborted the
  whole transaction (*"ISV code reduced the open transaction count"*) and rolled the
  relationship back — the table stayed stuck on **Failed (4)** with the easydo
  connection error (*"שגיאת קשר"*).

### Added

- **Runtime solution for managed environments.** The plug-in now resolves a
  **writable** target solution before adding the relationship:
  - base `alex_d365_easydo` is **unmanaged** (Dev) → use it directly — no change, no
    warning;
  - base is **managed** (Test/Prod/customer) → create or reuse a dedicated
    **unmanaged** solution **`alex_d365_easydo_runtime`** ("D365 easydo - Runtime
    Customizations") under the same publisher, add the relationship there, and return
    an advisory.
  - The plug-in **no longer swallows** `OrganizationService` exceptions, so a real
    failure surfaces instead of corrupting the transaction.
- **New Custom API outputs** on `alex_EnsureSignatureLookup`: `TargetSolution` (which
  solution received the relationship) and `Warning` (advisory text). `adminCenter.html`
  shows the warning as a toast and stores it in `alex_statusmessage`.

### Decisions

- **Business — why a separate runtime solution.** A managed solution is read-only by
  design; on a customer's environment our base solution arrives managed, so new
  metadata cannot be written into it. Rather than block the admin, the feature keeps
  the customer self-serving: the on-the-fly relationship is placed in a clearly named
  *runtime* solution, and the admin is told (via the warning) that this customization
  now lives there and should be exported with the rest of their unmanaged layer.
- **ALM — managed dependencies are expected.** Enabling a table that is owned by a
  managed first-party solution makes the easydo solution **depend** on it: e.g.
  `account`/`salesorder` → **Sales** (`msdynce_Sales`), `incident`/`entitlement` →
  **Service** (`msdynce_Service`), `msevtmgt_event` → **Marketing – Event Management**.
  Those managed solutions must exist in the target environment or import fails — so
  only enable the tables the customer actually has.

### Verified

- Live in Dev (EN, unmanaged base): re-enabling `account`, `entitlement`, `incident`
  and `msevtmgt_event` created their relationships and set the config rows to
  **Created (3)** with no transaction rollback; no runtime solution is created because
  the base is unmanaged (by design).

> **בעברית.** הפעלת טבלת שליחה ממסך "ניהול טבלאות שליחה" קוראת ל‑Custom API
> `alex_EnsureSignatureLookup` שמייצר ביקוש קשר N:1 בין הטבלה העסקית ל‑
> `alex_signaturerequest`. קודם הפלאגין הוסיף את הקשר ל‑solution הקשיח
> `alex_d365_easydo` ו**בלע** שגיאה כשה‑solution מנוהל — מה שגרם לגלגול הטרנזקציה
> לאחור ולסטטוס **נכשל (4)** עם "שגיאת קשר". **התיקון:** אם הבסיס לא‑מנוהל (פיתוח)
> משתמשים בו ישירות; אם מנוהל (לקוח) נוצר/נעשה שימוש ב‑solution לא‑מנוהל ייעודי
> **`alex_d365_easydo_runtime`** והמשתמש מקבל **אזהרה** שההתאמה נשמרה שם; הפלאגין כבר
> אינו בולע חריגות. **השלכת ALM:** הפעלת טבלה בבעלות solution מנוהל (Sales / Service /
> Marketing) יוצרת **תלות מנוהלת** עליו — שחייבת להתקיים בסביבת היעד, אחרת הייבוא
> ייכשל. לכן יש להפעיל רק טבלאות שהלקוח באמת מחזיק.

## [Unreleased] — signed PDF on the primary record, smart last-viewed & per-table lookups (2026-06-21)

### Added

- **Signed PDF lands on the business record (not the request).** New Custom API
  **`alex_AttachSignedPdf`** (`AttachSignedPdfPlugin`) takes the request id, file
  name and base64 PDF, resolves the request's **primary** record
  (`alex_primaryrecordid` + the template's `alex_primarytable`, with a contact
  fallback) and creates **one** annotation on **that** record's Timeline. The
  read-back flow now calls it via `PerformUnboundAction` instead of attaching a note
  to the signature request itself.
- **Smart "last viewed".** New datetime column **`alex_lastviewedon`** on
  `alex_signaturerequest` (`src/scripts/23-add-lastviewedon-column.ps1`). The
  read-back flow filters the easydo assignee **engagement log** for `action = view`
  and stores only the **most recent** view time — a single meaningful timestamp,
  not a visit counter. Added to the request main form.
- **Per-table dedicated lookups.** Each supported primary table gets a native lookup
  on `alex_signaturerequest` (`alex_related<table>id`, e.g.
  `alex_RelatedEntitlementId`), provisioned **on the fly** by
  `src/scripts/22-create-related-record-lookups.ps1` (one per distinct
  `alex_primarytable`; contact already covered by `alex_relatedcontactid`).
  `PopulateAnchorPlugin` fills the matching lookup alongside the anchor. The
  entitlement lookup was added to the request main form.

### Decisions

- The signed PDF is attached to the **primary business record only** — no duplicate
  note on the signature request.
- Lookup-column existence is checked via **`RetrieveEntityRequest`** (entity
  metadata), cached per process — `RetrieveAttributeRequest` failed silently inside
  the plug-in sandbox (anchor set but lookup left empty).

### Verified

- Entitlement-anchored request → `alex_relatedentitlementid` populated (live E2E,
  test record deleted afterwards). Items A/B deploy on the next 5-minute read-back
  cycle for a completing request.

## [Unreleased] — send wizard, entity config & template control flags (2026-06-20)

### Added

- **Send wizard** as an HTML **web resource** hosted in a model-driven **side pane**
  (`src/webresources/sendWizard.html` + launcher `formSend.js`). Same-origin, so it
  uses native `Xrm.WebApi` (no premium connector). Steps: template → data
  (prefill/validate) → recipients → review.
- **Wizard intake plug-in** (`WizardIntakePlugin`): parses the wizard JSON
  (`alex_wizardpayload`) into a full signature request — resolving template + related
  fields (pre-validation) and creating recipient rows + flipping status to
  *Ready to Send* (post-operation).
- **Template control flags** surfaced in the field-mapping **PCF** config strip
  (v0.4.0): `alex_allowsendfromobject` (hide a template from the wizard) and
  `alex_allowprefilledit` (enable the data step), plus `alex_rolesjson` for named
  signer roles. Backing columns by `src/scripts/14-add-template-send-wizard-columns.ps1`
  and backfill `15-backfill-template-roles-and-sendflag.ps1`.
- **Entity-config table** `alex_easydoentityconfig` (`16`/`20` scripts) and a
  global form button to launch the wizard (`19-deploy-global-formbutton.ps1`),
  plus `21-add-wizard-payload-column.ps1`.

### Decisions

- Wizard UI is a **side-pane web resource**, not a canvas custom page or full-page
  PCF: canvas custom pages cannot read/write Dataverse at runtime in this env, and
  a custom full-page PCF (`pagetype=control`) is unsupported. Same-origin web
  resource → native `Xrm.WebApi`.
- ResolvePrefill / write-back fall back to the **related contact** as the anchor when
  the template's primary table is `contact` and no explicit anchor is present.

## [Unreleased] — field prefill, lock & per-request values (2026-06-18)

### Discovered & verified (live, production)

- **Field prefill mechanism.** Reverse-engineered from the live web app and verified
  end-to-end: a template is sent with prefilled values via
  `POST /entity/me/templates/{templateId}/send` carrying a **`prefill_data`** array
  of `{ name, content_value, read_only }` items, where `name` is the field's
  **technical name** (e.g. `custom_field_6a32cedc7ede2`). Checkbox values are
  `"checked"` / `"unchecked"`. See `docs/api-research.md` §12.
- **Field lock.** The template-builder per-field lock is **not** enforced on a sent
  form by itself; passing **`read_only: true`** in the `prefill_data` item renders
  the input **disabled** (verified: typing into a locked field was rejected).
- **Read-back.** `GET /entity/me/forms/{id}` exposes a top-level `data` object keyed
  by `export.header`, populated once the recipient submits (`has_data` flips true) —
  the source for copying signed values back to Dynamics.
- Documented the approaches that **do not** work (do not retry) in
  `docs/api-research.md` §12.

### Added

- **Connector**: `prefill_data` array input added to the template **Send** operation
  (`name`, `content_value`, `read_only`), with bilingual summaries/descriptions.
- **Send flow** (`send-signature-request.flow.json`): on a real (non-draft) send it
  now lists the request's **Prefill** field values, builds the `prefill_data` array,
  and passes it to easydo.
- **Read-back flow** (`read-signature-results.flow.json`): a **scheduled** flow
  (recurrence every 5 min) that first lists only **open** requests (status Sent /
  Delivered / Viewed / In Progress with an `alex_externalformid`) — so a cycle with
  nothing pending makes **zero** easydo calls. For each, it reads the form; when
  `has_data` is `true` it writes the recipient-entered values as
  **`Read Back`** `alex_signaturefieldvalue` rows (keyed by `export.header`,
  skipping the signature field), marks the request **Completed**, downloads the
  signed PDF and attaches it to the request **Timeline** as a note.
- **Connector**: `DownloadDocument` now declares a binary (`application/pdf`)
  response so the signed PDF can be base64-encoded into a Dataverse annotation.
- **Dataverse**: new table **`alex_signaturefieldvalue`** (per-request field value)
  with columns `alex_fieldname`, `alex_fieldlabel`, `alex_value`, `alex_direction`,
  `alex_isreadonly`, a lookup to `alex_signaturerequest`, a main form and two views
  (*All Field Values*, *Prefill Values*). New global choice **`alex_fielddirection`**
  (Prefill / Read Back). Built by `src/scripts/09-create-fieldvalue-table.ps1` and
  added to the `alex_d365_easydo` solution (bilingual labels throughout).

### Decisions

- Prefill is **data-driven**: values live as Dataverse rows read at send time —
  **no Azure** and **no connector custom-code**. Connector dynamic-schema is not
  required (it would only improve design-time UX, not automation).
- Read-back is **scheduled polling** (every 5 min), gated by an up-front open-request
  query so idle cycles cost nothing; webhook remains a fast-follow.
- Signed PDF is stored as a **note on the request Timeline** (annotation) for the
  MVP; the dedicated `alex_signaturedocument` table (with its `alex_documentfile`
  File column) remains an option a control setting can switch to later.
- Read-back values are written as **new `Read Back` rows** (not upserts) to preserve
  an audit trail of *sent* (Prefill) vs *returned* (Read Back) values.

### Pending

- Stage B: a smart mapping of `Read Back` values onto Contact (or other) columns.

## [Unreleased] — initial setup (2026-06-17)

### Added

- Repository structure and initial documentation baseline.
- `docs/api-research.md` — easydo API research, **verified live against production**
  (`/entity/me` and `/entity/me/profiles` returned 200; entity `35866`).
- `docs/technical-architecture.md`, `docs/data-model.md` (baseline),
  `docs/security-model.md`, `docs/deployment-guide.md`.
- `.gitignore` blocking secrets, tokens, signed PDFs and payloads.

### Verified

- easydo API connectivity using a pre-issued 1-year Bearer token (production).
- Entity features relevant to the integration are enabled (Document-Send,
  Template-Forms, API-Webhooks, Multi-Recipient, Public-Link, Smart-Documents).

### Decisions

- MVP source record: **Contact**.
- Signed document storage: **Dataverse File**.
- Status tracking: **Polling** (webhook is a fast-follow).
- Preview before send: **easydo draft** (`draft:true`).

### Next phase

- Deeper architecture / solution-concept / data-model / table-relationship (ERD)
  documentation.
- Create the unmanaged Dataverse solution `alex_d365_easydo` and tables.
- Build the easydo Custom Connector.

### Security

- ⚠️ The development API token was shared in chat and **must be regenerated before
  production**.
