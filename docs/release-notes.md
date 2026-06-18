# Release Notes | יומן גרסאות

> יומן גרסאות ושלבי התקדמות הפרויקט.

All notable changes to this project are documented here.

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
  and passes it to EasyDoc.
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

### Pending

- Read-back flow (poll/webhook) writing `Read Back` rows from the form `data`.
- Re-import the connector + flows and activate.

## [Unreleased] — initial setup (2026-06-17)

### Added

- Repository structure and initial documentation baseline.
- `docs/api-research.md` — EasyDoc API research, **verified live against production**
  (`/entity/me` and `/entity/me/profiles` returned 200; entity `35866`).
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
