# D365 easydo — Digital Signature Integration for Dynamics 365 | אינטגרציית חתימה דיגיטלית ל-Dynamics 365

Digital signature capability that lets a Dynamics 365 user send a document for
signature from any business record, track its status, and automatically write the
signed results back into the originating record — powered by the
[easydo](https://easydoc.stoplight.io/docs/easydoc) signing service and Microsoft
Power Platform.

> Status: **MVP** — see [docs/release-notes.md](docs/release-notes.md).

> הפרויקט מאפשר למשתמש עסקי לשלוח מסמך לחתימה דיגיטלית ישירות מתוך רשומת
> Dynamics 365, למלא מראש שדות מהרשומה, לעקוב אחר הסטטוס, ולקבל בחזרה את
> הערכים החתומים אל הרשומה — באופן אוטומטי. בנוי על Power Platform עם תמיכה
> מלאה בעברית (RTL) ובאנגלית (LTR).

---

## Goal

Make Dynamics 365 the central launch and tracking point for the signature process,
with a simple, secure-by-default and fully bilingual (Hebrew RTL / English LTR)
experience — built on native Power Platform capabilities (no Azure resources).

## What it does

| Area | Approach |
| --- | --- |
| Source record | **Any table** — the template declares its primary table; an optional single lookup hop reaches related records |
| Prefill | Values are resolved from the source record(s) and pushed to easydo before the recipient opens the form |
| Write-back | When the form is **Completed**, signed field values are written back to the originating Dynamics record automatically |
| Status tracking | **Polling** (scheduled flow) using easydo GET status/PDF endpoints |
| Preview before send | **Yes** — easydo draft document (`draft:true`) |
| Integration layer | Custom Connector + Power Automate + Dataverse plug-ins (no Azure Function) |
| Field mapping UI | **PCF control** on the signature-template model-driven form |
| Languages | Hebrew + English |

## High-level architecture

```text
Dynamics 365 record  ─►  Signature Request (Dataverse)
        │                       │
        │   PCF control on the Signature Template form maps
        │   Dynamics columns ⇄ easydo template fields
        ▼                       ▼
Power Automate (solution-aware flows)  ─►  Custom Connector  ─►  easydo API
        │   - Send flow calls the alex_ResolvePrefill                (api.easydo.co.il)
        │     Custom API to build prefill_data from the source record
        ▼
Dataverse plug-ins
   - ResolvePrefill (Custom API): resolves prefill values for the send flow
   - WriteBack (async on Update): on status = Completed, writes signed
     values back into the originating record (direct or via one lookup hop)
```

## Repository structure

```text
/docs          Business, architecture, data, security, deployment & ops documentation
/src           Custom connector, flows, PCF control, plug-ins, setup scripts
/deployment    Environment variables, connection references, PAC CLI, import order
/tests         UAT scenarios and test matrix
```

See [docs/](docs/) for detailed documentation, including
[docs/prerequisites.md](docs/prerequisites.md) (what you need before installing — easydo
account, API access, trial & contact),
[docs/data-model.md](docs/data-model.md) (tables, ERD, data flow),
[docs/custom-connector.md](docs/custom-connector.md) (easydo connector actions),
[docs/technical-architecture.md](docs/technical-architecture.md) (components and
flow) and [docs/business-user-guide.md](docs/business-user-guide.md) (a plain-language
guide to every connector action).

## Solution

| Item | Value |
| --- | --- |
| Publisher prefix | `alex` |
| Solution (display) | `D365 easydo` |
| Solution (logical) | `alex_d365_easydo` |
| Lifecycle | Unmanaged in Dev → exported Managed for Test/Prod |

## Security

- **No secrets, tokens, client secrets, signed PDFs or customer payloads are ever
  committed to this repository.** See [.gitignore](.gitignore) and
  [docs/security-model.md](docs/security-model.md).
- Credentials are held only in Power Platform Environment Variables / Connection
  References.
- The easydo API token is rotated before any production use.
