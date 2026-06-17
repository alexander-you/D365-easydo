# Release Notes

> **תקציר בעברית:** יומן גרסאות ושלבי התקדמות הפרויקט.

All notable changes to this project are documented here.

## [Unreleased] — initial setup (2026-06-17)

### Added

- Repository structure and initial documentation baseline.
- `docs/api-research.md` — EasyDoc API research, **verified live against production**
  (`/entity/me` and `/entity/me/profiles` returned 200; entity `35866`).
- `docs/business-requirements.md` + `docs/requirements-he.md` (original brief).
- `docs/technical-architecture.md`, `docs/data-model.md` (baseline),
  `docs/security-model.md`, `docs/deployment-guide.md`.
- `.gitignore` blocking secrets, tokens, signed PDFs and payloads.

### Verified

- EasyDoc API connectivity using a pre-issued 1-year Bearer token (production).
- Entity features relevant to the integration are enabled (Document-Send,
  Template-Forms, API-Webhooks, Multi-Recipient, Public-Link, Smart-Documents).

### Decisions

- MVP source record: **Contact**.
- Signed document storage: **Dataverse File**.
- Status tracking: **Polling** (webhook is a fast-follow).
- Preview before send: **EasyDoc draft** (`draft:true`).

### Next phase

- Deeper architecture / solution-concept / data-model / table-relationship (ERD)
  documentation.
- Create the unmanaged Dataverse solution `alex_d365_easydo` and tables.
- Build the EasyDoc Custom Connector.

### Security

- ⚠️ The development API token was shared in chat and **must be regenerated before
  production**.
