<#
  61-add-copychannel-columns.ps1

  Governance for the "send a signed copy to the customer" capability, per channel.

  Sending the signed copy is a DIFFERENT decision from delivering the signing
  link: a customer may sign via a WhatsApp link yet want the formal copy by email.
  So the copy channels are governed independently of the send channels
  (alex_allowemail / alex_allowsms / alex_allowwhatsapp) and of the primary
  easydo channel (alex_easydochannel).

    alex_easydosettings.alex_AllowCopyEmail    (Boolean, default Yes)
    alex_easydosettings.alex_AllowCopySms      (Boolean, default No)
    alex_easydosettings.alex_AllowCopyWhatsApp (Boolean, default No)

  The document viewer's "Send copy to customer" buttons are shown per channel
  only when the channel is allowed here (and the recipient has the address/phone
  the channel needs). Managed from the easydo Admin Center - Global send settings.

  Re-runnable: Add-DVColumn is idempotent. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$settings = "alex_easydosettings"
Write-Output "== $settings =="

Add-DVColumn $settings (New-DVBool -Schema "alex_AllowCopyEmail" -En "Allow Copy by Email" -He "אפשר עותק בדוא\""ל" `
    -TrueEn "Allowed" -TrueHe "מותר" -FalseEn "Blocked" -FalseHe "חסום" -Default $true `
    -DescEn "Whether the 'send a signed copy to the customer' Email button is offered on signed documents." `
    -DescHe "האם כפתור שליחת עותק חתום ללקוח בדוא\""ל מוצג במסמכים חתומים.")

Add-DVColumn $settings (New-DVBool -Schema "alex_AllowCopySms" -En "Allow Copy by SMS" -He "אפשר עותק ב-SMS" `
    -TrueEn "Allowed" -TrueHe "מותר" -FalseEn "Blocked" -FalseHe "חסום" -Default $false `
    -DescEn "Whether the 'send a signed copy to the customer' SMS button is offered on signed documents." `
    -DescHe "האם כפתור שליחת עותק חתום ללקוח ב-SMS מוצג במסמכים חתומים.")

Add-DVColumn $settings (New-DVBool -Schema "alex_AllowCopyWhatsApp" -En "Allow Copy by WhatsApp" -He "אפשר עותק בוואטסאפ" `
    -TrueEn "Allowed" -TrueHe "מותר" -FalseEn "Blocked" -FalseHe "חסום" -Default $false `
    -DescEn "Whether the 'send a signed copy to the customer' WhatsApp button is offered on signed documents." `
    -DescHe "האם כפתור שליחת עותק חתום ללקוח בוואטסאפ מוצג במסמכים חתומים.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
