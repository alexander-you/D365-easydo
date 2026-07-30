# 43-deploy-expire-flow.ps1
# Creates + activates the daily "Expire Overdue Requests" cloud flow.
# Recurrence (daily) -> list open requests whose alex_expireson < now ->
# cancel the easydo form (connector CancelForm) -> mark alex_status = Expired.
# Idempotent: if a flow with the same name already exists it is PATCHed instead.

. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
Connect-Dataverse | Out-Null

$name = 'Expire Overdue Requests'
$flowFile = '.\src\flows\expire-overdue-requests.flow.json'

# minify the flow definition -> clientdata
$clientdata = (Get-Content -Raw -Path $flowFile | ConvertFrom-Json | ConvertTo-Json -Depth 100 -Compress)
$null = $clientdata | ConvertFrom-Json   # sanity
Write-Output ("clientdata length: " + $clientdata.Length)

$headers = @{ 'MSCRM.SolutionUniqueName' = 'alex_d365_easydo' }

# already exists?
$existing = Invoke-DV GET ("workflows?`$select=workflowid,statecode&`$filter=category eq 5 and name eq '" + $name + "'")
if ($existing.value.Count -gt 0) {
  $wid = $existing.value[0].workflowid
  Write-Output ("Flow exists ($wid) -> deactivating, patching clientdata, reactivating.")
  Invoke-DV PATCH ("workflows($wid)") -Body @{ statecode = 0; statuscode = 1 } | Out-Null
  Invoke-DV PATCH ("workflows($wid)") -Body @{ clientdata = $clientdata } -ExtraHeaders $headers | Out-Null
  Invoke-DV PATCH ("workflows($wid)") -Body @{ statecode = 1; statuscode = 2 } | Out-Null
  Write-Output "Existing flow updated + reactivated."
  return
}

# create as draft
$body = @{
  category      = 5
  type          = 1
  name          = $name
  primaryentity = 'none'
  clientdata    = $clientdata
  statecode     = 0
  statuscode    = 1
}
$created = Invoke-DV POST 'workflows' -Body $body -ExtraHeaders ($headers + @{ Prefer = 'return=representation' })
$wid = $created.workflowid
Write-Output ("Flow created: " + $wid)

# activate
Invoke-DV PATCH ("workflows($wid)") -Body @{ statecode = 1; statuscode = 2 } | Out-Null
Write-Output "Flow activated. Daily expiry monitor is live."
