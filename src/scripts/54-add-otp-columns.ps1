<#
  54-add-otp-columns.ps1

  OTP (SMS) recipient authentication - schema (step for the OTP feature).

  When the recipient authentication method (alex_authmethod) is OTP, easydo
  sends a one-time code by SMS to the recipient's phone. This script adds the
  D365-side ADMIN DEFAULTS that tell the send flow WHICH phone number to use and
  whether the sender may change it at send time.

  Mirrors the Variable-PIN pattern (alex_PinSourceField / alex_PinAllowSendOverride):

    alex_OtpPhoneSource       (string)  logical name of a column ON THE PRIMARY
                                        TABLE whose value is the recipient phone
                                        number. Resolved from the source record at
                                        send time.
    alex_OtpAllowSendOverride (bool)    may the sender enter / change the OTP phone
                                        number in the send wizard.

  USER DECISION: OTP phone comes from a PRIMARY-TABLE column (not a contact
  lookup), with an optional sender-edit override. There is deliberately NO fixed
  OTP phone option.

  Both columns are additive and default OFF / empty so existing templates are
  unaffected. Surfaced in the Template Field Mapping + Envelope Composition PCF
  auth section (shown only when Authentication Method = OTP).

  Re-runnable: Add-DVColumn skips existing columns. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$tpl = "alex_signaturetemplate"
Write-Output "== $tpl =="

Add-DVColumn $tpl (New-DVString -Schema "alex_OtpPhoneSource" -En "OTP Phone Source Field" -He "שדה מקור לטלפון OTP" -MaxLength 200 `
    -DescEn "Logical name of a column on the primary table whose value is the recipient phone number for OTP (SMS) authentication. Resolved from the source record at send time." `
    -DescHe "שם לוגי של עמודה בטבלה הראשית שערכה הוא מספר הטלפון של הנמען עבור אימות OTP (SMS). נפתר מרשומת המקור בזמן השליחה.")

Add-DVColumn $tpl (New-DVBool -Schema "alex_OtpAllowSendOverride" -En "Allow Changing OTP Phone At Send" -He "אפשר שינוי טלפון OTP בעת שליחה" `
    -DescEn "When on, the sender can enter or change the OTP phone number in the send wizard. When off, the template OTP phone source is always used." `
    -DescHe "כאשר פעיל, השולח יכול להזין או לשנות את מספר הטלפון ל-OTP באשף השליחה. כאשר כבוי, נעשה תמיד שימוש בשדה מקור הטלפון של התבנית." `
    -Default $false)

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
