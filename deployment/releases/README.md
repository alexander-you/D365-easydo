# Solution Releases | חבילות Solution

Exported managed **and** unmanaged solution packages for `alex_d365_easydo`.
Each version folder contains both artifacts, produced by
[src/scripts/40-export-release.ps1](../../src/scripts/40-export-release.ps1).

| File suffix | Type | When to use |
| --- | --- | --- |
| `_<ver>.zip` | **Unmanaged** | Dev/source environments where you continue to customize |
| `_<ver>_managed.zip` | **Managed** | Test / production / customer environments (locked, upgradable) |

## Versions

| Version | Date | Highlights |
| --- | --- | --- |
| [2.0.0.9](2.0.0.9/) | 2026-08-19 | **Feature** — cancelling a signature request in Dataverse (`alex_status` = Cancelled) now calls easydo `CancelForm` via a new flow, closing the form so the recipient can no longer sign; stamps `alex_cancelledon`, no status write-back (no re-trigger), idempotent for already-cancelled forms. Supersedes the unpublished 2.0.0.7/2.0.0.8 |
| [2.0.0.6](2.0.0.6/) | 2026-08-12 | **Feature** — per-channel governance for "send a signed copy to the customer" (Email/SMS/WhatsApp) via new global settings, managed from the Admin Center; buttons shown only when allowed and the recipient has a usable target |
| [2.0.0.5](2.0.0.5/) | 2026-08-12 | **Fix** — prefill/write-back anchor now falls back to the dedicated per-table "signature source" lookup, so requests created outside the send wizard (integrations/flows) prefill correctly; fully generic, no per-table hard-coding |
| [2.0.0.4](2.0.0.4/) | 2026-08-11 | **Fix** — `concurrency=1` on all three scheduled flows (auto-sync, read-results, expire-overdue) to stop runaway concurrent runs; manual Sync Templates label fix. Supersedes 2.0.0.3 |
| [2.0.0.3](2.0.0.3/) | 2026-08-11 | Superseded by 2.0.0.4 (trigger-concurrency deploy landed incomplete) |
| [2.0.0.2](2.0.0.2/) | 2026-08-10 | **Fix** — signature-lookup provisioning no longer fails ("שגיאת קשר") on managed installs; falls back to the Default solution when the publisher is read-only |
| [2.0.0.1](2.0.0.1/) | 2026-08-10 | **Release repair** — packages the Template Gallery PCF and removes an EN-only Tenant Contract relationship from EasyDo |
| [2.0.0.0](2.0.0.0/) | 2026-08-01 | **Major** — multi-document **envelopes** (2 new tables, 7 connector ops, Envelope Composition PCF), recipient **authentication** (PIN/OTP), **Template Gallery** PCF, on-demand **status check** flow, envelope real-time signing, copy-link governance, read-only forms |
| [1.3.0.0](1.3.0.0/) | 2026-07-30 | Document validity / expiry — per-template settings, send-time compute, per-send override, and daily auto-cancel of overdue requests |
| [1.2.0.0](1.2.0.0/) | 2026-07-30 | Multi-page read-back — signed values written back from **all** PDF pages, not just page 0 |

> **Keep this table in sync.** Every folder under `deployment/releases/` **must** have a
> row here and a matching git tag `v<version>` — otherwise the release is invisible to
> anyone browsing the repo. When you run `40-export-release.ps1`, add the row and the tag.

## Import order & connections

1. Import the **managed** zip into the target environment (Solutions → Import).
2. During import, establish the two **connections** when prompted:
   - `alex_easydo` — easydo custom connector (API key).
   - `alex_dataverse_easydo` — Dataverse.
3. After import, confirm the flows are **On** in the easydo Admin Center → "התקנה
   ותקינות" (required flows gate readiness; the optional copy flows do not).

> **הנחיות פריסה:** כל תיקיית גרסה מכילה חבילת **Managed** וחבילת **Unmanaged**. יש לייבא את
> חבילת ה‑Managed לסביבות בדיקה וייצור, ואת חבילת ה‑Unmanaged לסביבת הפיתוח. במהלך
> הייבוא יש להגדיר את שני החיבורים (`alex_easydo`, `alex_dataverse_easydo`) ולוודא
> שתהליכי ה‑Flow פעילים דרך מרכז הניהול.

> **PCF controls.** From **2.0.0.0** the package also carries three code components —
> Template Field Mapping, Template Gallery and Envelope Composition — plus the Documents
> grid. They are included in the exported solution; no separate `pac pcf push` is needed
> on the target.

## Regenerating

```powershell
pwsh -NoProfile -File src/scripts/40-export-release.ps1 -Version <x.y.z.0>
```

The script bumps the live solution version, publishes, then exports both zips into
`deployment/releases/<version>/`. **After exporting**, always:

1. Add a row to the **Versions** table above.
2. Add a `## [<version>]` entry to [docs/release-notes.md](../../docs/release-notes.md).
3. Commit and create the matching git tag `v<version>` (and push it) — a folder with no
   tag/row is effectively invisible.
