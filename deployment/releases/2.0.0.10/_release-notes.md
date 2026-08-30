## 2.0.0.10 — Recipient signing-interface language (Hebrew / English / Russian / Arabic)

### Why a new release
easydo added support for setting the **signing-interface language per recipient**. This
release wires that capability through the whole solution so senders can choose the
language a recipient sees while signing. **Bump your installed solution to `2.0.0.10`**
to upgrade — existing environments upgrade in place (no data migration required).

### What's new
- **`alex_language` choice extended 2 → 4 options** — Hebrew (`626210000`), English
  (`626210001`), **Russian** (`626210002`), **Arabic** (`626210003`). Managed upgrade
  adds the two new options automatically.
- **Send wizard** — new *Signing language* selector on the Settings step (shown for both
  standard and Contact Center sends, echoed on the Review step). One language applies to
  all recipients of the send.
- **Recipient record** — the choice is written to each recipient's `alex_preferredlanguage`
  by `WizardIntakePlugin`.
- **Send Signature Request flow** — passes the per-assignee `language` to easydo, falling
  back to the request language and then Hebrew.
- **Custom connector** — declares the `language` enum (`he`/`en`/`ru`/`ar`) on every
  assignee/recipient schema (SendTemplate, SetAssignees, SendEnvelope recipient and
  templates).
- **SharePoint "send file for signature" flow** — accepts an optional `RecipientLanguage`
  input.

### Upgrade
1. Import **`alex_d365_easydo_2_0_0_10_managed.zip`** into your test/production
   environment (Solutions → Import → *Upgrade*).
2. Keep the two existing connections (`alex_easydo`, `alex_dataverse_easydo`).
3. Publish all customizations. No configuration change is required — the default signing
   language remains Hebrew.

Use `alex_d365_easydo_2_0_0_10.zip` (unmanaged) only for development/source environments.
