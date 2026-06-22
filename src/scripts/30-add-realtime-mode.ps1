<#
  30-add-realtime-mode.ps1

  Adds the "real-time mode" (מצב זמן אמת) capability end-to-end at the data
  layer.

  Real-time model
  ---------------
  The agent is on a live call with the customer, sends a document and watches
  its progress live (sent -> delivered -> viewed -> signed) until it returns,
  then approves or rejects it in a floating modal. A dedicated Do-Until flow
  polls easydo every few seconds and writes progress onto the request; the modal
  polls Dataverse only (never easydo) so no token ever reaches the browser.

  NEW COLUMN on alex_easydosettings
  ----------------------------------
    alex_RealtimeEnabled (bool, default false) - org master switch. When ON the
      send wizard offers a "real-time mode" choice per send.

  NEW COLUMNS on alex_signaturerequest
  ------------------------------------
    alex_IsRealtime            (bool) - this request is a real-time session.
    alex_RealtimeSessionActive (bool) - a polling session is currently running.
      The dedicated poll flow triggers on this; the 5-minute read-back flow
      skips requests where this is true to avoid contention.
    alex_AgentRejected         (bool)     - the agent rejected the returned doc.
    alex_AgentRejectedOn       (datetime) - when the agent rejected it.

  REUSED (already exist): alex_viewedon, alex_signedon, alex_completedon feed the
  progress rail; alex_externalformid / alex_signinglink drive polling.

  Idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1. Real-time master switch on the settings singleton ----------------
$s = "alex_easydosettings"
Write-Output "== $s =="
Add-DVColumn $s (New-DVBool -Schema "alex_RealtimeEnabled" -En "Enable Real-Time Mode" -He "אפשר מצב זמן אמת" `
    -DescEn "When on, the send wizard lets the agent send in real-time mode and watch live progress until the document returns." `
    -DescHe "כאשר מופעל, אשף השליחה מאפשר לנציג לשלוח במצב זמן אמת ולעקוב אחר ההתקדמות החיה עד שהמסמך חוזר." `
    -TrueEn "On" -TrueHe "דלוק" -FalseEn "Off" -FalseHe "כבוי" -Default $false)

# ---- 2. Real-time session flags on the request ---------------------------
$q = "alex_signaturerequest"
Write-Output "== $q =="
Add-DVColumn $q (New-DVBool -Schema "alex_IsRealtime" -En "Real-Time Session" -He "סשן זמן אמת" `
    -DescEn "True when this request was sent in real-time mode, where the agent watches live progress and approves the returned document." `
    -DescHe "אמת כאשר הבקשה נשלחה במצב זמן אמת, שבו הנציג עוקב אחר ההתקדמות החיה ומאשר את המסמך שחוזר." `
    -TrueEn "Yes" -TrueHe "כן" -FalseEn "No" -FalseHe "לא" -Default $false)
Add-DVColumn $q (New-DVBool -Schema "alex_RealtimeSessionActive" -En "Real-Time Session Active" -He "סשן זמן אמת פעיל" `
    -DescEn "True while the dedicated poll flow is actively polling easydo for this request. The 5-minute read-back flow skips requests where this is true to avoid contention." `
    -DescHe "אמת בזמן שזרימת הדגימה הייעודית דוגמת את easydo עבור בקשה זו. זרימת הקריאה החוזרת כל 5 דקות מדלגת על בקשות שבהן ערך זה אמת כדי למנוע התנגשות." `
    -TrueEn "Yes" -TrueHe "כן" -FalseEn "No" -FalseHe "לא" -Default $false)
Add-DVColumn $q (New-DVBool -Schema "alex_AgentRejected" -En "Rejected By Agent" -He "נדחה על-ידי הנציג" `
    -DescEn "True when the agent reviewed the returned document in real-time mode and rejected it without resending." `
    -DescHe "אמת כאשר הנציג סקר את המסמך שחזר במצב זמן אמת ודחה אותו בלי לשלוח שוב." `
    -TrueEn "Yes" -TrueHe "כן" -FalseEn "No" -FalseHe "לא" -Default $false)
Add-DVColumn $q (New-DVDateTime -Schema "alex_AgentRejectedOn" -En "Rejected On" -He "נדחה בתאריך" `
    -DescEn "Date and time the agent rejected the returned document in real-time mode." `
    -DescHe "התאריך והשעה שבהם הנציג דחה את המסמך שחזר במצב זמן אמת.")

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. Published."
