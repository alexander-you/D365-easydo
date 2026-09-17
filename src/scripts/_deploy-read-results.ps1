. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

# Focused deploy: ONLY "Read Signature Results" (issue #1 fix).
$Id   = "0fc45c36-f96a-f111-ab0d-000d3a66fdf4"
$File = "read-signature-results.flow.json"
$path = Join-Path (Split-Path $PSScriptRoot -Parent) "flows\$File"

Write-Host "=== Deploying Read Signature Results <- $File ===" -ForegroundColor Cyan

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
