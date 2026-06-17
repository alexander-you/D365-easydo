# Business Requirements

The authoritative business & technical requirements are maintained (in Hebrew) in
[requirements-he.md](requirements-he.md) — the original brief provided by the
business owner.

## Summary (English)

Build a complete, convenient and dynamic digital-signature capability **from inside
Dynamics 365**, so a business user can send a document for signature from an
existing CRM record, track the signing status, and receive the signed document back
into the correct business context.

### Guiding principles

1. **Simplicity** — prefer native Power Platform building blocks over custom Azure
   code. Azure Functions are not required for the MVP.
2. **Security by design** — no passwords, tokens, client secrets, sensitive PDFs or
   full payloads stored in the clear; Connection References, Environment Variables,
   role-based access, secure inputs/outputs, full audit.
3. **Dynamic, not hard-coded** — an administrator configures the enabled tables,
   templates, field mappings, recipients and storage location through configuration,
   not code.
4. **Natural UX from Dynamics 365** — business-friendly language (no `TemplateId`,
   `Payload`, `JSON`); a guided flow: choose template → review → fill → recipients →
   send → track → open signed document.
5. **Full bilingual support** — Hebrew (true RTL) and English across buttons, forms,
   messages, statuses, previews and documentation.

### Primary user scenario

From a **Contact** record the user clicks **Send for Signature**, a guided page
opens (select template → review/preview → fill dynamic fields → choose recipient →
send), then returns to the record to track status and, once complete, open the
signed document.

### Success criteria

- Send for signature from Dynamics 365 without leaving for an external system.
- Data is pulled automatically from the record.
- Clear status visibility; the signed document returns to the correct record.
- Works in Hebrew and English; no secrets exposed; deployable environment-to-
  environment; maintainable through configuration, not code.

See [requirements-he.md](requirements-he.md) for the full detail (data model,
UX requirements, security model, ALM, MVP scope and research questions).
