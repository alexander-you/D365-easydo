. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

# Live workflow ids
$flows = @(
  @{ Name = "Sync EasyDoc Templates"; Id = "c7533576-826a-f111-ab0c-7ced8d72428a"; File = "sync-easydoc-templates.flow.json" }
  @{ Name = "Auto Sync EasyDo Templates"; Id = "bf47806d-d16e-f111-ab0c-7ced8d726840"; File = "auto-sync-templates.flow.json" }
  @{ Name = "Send Signature Request"; Id = "50007ad1-876a-f111-ab0c-7ced8d72428a"; File = "send-signature-request.flow.json" }
  @{ Name = "Read Signature Results"; Id = "0fc45c36-f96a-f111-ab0d-000d3a66fdf4"; File = "read-signature-results.flow.json" }
)

$flowDir = Join-Path (Split-Path $PSScriptRoot -Parent) "flows"

foreach ($f in $flows) {
  $path = Join-Path $flowDir $f.File
  Write-Host "=== Deploying $($f.Name) <- $($f.File) ===" -ForegroundColor Cyan

  # Raw clientdata (NEVER round-trip through ConvertFrom/ConvertTo-Json)
  $raw = Get-Content -Path $path -Raw

  # Normalize stale connection names -> live (no-op if already live)
  $raw = $raw.Replace("shared_alex-5feasydoc-5f5849d39a0feaf28d", "shared_alex-5feasydo-5f5849d39a0feaf28d")
  $raw = $raw.Replace("alex_EasyDoc", "alex_easydo")

  if ($raw -match "5feasydoc") { throw "Stale connection name still present in $($f.File)" }

  # 1) deactivate
  Invoke-DV -Method PATCH -Path "workflows($($f.Id))" -Body @{ statecode = 0; statuscode = 1 } -Silent | Out-Null
  # 2) push clientdata
  Invoke-DV -Method PATCH -Path "workflows($($f.Id))" -Body @{ clientdata = $raw } -Silent | Out-Null
  # 3) reactivate
  Invoke-DV -Method PATCH -Path "workflows($($f.Id))" -Body @{ statecode = 1; statuscode = 2 } -Silent | Out-Null

  Write-Host "   deployed + activated" -ForegroundColor Green
}

Write-Host "All flows deployed." -ForegroundColor Green
