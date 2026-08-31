<#
  64-add-cancel-columns.ps1

  Adds the columns that back the manual "cancel signature request" experience
  (cancel button in the document viewer pane).

    alex_signaturerequest.alex_CancelReason (Memo, multi-line text area)
        Free-text reason the user typed when cancelling the request. Kept in
        Dataverse for audit only — easydo's CancelForm has no reason field, so
        nothing is pushed to easydo. Rendered as a text area on the form.

    alex_easydosettings.alex_RequireCancelReason (Boolean, default No)
        Org-wide policy: when Yes, the cancel dialog forces the user to type a
        reason before the request can be cancelled. Managed from the easydo
        Admin Center (Global send settings drawer).

  Re-runnable: Add-DVColumn is idempotent. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- Cancel reason on the request (multi-line text area) -----------------
$req = "alex_signaturerequest"
Write-Output "== $req =="
Add-DVColumn $req (New-DVMemo -Schema "alex_CancelReason" -En "Cancellation Reason" -He "סיבת ביטול" -MaxLength 2000 `
    -DescEn "Reason the user entered when the signature request was cancelled. Stored for audit; not sent to easydo." `
    -DescHe "הסיבה שהזין המשתמש בעת ביטול בקשת החתימה. נשמרת למעקב; אינה נשלחת ל-easydo.")

# ---- Global policy: require a cancellation reason ------------------------
$settings = "alex_easydosettings"
Write-Output "== $settings =="
Add-DVColumn $settings (New-DVBool -Schema "alex_RequireCancelReason" -En "Require Cancellation Reason" -He "חייב סיבת ביטול" `
    -DescEn "Org-wide policy: when on, users must enter a reason before cancelling a signature request." `
    -DescHe "מדיניות ארגונית: כאשר מופעל, על המשתמשים להזין סיבה לפני ביטול בקשת חתימה." `
    -Default $false)

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
