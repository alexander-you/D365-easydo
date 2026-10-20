. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

# Focused deploy: ONLY "Real-Time Session Poll" (2.0.0.13 - no status overwrite / no upsert of deleted requests).
$File = "realtime-session-poll.flow.json"
$path = Join-Path (Split-Path $PSScriptRoot -Parent) "flows\$File"

$wfs = (Invoke-DV GET "workflows?`$select=workflowid,name&`$filter=category eq 5 and contains(name,'Real') and contains(name,'Session')" -Silent).value
if ($wfs.Count -ne 1) { throw "Expected exactly one Real-Time Session Poll cloud flow, found $($wfs.Count): $($wfs.name -join ', ')" }
$Id = $wfs[0].workflowid

Write-Host "=== Deploying $($wfs[0].name) ($Id) <- $File ===" -ForegroundColor Cyan

# Raw clientdata (NEVER round-trip through ConvertFrom/ConvertTo-Json)
$raw = Get-Content -Path $path -Raw

# Sanity: must be valid JSON before we push it
$null = $raw | ConvertFrom-Json

# Normalize stale connection names -> live (no-op if already live)
$raw = $raw.Replace("shared_alex-5feasydoc-5f5849d39a0feaf28d", "shared_alex-5feasydo-5f5849d39a0feaf28d")
$raw = $raw.Replace("alex_EasyDoc", "alex_easydo")

if ($raw -match "5feasydoc") { throw "Stale connection name still present in $File" }

# 1) deactivate
Invoke-DV -Method PATCH -Path "workflows($Id)" -Body @{ statecode = 0; statuscode = 1 } -Silent | Out-Null
# 2) push clientdata
Invoke-DV -Method PATCH -Path "workflows($Id)" -Body @{ clientdata = $raw } -Silent | Out-Null
# 3) reactivate
Invoke-DV -Method PATCH -Path "workflows($Id)" -Body @{ statecode = 1; statuscode = 2 } -Silent | Out-Null

# Confirm state
$wf = Invoke-DV GET "workflows($Id)?`$select=name,statecode,statuscode,modifiedon" -Silent
Write-Host ("   deployed + activated: name='{0}' statecode={1} statuscode={2} modifiedon={3}" -f $wf.name, $wf.statecode, $wf.statuscode, $wf.modifiedon) -ForegroundColor Green
