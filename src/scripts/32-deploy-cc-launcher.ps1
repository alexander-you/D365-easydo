<#
  32-deploy-cc-launcher.ps1

  Deploys the Contact Center send launcher web resource
  (src/webresources/contactCenterSend.js) as alex_/scripts/contactCenterSend.js
  (type 3 = JScript), adds it to the alex_d365_easydo solution, and publishes it.

  Idempotent: creates the web resource on first run, updates content thereafter.

  The launcher exposes EasyDo.ContactCenter.isEnabled / .launch for an
  agent-side Contact Center "Send easydo document" trigger. The button surface
  (ribbon / productivity pane) is wired in a later step.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

$ErrorActionPreference = "Stop"
$sol       = "alex_d365_easydo"
$jsPath    = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\webresources\contactCenterSend.js"))
$jsName    = "alex_/scripts/contactCenterSend.js"
$SolHeader = @{ "MSCRM.SolutionUniqueName" = $sol }

if (-not (Test-Path $jsPath)) { throw "Web resource not found: $jsPath" }
$jsB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($jsPath))

$wr = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$jsName'").value
if (-not $wr -or $wr.Count -eq 0) {
    $body = @{
        name            = $jsName
        displayname     = "easydo - Contact Center send launcher"
        webresourcetype = 3
        content         = $jsB64
    }
    Invoke-DV POST "webresourceset" -Body $body -ExtraHeaders $SolHeader -Silent | Out-Null
    $wrId = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$jsName'").value[0].webresourceid
    Write-Output "contactCenterSend.js CREATED ($wrId)"
} else {
    $wrId = $wr[0].webresourceid
    Invoke-DV PATCH "webresourceset($wrId)" -Body @{ content = $jsB64 } | Out-Null
    Write-Output "contactCenterSend.js UPDATED ($wrId)"
}

Invoke-DV POST "PublishXml" -Body @{ ParameterXml = "<importexportxml><webresources><webresource>{$wrId}</webresource></webresources></importexportxml>" } | Out-Null
Write-Output "Published."
