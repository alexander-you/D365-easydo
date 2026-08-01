<#
  48-add-request-effective-auth-columns.ps1

  Identification & authentication feature (step 3 - request-level snapshot).

  The template/envelope holds the PIN & auth-method DEFAULTS (script 47). But the
  PIN actually delivered for a SPECIFIC signature request must be persisted on the
  request itself, because:
    - an override entered in the send wizard has no other home;
    - a "variable PIN" is resolved from a source field at a point in time and must
      stay reproducible even if that field later changes;
    - support / audit / resend need to know exactly which PIN a recipient received.

  This mirrors the expiry model (template alex_expirydays default -> request
  alex_expireson effective value).

  Columns added to alex_signaturerequest (regular fields, NO field-level security
  per request):

    alex_EffectivePin         (string)  the PIN actually sent for this request
                                         (fixed value / resolved-from-field / wizard override)
    alex_EffectiveAuthMethod  (choice)  the auth method actually applied (alex_authmethod)

  Re-runnable: Add-DVColumn is idempotent. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$req = "alex_signaturerequest"
Write-Output "== $req =="

Add-DVColumn $req (New-DVString -Schema "alex_EffectivePin" -En "Effective PIN" -He "PIN שנשלח" -MaxLength 50 `
    -DescEn "The PIN actually sent to the recipient for this request (a fixed template value, a value resolved from a source field, or a send-time override). Stored so the delivered PIN stays reproducible for support, audit and resend." `
    -DescHe "ה-PIN שנשלח בפועל לנמען עבור בקשה זו (ערך קבוע מהתבנית, ערך שנפתר משדה מקור, או דריסה בזמן שליחה). נשמר כדי שה-PIN שנמסר יישאר ניתן לשחזור לצורכי תמיכה, ביקורת ושליחה חוזרת.")

Add-DVColumn $req (New-DVPicklistGlobal -Schema "alex_EffectiveAuthMethod" -En "Effective Authentication Method" -He "שיטת אימות שהוחלה" `
    -DescEn "The recipient authentication method actually applied when this request was sent (None / PIN / OTP-SMS). Recorded for audit." `
    -DescHe "שיטת אימות הנמען שהוחלה בפועל בעת שליחת בקשה זו (ללא / PIN / OTP-SMS). נשמר לצורכי ביקורת." `
    -GlobalOptionSetName "alex_authmethod")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
