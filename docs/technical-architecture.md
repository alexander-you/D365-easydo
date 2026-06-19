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

1. A scheduled flow reads open `Signature Request` rows and calls easydo *Get
   Status*.
2. Status is mapped to the Dataverse status choice.
3. On `signed` / `approved`, the flow downloads the complete PDF and stores it in a
   **Dataverse File** column on `Signature Document`, then surfaces it on the Contact.

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
