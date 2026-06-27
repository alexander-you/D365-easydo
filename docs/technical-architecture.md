# Technical Architecture | ארכיטקטורה טכנית

## Overview

The solution keeps Dynamics 365 as the launch and tracking point and uses native
Power Platform components to integrate with the easydo signing service. No Azure
Function is used in the MVP; the architecture is designed so the integration layer
can later be swapped for an Azure Function without changing the data model or UX.

> הארכיטקטורה משאירה את Dynamics 365 כנקודת ההפעלה והמעקב
> המרכזית. הזרימה: כפתור ב-Command Bar בטופס Contact → Custom Page מונחה → Power
> Automate → Custom Connector → easydo API, כאשר Dataverse מאחסן את כל הנתונים.
> אין Azure Function ב-MVP, אך התכנון מאפשר החלפת שכבת האינטגרציה בעתיד ללא שינוי
> מודל הנתונים או חוויית המשתמש.

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Dynamics 365 — Contact form                                         │
│   • Command Bar button: "Send for Signature" (Modern Commanding)    │
│   • Subgrid / related tab: Signature Requests                       │
└───────────────┬─────────────────────────────────────────────────────┘
                │ opens
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Custom Page (guided)                                                │
│   Select Template → Review/Preview → Fill Fields → Recipients → Send │
└───────────────┬─────────────────────────────────────────────────────┘
                │ triggers
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Power Automate (solution-aware flows)                               │
│   Send Request · Create Draft+Preview · Refresh Status (polling)     │
│   Retrieve Signed Doc · Retry · Cancel · Notify Owner                │
└───────────────┬─────────────────────────────────────────────────────┘
                │ via
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Custom Connector (easydo)                                          │
│   Auth · Get Profiles · Create Form · Set Assignees · Upload ·       │
│   Send · Get Status · Get PDF (draft/complete) · Cancel              │
└───────────────┬─────────────────────────────────────────────────────┘
                │ HTTPS (Bearer token from Env Var / Connection)
                ▼
        easydo API — https://api.easydo.co.il/api

Dataverse stores: Signature Request · Signature Template · Template Field Mapping ·
Signature Recipient · Signature Document · Integration Log
```

## Components

| Component | Role | MVP |
| --- | --- | --- |
| Dataverse tables | Templates, mappings, requests, recipients, documents, logs | ✅ |
| Custom Connector | Typed easydo operations (no raw HTTP actions) | ✅ |
| Power Automate | Orchestration, status polling, document return | ✅ |
| Command Bar button | "Send for Signature" on the Contact form | ✅ |
| Custom Page | Guided send experience | ✅ |
| Environment Variables | Base URL, sandbox/prod, polling interval, storage mode, feature flags | ✅ |
| Connection References | Managed connections owned by a service account | ✅ |
| PCF control | Rich PDF preview / field overlay | ⛔ (only if preview demands) |
| Azure Function | Secure callback, token cache, large files, high volume | ⛔ (future) |

## Key flows

### Send for Signature

1. User selects a template and confirms recipient (Contact) on the Custom Page.
2. Flow creates the easydo form (`draft:true`), applies the template/fields, sets
   the Contact as the single assignee (`recipient:true`), and uploads the PDF.
3. Flow fetches the **draft PDF** and shows it for **preview**.
4. On confirmation, flow `PUT …/send` with `meta_data.client` carrying the Contact id
   + table name.
5. A `Signature Request` row is created/updated in Dataverse with the easydo form id
   and `fill_url`.

### Status polling & document return

1. A scheduled flow (every 5 min) reads open `Signature Request` rows
   (`alex_status` in Sent/Delivered/Viewed/InProgress, `alex_externalformid` set,
   not in a live real-time session) and calls easydo *Get Status*
   (`GET /entity/me/forms/{formId}`).
2. The easydo form `status` + assignee `log` are mapped to the Dataverse status
   choice, covering the full lifecycle:
   - `decline` → **Declined** (`626210007`), and the assignee `decline_reason`
     is captured into **`alex_declinereason`**.
   - `expired` → **Expired** (`626210010`).
   - `canceled` / `deleted_at` set → **Cancelled** (`626210009`).
   - `signed` / `has_data` → **Completed** (`626210006`).
   - a `view` log event (no submission yet) → **Viewed** (`626210004`).
   - otherwise the existing status is preserved.
   > easydo exposes no reliable *delivered* signal (log actions observed:
   > `attachment, decline, fill, view` only), so **Delivered** is not auto-set.
3. On completion (`signed` / `has_data`), the flow downloads the complete PDF and
   stores it in a **Dataverse File** column on `Signature Document`, then surfaces
   it on the Contact (and the side panel shows the decline reason for declined
   requests).

## Dynamic send-table enablement

Any business table can be made "sendable" at runtime from the admin center
(`adminCenter.html` → **Send tables management**). Enabling a table calls the unbound
Custom API **`alex_EnsureSignatureLookup`** (`EnsureSignatureLookupPlugin`), which
idempotently provisions a native **N:1 relationship** `alex_<table>_signaturerequest`
(lookup `alex_related<table>id`) from `alex_signaturerequest` to that table.
`PopulateAnchorPlugin` later fills the matching lookup alongside the generic anchor.

**Target-solution resolution.** A new metadata component must land in a **writable
(unmanaged)** solution. The plug-in therefore inspects the base solution
`alex_d365_easydo`:

| Base solution state | Where the relationship is added | `Warning` |
| --- | --- | --- |
| Unmanaged (Dev) | `alex_d365_easydo` directly | — |
| Managed (Test/Prod/customer) | dedicated unmanaged `alex_d365_easydo_runtime`, created on demand under the same publisher | advisory text returned |
| Solution not found | Default solution | advisory text returned |

The API returns `RelationshipSchemaName`, `LookupLogicalName`, `Created`,
**`TargetSolution`** and **`Warning`**; the admin center shows the warning as a toast
and persists it to `alex_statusmessage`. The plug-in deliberately **does not catch and
continue** past an `OrganizationService` failure — doing so aborts the platform
transaction and silently rolls the relationship back.

> **בעברית.** הפעלת טבלה לשליחה (מסך "ניהול טבלאות שליחה") קוראת ל‑Custom API
> `alex_EnsureSignatureLookup`, שמייצר קשר N:1 מ‑`alex_signaturerequest` לטבלה. מאחר
> שאי אפשר לכתוב מטא‑דאטה ל‑solution מנוהל, הפלאגין בוחר יעד **לא‑מנוהל**: בפיתוח —
> `alex_d365_easydo` עצמו; אצל לקוח (בסיס מנוהל) — solution לא‑מנוהל ייעודי
> `alex_d365_easydo_runtime` שנוצר לפי הצורך, עם **אזהרה** למשתמש. הפלאגין אינו בולע
> חריגות, כדי לא לגלגל את הטרנזקציה לאחור.

## Correlation strategy

The easydo `meta_data.client` bag stores `{ "d365_table": "contact",
"d365_id": "<guid>", "signature_request_id": "<guid>" }`, allowing both polling and a
future webhook to map an easydo form back to the originating Dynamics 365 record.

## Future evolution

- Replace polling with the easydo **webhook** (`Form Submitted`) once a secure
  HTTPS receiver exists (Power Automate HTTP trigger or Azure Function).
- Introduce an Azure Function + Key Vault if secure callbacks, token caching, large
  files or high volumes are required.
- Extend from Contact to additional tables and to multi-signer scenarios.
