# D365 easydo — Digital Signature Integration for Dynamics 365

Business-driven digital signature capability that lets a Dynamics 365 user send a
document for signature from a CRM record, track its status, and receive the signed
document back into the correct business context — powered by the
[EasyDoc](https://easydoc.stoplight.io/docs/easydoc) signing service and Microsoft
Power Platform.

> Status: **MVP in development** — see [docs/release-notes.md](docs/release-notes.md).

> **תקציר בעברית:** הפרויקט מאפשר למשתמש עסקי לשלוח מסמך לחתימה דיגיטלית ישירות
> מתוך רשומת Dynamics 365, לעקוב אחר הסטטוס, ולקבל בחזרה את המסמך החתום לרשומה.
> ה-MVP מתמקד ברשומת **Contact**, אחסון ב-**Dataverse File**, מעקב ב-**Polling**,
> ותצוגה מקדימה לפני שליחה — בנוי על Power Platform עם תמיכה מלאה בעברית ובאנגלית.

---

## Goal

Turn Dynamics 365 into the central launch and tracking point for the signature
process, with a simple, guided, secure-by-default and fully bilingual (Hebrew RTL /
English LTR) experience — built primarily on native Power Platform capabilities.

## MVP scope

| Area | Decision |
| --- | --- |
| Source record | **Contact** |
| Signed document storage | **Dataverse File** column |
| Status tracking | **Polling** (scheduled flow) — verified supported by EasyDoc GET status/PDF endpoints |
| Preview before send | **Yes** — EasyDoc draft document (`draft:true`) |
| Integration layer | Custom Connector + Power Automate (no Azure Function for MVP) |
| Signer model | Single signer |
| Languages | Hebrew + English |

Out of MVP scope: in-D365 template editor, drag & drop field placement, advanced
multi-signer, Azure Function / API Management / Blob storage, complex PCF (unless
preview demands it), legal-evidence flows.

## High-level architecture

```text
Dynamics 365 (Contact form)
   │  Command Bar: "Send for Signature"
   ▼
Custom Page (guided steps: Template → Preview → Fill → Recipients → Send)
   │
   ▼
Power Automate (solution-aware flows)  ──►  Custom Connector  ──►  EasyDoc API
   │                                                                  (api.easydo.co.il)
   ▼
Dataverse (Signature Request / Template / Field Mapping / Recipient / Document / Log)
   │
   ▼
Polling flow updates status → on signed/approved → store signed PDF in Dataverse File
```

## Repository structure

```text
/docs          Business, architecture, data, security, deployment & ops documentation
/src           Power Platform solution, custom connector, PCF, custom pages, scripts
/deployment    Environment variables, connection references, PAC CLI, import order
/tests         UAT scenarios and test matrix
```

See [docs/](docs/) for detailed documentation.

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
- The EasyDoc API token used during early development was shared in a chat session
  and **must be regenerated before any production use**.
