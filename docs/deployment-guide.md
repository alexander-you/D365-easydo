# Deployment Guide

> **תקציר בעברית:** מדריך פריסה. הפתרון נבנה כ-solution לא מנוהל (unmanaged) בסביבת
> הפיתוח, ומיוצא כ-solution מנוהל (managed) לפריסה ל-Test/Production. הפריסה משתמשת
> ב-Environment Variables ו-Connection References, ומומלץ לבצעה דרך PAC CLI.

## Environments

| Stage | Environment |
| --- | --- |
| Development | `Demo Contact Center EN` — `https://demo-contact-center-en.crm4.dynamics.com/` |
| Test | TBD |
| Production | TBD |

## Solution

| Item | Value |
| --- | --- |
| Display name | `D365 easydo` |
| Logical name | `alex_d365_easydo` |
| Publisher | `Alexander Yurpolsky` (`alexander_yurpolsky`) |
| Prefix | `alex` |

## Lifecycle

1. Develop in the **unmanaged** solution in `Demo Contact Center EN`.
2. Export as **managed** for Test / Production.
3. Bind Environment Variables and Connection References per target environment.
4. Import in the correct order (see [import-order.md](../deployment/import-order.md)).

## Prerequisites

- Power Platform CLI (`pac`) — see [pac-cli.md](../deployment/pac-cli.md).
- A dedicated service account for connections.
- EasyDoc API credentials available as Environment Variables (never in source).

> Detailed steps will be expanded as the solution components are built.
