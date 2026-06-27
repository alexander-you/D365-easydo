# 36-add-declinereason-column.ps1
# Decline handling: when a recipient refuses to sign in easydo, GetFormStatus
# returns form.status = "decline" and assignees[0].decline_reason = the free-text
# reason the customer typed. The scheduled polling flow promotes the request to
# Declined (626210007) and stores that text here so agents see *why* it was refused.
#   - alex_DeclineReason : Memo, the recipient's free-text decline reason.
# Idempotent: Add-DVColumn is create-or-skip.
$ErrorActionPreference = "Stop"
. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
. .\src\scripts\dv-meta.ps1
Connect-Dataverse | Out-Null

$reason = New-DVMemo `
    -Schema "alex_DeclineReason" `
    -En "Decline Reason" -He "סיבת דחייה" `
    -DescEn "The free-text reason the recipient typed in easydo when refusing to sign. Populated by the polling flow when the form status becomes 'decline'." `
    -DescHe "הטקסט החופשי שהנמען הקליד ב-easydo בעת סירוב לחתום. מתמלא על ידי זרימת הסנכרון כשסטטוס הטופס הופך ל-'decline'." `
    -MaxLength 2000

Add-DVColumn -TableLogical "alex_signaturerequest" -Attribute $reason

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. alex_declinereason ensured + published."
