# 2.0.0.11 — Manual signature-request cancellation with reason

**Feature.** Cancel a signature request by hand, directly from the document pane, and
record why.

## What's new

- **Cancel button in the document pane.** Opening a **sent, not-yet-signed** single
  document in the *eayDo Documents* pane now shows a red **"ביטול בקשת החתימה"** (Cancel
  signature request) button. It opens a confirmation dialog with a **multi-line reason**
  text area. On confirm, the request's `alex_status` is set to **Cancelled**
  (`626210009`) and the reason is stored in the new `alex_cancelreason` memo column.
- **Closes the easydo form automatically.** Setting the status to Cancelled triggers the
  existing *"Cancel Signature Request on easydo"* flow (from 2.0.0.9), which calls the
  connector `CancelForm` so the recipient can no longer sign.
- **Optional "require cancel reason" governance.** A new global toggle **"חייב סיבת
  ביטול"** in the Admin Center → Send settings drawer (`alex_requirecancelreason` on
  `alex_easydosettings`) makes the reason mandatory.
- **Scope.** Single documents only. Envelopes are excluded (they close via a different
  id). The cancel button appears only for cancellable statuses.
- **Audit-only reason.** easydo has no free-text cancel-reason field, so nothing extra
  is pushed to easydo; `alex_cancelreason` is Dataverse-only and also appears on the
  signature-request form's *Tracking* section.

## New solution components

- `alex_signaturerequest.alex_cancelreason` — memo (text area), max length 2000.
- `alex_easydosettings.alex_requirecancelreason` — boolean, default No.
- Updated web resources: `alex_/html/documentViewer.html`, `alex_/html/adminCenter.html`.

## Import

Import the **managed** zip into test/production, or the **unmanaged** zip into a dev
environment. Establish the `alex_easydo` and `alex_dataverse_easydo` connections when
prompted. No separate PCF push is required.
