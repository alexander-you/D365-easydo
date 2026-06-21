# 23-add-lastviewedon-column.ps1
# Item ב: add a "smart" engagement column on alex_signaturerequest that stores
# only the MOST RECENT time the recipient viewed the document (not a counter and
# not every visit). The value is filled by the Read Signature Results flow from
# the easydo form's assignee engagement log (action == "view").
$ErrorActionPreference = "Stop"
. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
. .\src\scripts\dv-meta.ps1
Connect-Dataverse | Out-Null

$col = New-DVDateTime `
    -Schema "alex_LastViewedOn" `
    -En "Last viewed on" -He "נצפה לאחרונה" `
    -DescEn "The most recent time the recipient opened the document to view it (from easydo engagement log)." `
    -DescHe "הפעם האחרונה שבה הנמען פתח את המסמך לצפייה (מתוך יומן המעורבות של easydo)." `
    -Format "DateAndTime"

Add-DVColumn -TableLogical "alex_signaturerequest" -Attribute $col

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. alex_lastviewedon ensured + published."
