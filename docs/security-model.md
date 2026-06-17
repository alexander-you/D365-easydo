# Security Model

> **תקציר בעברית:** אבטחה כברירת מחדל — אין לשמור סודות, טוקנים או מסמכים חתומים
> ב-Git. הטוקן נשמר רק ב-Environment Variables / Connection References. הגישה למסמכים
> חתומים מוגבלת לפי הרשאות הרשומה ב-Dynamics 365, ומוגדרים תפקידי אבטחה ייעודיים.

Security by design is a core principle of this solution.

## Secrets handling

- **Never** commit passwords, tokens, client secrets, signed PDFs or full payloads.
  Enforced by [.gitignore](../.gitignore).
- The EasyDoc Bearer token / Client Secret are stored **only** in Power Platform
  **Environment Variables** and accessed through **Connection References** owned by a
  dedicated service account.
- ⚠️ The development token shared during early setup was exposed in a chat session and
  **must be regenerated before production use**.
- Enable **Secure Inputs / Secure Outputs** on sensitive Power Automate actions so
  tokens and payloads do not appear in run history.

## Access control

- Dedicated **Security Roles**: Signature User, Signature Manager, Signature Admin,
  Signature Auditor, Signature Support.
- Access to a signed document is tied to the user's access to the **source record**:
  a user who cannot see the Contact cannot open its signed document.

## Logging & audit

- `Integration Log` stores only a **safe payload summary** — never full sensitive
  payloads.
- Audit: who created a request, when it was sent, to whom, which template, which
  fields, status changes, document return, and document access where possible.

## Platform governance

- Review **DLP policies** for the Custom Connector, Power Automate, Dataverse and
  any HTTP triggers.
- Use Connection References with **least-privilege** and stable ownership; separate
  Dev / Test / Prod.
- Key Vault is only introduced if/when an Azure Function is added later.
