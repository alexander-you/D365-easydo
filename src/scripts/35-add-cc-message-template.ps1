# 35-add-cc-message-template.ps1
# Contact Center: the admin can define the message text that wraps the signing link
# when it is pushed into the live conversation. The placeholder {link} (or {קישור})
# is replaced with the actual signing URL by the send wizard. When empty, the raw
# link is sent. One column on the alex_easydosettings singleton:
#   - alex_ccmessagetemplate : e.g. "מסמך מוכן לחתימה: {קישור}".
# Idempotent: Add-DVColumn is create-or-skip.
$ErrorActionPreference = "Stop"
. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
. .\src\scripts\dv-meta.ps1
Connect-Dataverse | Out-Null

$tpl = New-DVString `
    -Schema "alex_CcMessageTemplate" `
    -En "CC message template" -He "תבנית הודעת Contact Center" `
    -DescEn "Text sent with the signing link in the live conversation. Use {link} (or {קישור}) as the placeholder for the signing URL. When empty, the raw link is sent." `
    -DescHe "הטקסט שנשלח עם קישור החתימה בשיחה החיה. השתמשו ב-{link} (או {קישור}) כמציין מיקום לכתובת החתימה. כשריק, נשלח הקישור בלבד." `
    -MaxLength 500

Add-DVColumn -TableLogical "alex_easydosettings" -Attribute $tpl

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. alex_ccmessagetemplate ensured + published."
