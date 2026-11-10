. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

# Focused deploy (2.0.0.14 - skip read-back fields with an empty export header):
# "Read Signature Results" + "Check Signature Status", straight from the repo files.
$targets = @(
    @{ Name = "Read Signature Results"; File = "read-signature-results.flow.json" },
    @{ Name = "Check Signature Status"; File = "check-signature-status.flow.json" }
)

foreach ($t in $targets) {
    $path = Join-Path (Split-Path $PSScriptRoot -Parent) "flows\$($t.File)"
    $wfs = (Invoke-DV GET "workflows?`$select=workflowid,name&`$filter=category eq 5 and name eq '$($t.Name)'" -Silent).value
    if ($wfs.Count -ne 1) { throw "Expected exactly one cloud flow named '$($t.Name)', found $($wfs.Count)." }
    $Id = $wfs[0].workflowid

    Write-Host "=== Deploying $($t.Name) ($Id) <- $($t.File) ===" -ForegroundColor Cyan

    # Raw clientdata (NEVER round-trip through ConvertFrom/ConvertTo-Json)
    $raw = Get-Content -Path $path -Raw
    $null = $raw | ConvertFrom-Json

    # Normalize stale connection names -> live (no-op if already live)
    $raw = $raw.Replace("shared_alex-5feasydoc-5f5849d39a0feaf28d", "shared_alex-5feasydo-5f5849d39a0feaf28d")
    $raw = $raw.Replace("alex_EasyDoc", "alex_easydo")
    if ($raw -match "5feasydoc") { throw "Stale connection name still present in $($t.File)" }

    Invoke-DV -Method PATCH -Path "workflows($Id)" -Body @{ statecode = 0; statuscode = 1 } -Silent | Out-Null
    Invoke-DV -Method PATCH -Path "workflows($Id)" -Body @{ clientdata = $raw } -Silent | Out-Null
    Invoke-DV -Method PATCH -Path "workflows($Id)" -Body @{ statecode = 1; statuscode = 2 } -Silent | Out-Null

    $wf = Invoke-DV GET "workflows($Id)?`$select=name,statecode,statuscode,modifiedon" -Silent
    Write-Host ("   deployed + activated: name='{0}' statecode={1} statuscode={2} modifiedon={3}" -f $wf.name, $wf.statecode, $wf.statuscode, $wf.modifiedon) -ForegroundColor Green
}
