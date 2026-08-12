## D365 easydo v2.0.0.4

Corrects v2.0.0.3, which was published before the trigger concurrency fix was actually deployed/exported. Use this release instead of 2.0.0.3.

### What changed
1. Trigger concurrency (runs=1) on ALL scheduled (Recurrence) flows — verified inside the managed package:
   - Auto Sync EasyDo Templates (every 5 min)
   - Read Signature Results (every 5 min)
   - Expire Overdue Requests (daily)
   This stops runs from stacking on top of each other and self-throttling.
2. Manual "Sync Templates" no longer overwrites template field display names: it reads the field label and writes coalesce(label, header, name) plus alex_externalexportname (matches Auto Sync behavior).

### Assets
- alex_d365_easydo_2_0_0_4_managed.zip — managed solution (use this to install/upgrade).
- alex_d365_easydo_2_0_0_4.zip — unmanaged solution (dev/backup).

### Upgrade note
If concurrency was previously toggled manually in the flow UI, that creates an unmanaged active layer that shadows the managed setting. After import (Upgrade), open the affected flow, view solution layers, and remove the active/unmanaged customization so the managed value takes effect.
