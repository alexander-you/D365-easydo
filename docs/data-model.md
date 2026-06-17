# Data Model (baseline)

> **תקציר בעברית:** מסמך זה הוא בסיס ראשוני למודל הנתונים ב-Dataverse. הוא מתאר את
> הטבלאות המרכזיות והשדות העיקריים לפי דרישות הלקוח. מודל מפורט יותר כולל דיאגרמת
> קשרים בין טבלאות (ERD) ותפיסת פתרון מלאה יתווסף בשלב הבא.

This is the initial baseline data model. A deeper version — including an entity
relationship diagram (ERD) and full solution-concept — is planned for the **next
phase** (per project direction 2026-06-17).

All tables use the publisher prefix **`alex_`** in the `Demo Contact Center EN`
environment.

## Tables

### `alex_signaturerequest` — Signature Request

Central table for a signature request.

| Field | Type | Notes |
| --- | --- | --- |
| Name | Text | Primary name |
| Related Record | Lookup/Text | Source record id (MVP: Contact) |
| Related Table Name | Text | Source table logical name (MVP: `contact`) |
| Template | Lookup → Signature Template | |
| Status | Choice | Draft, Ready to Send, Sent, Delivered, Viewed, In Progress, Completed, Failed, Cancelled, Expired, Deleted, Pending Retry |
| External Form Id | Text | EasyDoc form id |
| External Document Id | Text | EasyDoc document id |
| Sent On / Completed On / Cancelled On | DateTime | |
| Last Status Check On | DateTime | Polling timestamp |
| Error Code / Error Message | Text | |
| Retry Count | Number | |
| Language | Choice | he / en |
| Is Draft | Yes/No | |
| Is Preview Generated | Yes/No | |

### `alex_signaturetemplate` — Signature Template

| Field | Type | Notes |
| --- | --- | --- |
| Template Name | Text | |
| External Template Id | Text | EasyDoc template id |
| Related Dynamics Table | Text | |
| Template Type | Choice | |
| Language | Choice | |
| Active | Yes/No | |
| Supports Single/Multiple Signers | Yes/No | |
| Supports Preview | Yes/No | |
| Default Delivery Method | Choice | email / sms / none |
| Last Synced On | DateTime | |

### `alex_templatefieldmapping` — Template Field Mapping

Maps EasyDoc document fields to Dynamics 365 fields (configuration, not code).

| Field | Type | Notes |
| --- | --- | --- |
| Template | Lookup → Signature Template | |
| External Field Id / Name / Type | Text | |
| Dynamics Table / Dynamics Field | Text | |
| Default Value | Text | |
| Required | Yes/No | |
| Editable Before Send | Yes/No | |
| Visible to User | Yes/No | |
| Sender Prefill | Yes/No | |

### `alex_signaturerecipient` — Signature Recipient

| Field | Type | Notes |
| --- | --- | --- |
| Signature Request | Lookup → Signature Request | |
| Recipient Type | Choice | |
| Contact | Lookup → Contact | **MVP primary link** |
| External Name / Email / Phone | Text | For ad-hoc recipients |
| Signing Order | Number | |
| External Profile Id | Text | EasyDoc profile id |
| Status | Choice | |
| Sent On / Viewed On / Signed On | DateTime | |
| Preferred Language | Choice | |

### `alex_signaturedocument` — Signature Document

| Field | Type | Notes |
| --- | --- | --- |
| Signature Request | Lookup → Signature Request | |
| Document Type | Choice | Draft / Signed / Evidence |
| File Name | Text | |
| Mime Type | Text | |
| **Signed File** | **File column** | **MVP storage = Dataverse File** |
| External File Id | Text | |
| Retrieved On | DateTime | |
| Is Signed / Is Original | Yes/No | |

### `alex_integrationlog` — Integration Log

| Field | Type | Notes |
| --- | --- | --- |
| Signature Request | Lookup → Signature Request | |
| Event Type / Operation Name | Text | |
| Direction | Choice | Inbound / Outbound |
| Status | Choice | |
| Started On / Completed On | DateTime | |
| Correlation Id | Text | matches `meta_data.client` |
| Error Code / Error Message | Text | |
| Safe Payload Summary | Text | **No sensitive full payloads** |

## Relationships (baseline)

```text
Signature Template 1 ──< Template Field Mapping
Signature Template 1 ──< Signature Request
Signature Request  1 ──< Signature Recipient >── Contact
Signature Request  1 ──< Signature Document
Signature Request  1 ──< Integration Log
```

A full ERD will be added in the next phase.
