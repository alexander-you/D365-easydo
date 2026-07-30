# 44-deploy-send-expiry-override.ps1
# Upgrades the live "Send Signature Request" flow so alex_expireson honors a
# per-send validity override from the wizard payload, but ONLY when the template
# has alex_allowexpiryoverride = true. Otherwise it falls back to the template's
# alex_expirydays (the behavior deployed by 42-deploy-send-expiry.ps1).
# String-splice: replaces the template-only expression with the override-aware one.

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

# current (template-only) expression deployed by script 42
$old = "@if(and(coalesce(outputs('Get_the_signature_template')?['body/alex_hasexpiry'], false), greater(int(coalesce(outputs('Get_the_signature_template')?['body/alex_expirydays'], 0)), 0)), addDays(utcNow(), int(outputs('Get_the_signature_template')?['body/alex_expirydays'])), null)"

# override-aware expression: use the wizard payload value when the template allows it
$new = "@if(and(coalesce(outputs('Get_the_signature_template')?['body/alex_hasexpiry'], false), greater(int(if(and(coalesce(outputs('Get_the_signature_template')?['body/alex_allowexpiryoverride'], false), greater(length(coalesce(triggerOutputs()?['body/alex_wizardpayload'], '')), 0)), coalesce(json(triggerOutputs()?['body/alex_wizardpayload'])?['payload']?['expiryDays'], coalesce(outputs('Get_the_signature_template')?['body/alex_expirydays'], 0)), coalesce(outputs('Get_the_signature_template')?['body/alex_expirydays'], 0))), 0)), addDays(utcNow(), int(if(and(coalesce(outputs('Get_the_signature_template')?['body/alex_allowexpiryoverride'], false), greater(length(coalesce(triggerOutputs()?['body/alex_wizardpayload'], '')), 0)), coalesce(json(triggerOutputs()?['body/alex_wizardpayload'])?['payload']?['expiryDays'], coalesce(outputs('Get_the_signature_template')?['body/alex_expirydays'], 0)), coalesce(outputs('Get_the_signature_template')?['body/alex_expirydays'], 0)))), null)"

$cd = Apply-One $cd $old $new 'override-aware expireson'

Write-Output ("clientdata length after: " + $cd.Length)

# sanity: must be valid JSON
$null = $cd | ConvertFrom-Json
Write-Output "clientdata parses as JSON: OK"

$headers = @{ 'MSCRM.SolutionUniqueName' = 'alex_d365_easydo' }
Invoke-DV PATCH ("workflows($wid)") -Body @{ clientdata = $cd } -ExtraHeaders $headers | Out-Null
Write-Output "clientdata PATCHed. Send flow now honors the per-send validity override."
