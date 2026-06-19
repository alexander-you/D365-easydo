# easydo API — Research & Verification | מחקר ואימות ה-API

Source: <https://easydoc.stoplight.io/docs/easydoc>
Last verified against the live API: **2026-06-18** (production).
The field **prefill + lock** behaviour (§12) was reverse-engineered from the live
web app and **verified end-to-end** on 2026-06-18.

This document captures the easydo API behaviour relevant to the Dynamics 365
digital-signature integration. It is the reference for building the Custom
Connector and Power Automate flows.

> מסמך זה מתעד את ה-API של easydo לאחר אימות מול הסביבה החיה
> (production, 17/06/2026). מאומת: אימות באמצעות Bearer token תקף לשנה, שליפת פרטי
> הישות (`/entity/me`) ורשימת הפרופילים (`/entity/me/profiles`). תהליך השליחה מורכב
> מ-4 קריאות: יצירת טופס → הגדרת נמענים → העלאת PDF → שליחה. מצב `draft:true` מאפשר
> תצוגה מקדימה לפני שליחה, ושדה `meta_data.client` משמש לקישור חזרה לרשומת D365.

---

## 1. Environments

| Environment | Base URL |
| --- | --- |
| Production | `https://api.easydo.co.il/api` |
| Sandbox | `https://sandbox.easydoc.co.il/` (replace the `api.easydo.co.il` host) |

- Fill links are served from `stage.easydoc.co.il` (and the production web app).
- API clients and webhooks are managed in the easydo web app (`app2.easydoc.co.il`
  / `stage.easydoc.co.il`) → Settings → **API Settings**.

## 2. Authentication

easydo uses a `Client ID` + `Secret` to issue a Bearer token.

```http
POST https://api.easydo.co.il/api/auth/token
# Parameters: API_CLIENT_ID, API_CLIENT_SECRET
```

Response:

```json
{ "token_type": "Bearer", "expires_in": 31536000, "access_token": "<token>" }
```

- The token is valid for **1 year** (`expires_in` = 31,536,000 s).
- Every authenticated request must include the header:
  `Authorization: Bearer <token>`.
- A pre-issued token can also be generated in the web app (Settings → API Client →
  *manage tokens*), which removes the need to call `/auth/token` for testing.

### Verification (2026-06-17, production)

```http
GET https://api.easydo.co.il/api/entity/me
Authorization: Bearer <token>
```

Returned **200** with the entity profile:

| Field | Value |
| --- | --- |
| `id` | `35866` |
| `name` | `חברה לדוגמה` (Sample Company) |
| `default_language` | `he` |
| `status` | `active` |

Relevant entity features that are **enabled**: `Document-Send`, `Send-Documents`,
`Template-Forms`, `Template-Envelopes`, `API-Clients`, `API-Webhooks`,
`Multi-Recipient`, `Public-Link`, `Smart-Documents`, `Conditional-Fields`,
`Formula-Fields`, `Pin-Code`, `Fill-OTP`, `Auto-Refresh`, `Recipient-Group`,
`Flexible-Recipient`, `Contacts`, `Bulk-Forms`, `Form-Edit`, `HTML-Forms`.

Disabled for this entity: `Employee-Management`, `Onboarding`, `101-Report`,
`Payslips`, `Workflows`, `QES`, `SSO`.

## 3. Profiles

A *profile* is any party in easydo.

| Type | Capability |
| --- | --- |
| Contact | Receive and sign/fill only; auto-created when a document is sent. |
| Employee | Has own portal, mostly read access; cannot send. |
| Manager | Admin; can send documents and manage other profiles. |

```http
GET https://api.easydo.co.il/api/entity/me/profiles
Authorization: Bearer <token>
```

### Verification (2026-06-17)

Returned **200** with a paginated envelope:

```json
{ "draw": 0, "recordsTotal": 1, "recordsFiltered": 1, "recordsReturned": 1,
  "recordsOffset": 0, "data": [ { "id": 895602, "full_name": "אלכסנדר",
  "email": "ayurpolsky@microsoft.com", "type_name": "Company Admin",
  "type_slug": "company-admin", "type_group": "internal",
  "entity": { "id": 35866, "name": "חברה לדוגמה" } } ] }
```

> **Connector note:** the list is wrapped in a DataTables-style envelope
> (`draw`, `recordsTotal`, `data[]`), so the connector schema must read the array
> from `data`, and paging uses `recordsOffset` / length parameters.

### Create an employee profile (reference, not used in MVP)

```http
POST https://api.easydo.co.il/api/entity/me/employee
{ "first_name": "test recipient", "email": "test@test.com" }
```

Optional fields: `last_name`, `phone`, `id_number`, `birth_date` (dd.mm.yyyy),
`city`, `gender` (`male`/`female`), `marital_status`
(`single`/`married`/`divorced`/`widower`/`seperated`), `direct_manager_id`,
`indirect_manager_id`, `payroll_id`, `department_id`, `require_101`,
`language` (`he`/`en`/`ar`/`ru`).

## 4. Sending a document (one-time / random form)

Sending is a **four-step sequence**. Each step needs the form `id` returned by
step 1.

### Step 1 — Create the form

```http
POST https://api.easydo.co.il/api/entity/me/forms
{ "name": "New Random Form", "draft": true }
```

- `name` — shown to the recipient.
- `draft` — boolean (default `false`). When `true`, the form is available as a
  **draft** before it is sent → this is the mechanism used for **preview before
  send**.

Returns the new form `id`.

### Step 2 — Set assignees (recipients)

```http
POST https://api.easydo.co.il/api/entity/me/forms/{formId}/assignees
{
  "assignees": [
    { "profile": { "id": 35599 }, "sequence": 1,
      "notify_platform": "email", "recipient": true }
  ]
}
```

- `profile.id` — an existing profile (from `/profiles`).
- For an ad-hoc recipient without a profile, use
  `{ "email": "...", "name": "...", "sequence": 1, "recipient": true }`.
- `sequence` — signing order. If **all** assignees are `1` → parallel (a fill URL is
  generated per recipient). Otherwise → queue: only the `sequence:1` recipient gets a
  fill URL first; the next is generated after the previous one fills.
- `notify_platform` — `email`, `sms`, or `null` (no notification).
- **Only one assignee may have `recipient: true`** (the main recipient the document
  is associated with).

### Step 3 — Upload the PDF

```http
POST https://api.easydo.co.il/api/entity/me/forms/{formId}/upload
{ "file": { "name": "file.pdf", "data": "<base64>", "mime": "..." } }
```

- **PDF only.** `data` is Base64-encoded. `mime` instructs the API to use the PDF
  interpreter. (Through API builders use `files[0]`, `files[1]`, … for the file
  field.)

### Step 4 — Send

```http
PUT https://api.easydo.co.il/api/entity/me/forms/{formId}/send
{
  "settings": { "notify_emails": [ { "email": "you@co.il", "name": "Notify me" } ] },
  "meta_data": { "client": { "custom": "data", "key": "value" } }
}
```

- `settings.notify_emails` — addresses notified when the form is complete.
- **`meta_data.client`** — arbitrary key/value bag.
  **Used by this project to store the Dynamics 365 record id + table name** so the
  signed document can be correlated back to the originating Contact.

Response contains the form and, per assignee, a **`fill_url`** plus a `status`.
Each assignee has its own `fill_url`; only an assignee in `waiting` status can fill.

```json
{ "id": 10052, "status": "waiting",
  "assignees": [ { "id": 10343, "sequence": 1, "status": "waiting",
                   "fill_url": "https://stage.easydoc.co.il/formfill/..." } ] }
```

## 5. Templates

- Templates are created on the easydo website with their fields and default
  recipients pre-placed, then applied via the API — fields and recipients are sent
  exactly as configured.
- Templates can also be applied to changing/random files (fields land in the same
  positions).
- To send multiple template files together, use **Envelopes**.

The "Getting Started — Company" guide additionally documents: Block-Table Fields,
Sending Approved Templates, Upload form file, Update form, the 101 Form, and
Downloading Document Attachments.

## 6. Document status & PDF retrieval

Document statuses: `waiting`, `in progress`, `declined`, `signed`, `approved`.

- A **complete** PDF is generated only once status is `signed` or `approved`.
- For `waiting` / `in progress` / `declined`, only the **draft** PDF is available
  (the draft contains the PDF and limited field info, not the full data).
- Downloading a PDF requires the **document ID** (returned at send time and stored
  in Dataverse). The docs include a "Locating Document ID" guide.

This confirms **polling is viable**: a scheduled flow re-reads the document status
and, when it reaches `signed`/`approved`, downloads the complete PDF.

## 7. Envelopes

- A bundle of template documents sent together; the sender is notified once **all**
  documents in the envelope are filled/signed.
- Requires the feature to be enabled for the entity (it **is** enabled here:
  `Template-Envelopes` = true) and at least one document template.
- A "Download an Envelope" endpoint exists. *Not used in MVP* (single Contact, single
  template).

## 8. Webhooks (callback alternative to polling)

Configured in the web app: Settings → API Settings → **Webhooks** → *Add Webhook*.

| Setting | Notes |
| --- | --- |
| Name | Human-readable only. |
| Event | e.g. **Form Submitted** — fires once all recipients have signed/filled. |
| Method | Usually `POST`. |
| URL | Endpoint that receives the webhook payload. |

`API-Webhooks` is enabled for this entity. Webhooks are a **fast-follow** option;
the MVP uses scheduled polling and does not require a public HTTPS endpoint.

## 9. Common errors

| Message | Meaning |
| --- | --- |
| `Operation is not allowed` | A POST that needs a prior step, or a bad/non-existent id. |
| `Unauthenticated` | Token expired or incorrect — regenerate. |
| `You have exceeded package limit` | Monthly document cap for the entity reached. |
| `Record not found or not accessible` | Wrong entity/URL. |
| `Assignees can only have 1 sum of recipient` | More than one assignee had `recipient: true`. |

## 10. Implications for the integration

1. **No `/auth/token` needed for development** — a pre-issued 1-year Bearer token
   works directly. Production should call `/auth/token` with a stored `Client ID` +
   `Secret`, or rotate the long-lived token.
2. The Custom Connector must cover: `Get Entity (me)`, `Get Profiles`, `Create Form`,
   `Set Assignees`, `Upload File`, `Send Form`, `Get Status`, `Get PDF (draft &
   complete)`, and (later) Cancel / Envelope operations.
3. Use **`meta_data.client`** to carry the Dynamics 365 Contact id + table for
   correlation on status return.
4. **Preview before send** = create the form with `draft: true`, fetch the draft
   PDF, show it in the Custom Page, then `PUT …/send` only after user confirmation.
5. Profile lists use a **paginated DataTables envelope** — read `data[]`.
6. Handle the documented error messages explicitly in flows (esp. package limit and
   unauthenticated → token refresh).

## 12. Field prefill & lock (verified live 2026-06-18)

> זהו הממצא המרכזי של שלב זה: כיצד למלא מראש ערכים משדות D365 לתוך טופס easydo,
> ובאופן אופציונלי לנעול אותם כך שהנמען לא יוכל לערוך. המנגנון אומת מקצה-לקצה מול
> ה-API החי: הערכים (שם הלקוח, ת"ז) הוצגו בטופס, ועם `read_only:true` השדה הפך לאין
> ניתן לעריכה (disabled). תבנית: 68729 “הכר את הלקוח”.

### The send endpoint that carries prefill

A template is sent (and prefilled in the same call) via:

```http
POST https://api.easydo.co.il/api/entity/me/templates/{templateId}/send
Authorization: Bearer <token>
{
  "assignees": [
    { "name": "דנה לוי", "email": "dana@example.co.il", "sequence": 1, "recipient": true }
  ],
  "prefill_data": [
    { "name": "custom_field",               "content_value": "דנה לוי",  "read_only": true  },
    { "name": "custom_field_6a32cedc7ede2", "content_value": "302154879", "read_only": true  },
    { "name": "custom_field_6a32cf0ea456f", "content_value": "checked",   "read_only": false }
  ]
}
```

### `prefill_data` item shape

| Property | Type | Meaning |
| --- | --- | --- |
| `name` | string | The field's **technical `name`** (e.g. `custom_field`, `custom_field_6a32cedc7ede2`). **Not** `export.header` and **not** the GUID `id`. Matches `alex_templatefieldmapping.alex_externalfieldid`. |
| `content_value` | string | The value to place in the field. For a **checkbox** use `"checked"` / `"unchecked"`. |
| `read_only` | boolean | When `true`, the field is rendered **disabled** — the recipient sees the value but cannot change it. |

### How it was verified (renderer logic)

- The web app's quick-send (`sendQuickSend()`) posts `{ recipient_id, assignees,
  prefill_data }` to the template `…/send` endpoint.
- The form renderer matches a prefill item to a field by **`prefillItem.name ===
  field.name`** and displays `content_value`.
- The read-only decision is `isReadOnly = !!isSystem || (prefillItem.read_only ??
  field.isReadOnly)`.

> **CRITICAL:** the template-builder per-field lock (the “נעול” checkbox, which sets
> `field.isReadOnly = true`) is **not enforced on a sent form by itself** — a sent
> form still allowed typing. To actually lock a value you **must pass
> `read_only: true` in the `prefill_data` item** at send time.

### `prefill_enabled` template flag

`prefill_enabled` (UI: “מילוי מקדם לפני שליחה”) can be toggled via
`PUT /entity/me/templates/{id}` `{ "prefill_enabled": true }`. It governs the manual
sender prefill UI; `prefill_data` on `…/send` rendered even independently of it in
testing. Keep it `true` to be safe.

### Read-back (recipient-entered values)

`GET /entity/me/forms/{id}` returns a top-level **`data`** object keyed by
`export.header` (e.g. `{ "customer_name": "", "customer_id": "", "q1": "", … }`).
It is **empty until the recipient submits**, at which point `has_data` flips to
`true`. This object is **read-only / computed** (it cannot be written via `PUT`),
and is the source for copying filled values back into Dynamics.

The scheduled read-back flow iterates `payload.data[0]` (the field objects, which
carry `name`, `label`, `type` and `export.header`), skips the `input-signature`
field, and reads each value from the top-level `data[export.header]`. Checkbox
values come back as `"checked"` / `"unchecked"`; dates as a datetime string.

### Signed PDF download (verified live 2026-06-18)

`GET /entity/me/forms/{id}/download` returns the PDF (`200`, `application/pdf`,
`%PDF-…`, ~448 KB in testing). The **complete** PDF exists only once the form is
`signed` / `approved`; before that the endpoint returns
`400 record_not_accessible`. The connector's `DownloadDocument` operation declares
a binary response so the bytes can be `base64()`-encoded into a Dataverse
`annotation` (`documentbody`, `mimetype = application/pdf`, bound to the request via
`objectid_alex_signaturerequest@odata.bind`).

### Approaches that do NOT work (do not retry)

- Injecting `value` / `val` / `content` / `text` / `default` / `data` /
  `default_value` / `defaultValue` / `default_data` / `defaultData` onto the
  `payload.data[][]` field objects via `PUT /forms/{id}` — the values persist on the
  payload but the renderer **ignores** them.
- `PUT /forms/{id}` with `data` as a header-keyed object → **400 invalid_input**
  (the `data` body must be the `payload.data` array).
- The top-level header-keyed `data` is read-only/computed and cannot be set.
- No `…/forms/{id}/fill|values|prefill|submit|save` write endpoints exist
  (404 / 405).

## 11. Documentation page slugs

`easydoc.stoplight.io/docs/easydoc/<slug>`

| Topic | Slug |
| --- | --- |
| Getting Started (Company) | `hq8mzxlcclv2i-getting-started-company` |
| Authentication | `yzdi6nkwe0tre-authentication` |
| Profiles (intro) | `76alwp784gahw-introduction` |
| Employees | `9dqgbvs5ipn69-employees` |
| Documents (intro) | `0syumeo94x73c-introduction` |
| Templates (intro) | `bxrsp1lhilpn3-introduction` |
| Envelopes (intro) | `z9g0a01e22tix-introduction` |
| Sending a random document | `tosuhd0ib6fm8-sending-a-random-document` |
| Document Status & PDF Files | `h0evrnbxdubkg-document-status-and-pdf-files` |
| Document Logs | `nl7m34ta2i0cg-document-logs` |
| Download an Envelope | `5eclao3b4l95p-download-an-envelope` |
| Configuring a new Webhook | `goyeev28fu7sf-configuring-a-new-webhook` |
| Common Errors | `eilsqgrp0d7jw-common-errors` |
