# Solution Releases | חבילות פתרון

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
| [1.2.0.0](1.2.0.0/) | 2026-07-30 | Multi-page read-back — signed values written back from **all** PDF pages, not just page 0 |

## Import order & connections

1. Import the **managed** zip into the target environment (Solutions → Import).
2. During import, establish the two **connections** when prompted:
   - `alex_easydo` — easydo custom connector (API key).
   - `alex_dataverse_easydo` — Dataverse.
3. After import, confirm the three flows are **On** (or use the easydo Admin Center → "בדיקת זרימות").

> **בעברית.** כל תיקיית גרסה מכילה חבילה **מנוהלת** ו**לא‑מנוהלת**. ייבא את המנוהלת
> לסביבות בדיקה/ייצור ואת הלא‑מנוהלת לסביבת פיתוח. בזמן הייבוא הקם את שני החיבורים
> (`alex_easydo`, `alex_dataverse_easydo`), ואז ודא שלוש הזרימות פעילות דרך מרכז הניהול.

## Regenerating

```powershell
pwsh -NoProfile -File src/scripts/40-export-release.ps1 -Version <x.y.z.0>
```

The script bumps the live solution version, publishes, then exports both zips into
`deployment/releases/<version>/`.
