<#
  56-add-statuscheck-columns.ps1

  On-demand "Check status" support for the Documents PCF / results viewer.

  The Documents grid gets a "Check status" button. Instead of a Custom API
  (which needs manual maker-UI wiring, see the sync-button lesson), the button
  simply STAMPS a datetime column on the signature request. A dedicated cloud
  flow (check-signature-status.flow.json) is subscribed to that single column
  and re-polls easydo for that one request on demand - the same reliable
  column-change trigger pattern used elsewhere.

  Columns added to alex_signaturerequest (all additive / idempotent):

    alex_StatusCheckRequestedOn (DateTime) - the button writes utcNow() here to
                                             fire the on-demand check flow.
    alex_StatusCheckLastRunOn   (DateTime) - the flow stamps this when it finishes.
    alex_StatusCheckStatus      (String)   - short result text ("OK" / error) for
                                             lightweight feedback / audit.

  Re-runnable: Add-DVColumn is idempotent. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$req = "alex_signaturerequest"
Write-Output "== $req =="

Add-DVColumn $req (New-DVDateTime -Schema "alex_StatusCheckRequestedOn" -En "Status Check Requested On" -He "בקשת בדיקת סטטוס בתאריך" `
    -DescEn "Set to the current time by the 'Check status' button to trigger an on-demand re-poll of easydo for this signature request. A dedicated cloud flow subscribes to this column." `
    -DescHe "מוגדר לזמן הנוכחי על ידי כפתור 'בדוק מצב' כדי להפעיל בדיקה מחדש מיידית מול easydo עבור בקשת חתימה זו. זרימת ענן ייעודית מנויה לעמודה זו.")

Add-DVColumn $req (New-DVDateTime -Schema "alex_StatusCheckLastRunOn" -En "Status Check Last Run On" -He "בדיקת סטטוס רצה לאחרונה" `
    -DescEn "The date and time the on-demand status-check flow last finished running for this request." `
    -DescHe "התאריך והשעה שבהם זרימת בדיקת הסטטוס לפי דרישה סיימה לרוץ לאחרונה עבור בקשה זו.")

Add-DVColumn $req (New-DVString -Schema "alex_StatusCheckStatus" -En "Status Check Result" -He "תוצאת בדיקת סטטוס" -MaxLength 400 `
    -DescEn "Short result text of the last on-demand status check ('OK' or an error message), for lightweight feedback and audit." `
    -DescHe "טקסט תוצאה קצר של בדיקת הסטטוס האחרונה לפי דרישה ('OK' או הודעת שגיאה), למשוב קל ולביקורת.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
