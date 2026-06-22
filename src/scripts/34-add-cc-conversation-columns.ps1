# 34-add-cc-conversation-columns.ps1
# Contact Center self-distribution: when a signature request is sent from a LIVE
# conversation, the signing link is delivered over that conversation instead of
# easydo's native notify. Two columns on alex_signaturerequest carry the context:
#   - alex_ccconversationid : the msdyn_ocliveworkitem id (the CC signal). When set,
#     the Send flow uses notify_platform = null so easydo stays silent (no double-send).
#   - alex_ccchannel        : the conversation channel (chat / whatsapp / sms) for reporting.
# Idempotent: Add-DVColumn is create-or-skip.
$ErrorActionPreference = "Stop"
. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
. .\src\scripts\dv-meta.ps1
Connect-Dataverse | Out-Null

$conv = New-DVString `
    -Schema "alex_CcConversationId" `
    -En "CC conversation id" -He "מזהה שיחת Contact Center" `
    -DescEn "The live conversation (msdyn_ocliveworkitem) this request was sent from. When set, the Send flow suppresses easydo's native notify (notify_platform = null) and the link is delivered over the conversation." `
    -DescHe "השיחה החיה (msdyn_ocliveworkitem) שממנה נשלחה הבקשה. כשמוגדר, זרימת השליחה מבטלת את ההתראה הנייטיב של easydo (notify_platform = null) והקישור נמסר דרך השיחה." `
    -MaxLength 200

Add-DVColumn -TableLogical "alex_signaturerequest" -Attribute $conv

$chan = New-DVString `
    -Schema "alex_CcChannel" `
    -En "CC channel" -He "ערוץ Contact Center" `
    -DescEn "The live conversation channel (chat / whatsapp / sms) the signing link was delivered over." `
    -DescHe "ערוץ השיחה החיה (צ'אט / וואטסאפ / SMS) שדרכו נמסר קישור החתימה." `
    -MaxLength 200

Add-DVColumn -TableLogical "alex_signaturerequest" -Attribute $chan

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. alex_ccconversationid + alex_ccchannel ensured + published."
