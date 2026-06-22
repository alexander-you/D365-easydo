<#
  32-deploy-cc-launcher.ps1

  Deploys the Contact Center agent-side web resources and publishes them:
    - src/webresources/contactCenterSend.js  -> alex_/scripts/contactCenterSend.js (type 3, JScript)
        Launcher: EasyDo.ContactCenter.isEnabled / .getCurrentContext / .launch.
    - src/webresources/contactCenterPane.html -> alex_/html/contactCenterPane.html (type 1, HTML)
        Productivity-pane host UI (always-on, discovers the focused conversation itself).

  Idempotent: creates each web resource on first run, updates content thereafter,
  adds new ones to the alex_d365_easydo solution, and publishes.

  The productivity-pane SURFACE is registered in the Contact Center admin center
  (custom productivity tool) - that config step is not part of this script.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

$ErrorActionPreference = "Stop"
$sol       = "alex_d365_easydo"
$SolHeader = @{ "MSCRM.SolutionUniqueName" = $sol }

$resources = @(
    @{ Path = "..\webresources\contactCenterSend.js";  Name = "alex_/scripts/contactCenterSend.js"; Type = 3; Display = "easydo - Contact Center send launcher" }
    @{ Path = "..\webresources\contactCenterPane.html"; Name = "alex_/html/contactCenterPane.html";  Type = 1; Display = "easydo - Contact Center productivity pane" }
)

$ids = @()
foreach ($res in $resources) {
    $full = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $res.Path))
    if (-not (Test-Path $full)) { throw "Web resource not found: $full" }
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($full))

    $wr = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$($res.Name)'").value
    if (-not $wr -or $wr.Count -eq 0) {
        $body = @{ name = $res.Name; displayname = $res.Display; webresourcetype = $res.Type; content = $b64 }
        Invoke-DV POST "webresourceset" -Body $body -ExtraHeaders $SolHeader -Silent | Out-Null
        $wrId = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$($res.Name)'").value[0].webresourceid
        Write-Output "$($res.Name) CREATED ($wrId)"
    } else {
        $wrId = $wr[0].webresourceid
        Invoke-DV PATCH "webresourceset($wrId)" -Body @{ content = $b64 } | Out-Null
        Write-Output "$($res.Name) UPDATED ($wrId)"
    }
    $ids += $wrId
}

$xml = "<importexportxml><webresources>" + (($ids | ForEach-Object { "<webresource>{$_}</webresource>" }) -join "") + "</webresources></importexportxml>"
Invoke-DV POST "PublishXml" -Body @{ ParameterXml = $xml } | Out-Null
Write-Output "Published."
