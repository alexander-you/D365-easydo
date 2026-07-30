# 42-deploy-send-expiry.ps1
# Patches the live "Send Signature Request" flow clientdata so that, when the
# request is marked as Sent, it also stamps alex_expireson:
#   alex_expireson = if template.alex_hasexpiry AND alex_expirydays > 0
#                      then addDays(utcNow(), alex_expirydays)
#                      else null
# String-splice on minified clientdata; the anchor must match exactly once.

. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
Connect-Dataverse | Out-Null

$wid = '50007ad1-876a-f111-ab0c-7ced8d72428a'   # Send Signature Request
$w = Invoke-DV GET ("workflows($wid)?`$select=clientdata")
$cd = $w.clientdata
Write-Output ("clientdata length before: " + $cd.Length)

function Apply-One($text, $old, $new, $label) {
  $count = ([regex]::Matches($text, [regex]::Escape($old))).Count
  if ($count -ne 1) { throw ("[$label] expected 1 match, found $count") }
  return $text.Replace($old, $new)
}

# Anchor: unique to Mark_request_as_Sent (the Failed branch has no realtime flag).
$old = @'
"item/alex_senton":"@utcNow()","item/alex_realtimesessionactive":"@coalesce(triggerOutputs()?['body/alex_isrealtime'], false)"
'@

$new = @'
"item/alex_senton":"@utcNow()","item/alex_expireson":"@if(and(coalesce(outputs('Get_the_signature_template')?['body/alex_hasexpiry'], false), greater(int(coalesce(outputs('Get_the_signature_template')?['body/alex_expirydays'], 0)), 0)), addDays(utcNow(), int(outputs('Get_the_signature_template')?['body/alex_expirydays'])), null)","item/alex_realtimesessionactive":"@coalesce(triggerOutputs()?['body/alex_isrealtime'], false)"
'@

$cd = Apply-One $cd $old $new 'expireson on Mark_request_as_Sent'

Write-Output ("clientdata length after: " + $cd.Length)

# sanity: must be valid JSON
$null = $cd | ConvertFrom-Json
Write-Output "clientdata parses as JSON: OK"

$headers = @{ 'MSCRM.SolutionUniqueName' = 'alex_d365_easydo' }
Invoke-DV PATCH ("workflows($wid)") -Body @{ clientdata = $cd } -ExtraHeaders $headers | Out-Null
Write-Output "clientdata PATCHed. Send flow now stamps alex_expireson."
