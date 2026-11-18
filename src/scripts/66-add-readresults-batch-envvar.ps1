<#
  66-add-readresults-batch-envvar.ps1

  Creates the environment variable alex_ReadResultsBatchSize (Whole Number,
  default 25) in the alex_d365_easydo solution.

  "Read Signature Results" (every 5 min) processes at most this many requests per
  run, oldest status check first (alex_laststatuscheckon asc). The rest are picked
  up by the following runs in rotation, so nothing is skipped. Keeps every run well
  inside the 5-minute window and bounds the daily Power Platform action count.

  Idempotent: re-running only refreshes the display name / description / default.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

$schema  = "alex_ReadResultsBatchSize"
$headers = @{ 'MSCRM.SolutionUniqueName' = 'alex_d365_easydo' }
$body = @{
    displayname  = "Read Results Batch Size"
    description  = "Maximum number of signature requests the Read Signature Results flow processes per run (oldest status check first). Remaining requests are handled by the next runs. Default 25."
    type         = 100000001   # Number
    defaultvalue = "25"
}

$existing = (Invoke-DV GET "environmentvariabledefinitions?`$select=environmentvariabledefinitionid&`$filter=schemaname eq '$schema'").value
if ($existing -and $existing.Count -gt 0) {
    $id = $existing[0].environmentvariabledefinitionid
    Invoke-DV PATCH "environmentvariabledefinitions($id)" -Body $body -ExtraHeaders $headers | Out-Null
    Write-Output "Environment variable $schema exists ($id) - refreshed."
} else {
    $body.schemaname = $schema
    $r = Invoke-DV POST "environmentvariabledefinitions" -Body $body -ExtraHeaders $headers -ReturnHeaders
    $id = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "+ Environment variable $schema ($id), default 25."
}
