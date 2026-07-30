# Bumps the alex_d365_easydo solution version and exports BOTH managed and
# unmanaged solution zips into deployment/releases/<version>/.
# Web API only. Run: pwsh -NoProfile -File src/scripts/40-export-release.ps1 -Version 1.2.0.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version
)
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

$solutionUnique = "alex_d365_easydo"
$sol = (Invoke-DV GET "solutions?`$select=solutionid,uniquename,version&`$filter=uniquename eq '$solutionUnique'").value[0]
if (-not $sol) { throw "Solution $solutionUnique not found." }
Write-Output "Current: $($sol.uniquename) v$($sol.version) (id $($sol.solutionid))"

# 1. Bump version
Write-Output "Bumping version -> $Version"
Invoke-DV -Method PATCH -Path "solutions($($sol.solutionid))" -Body @{ version = $Version } | Out-Null

# 2. Publish everything so the export is complete
Write-Output "PublishAllXml..."
Invoke-DV POST "PublishAllXml" -Body @{} | Out-Null

# 3. Output folder
$verFolder = $Version -replace '\.', '_'
$outDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "deployment\releases\$Version"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# 4. Export unmanaged
Write-Output "Exporting UNMANAGED..."
$expU = Invoke-DV POST "ExportSolution" -Body @{ SolutionName = $solutionUnique; Managed = $false }
$unmanagedPath = Join-Path $outDir "${solutionUnique}_${verFolder}.zip"
[IO.File]::WriteAllBytes($unmanagedPath, [Convert]::FromBase64String($expU.ExportSolutionFile))
Write-Output ("  -> {0} ({1:N0} bytes)" -f $unmanagedPath, (Get-Item $unmanagedPath).Length)

# 5. Export managed
Write-Output "Exporting MANAGED..."
$expM = Invoke-DV POST "ExportSolution" -Body @{ SolutionName = $solutionUnique; Managed = $true }
$managedPath = Join-Path $outDir "${solutionUnique}_${verFolder}_managed.zip"
[IO.File]::WriteAllBytes($managedPath, [Convert]::FromBase64String($expM.ExportSolutionFile))
Write-Output ("  -> {0} ({1:N0} bytes)" -f $managedPath, (Get-Item $managedPath).Length)

Write-Output ""
Write-Output "DONE. Exported v$Version (managed + unmanaged) to $outDir"
