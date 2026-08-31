<#
  65-deploy-cancel-ui.ps1

  Redeploys the two HTML web resources changed by the manual-cancel feature:
    - alex_/html/documentViewer.html  (cancel button + reason dialog)
    - alex_/html/adminCenter.html     (global "require cancellation reason" toggle)

  Run 64-add-cancel-columns.ps1 first so the backing columns exist. Idempotent:
  PATCHes existing web resources by name, then publishes both.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$resources = @(
    @{ Name = "alex_/html/documentViewer.html"; File = "$PSScriptRoot\..\webresources\documentViewer.html" },
    @{ Name = "alex_/html/adminCenter.html";    File = "$PSScriptRoot\..\webresources\adminCenter.html" }
)

$ids = @()
foreach ($r in $resources) {
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $r.File)))
    $wr = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$($r.Name)'").value
    if (-not $wr) { throw "Web resource '$($r.Name)' not found in this environment." }
    $wrId = $wr[0].webresourceid
    Invoke-DV PATCH "webresourceset($wrId)" -Body @{ content = $b64 } | Out-Null
    Write-Output "  ~ updated $($r.Name)"
    $ids += $wrId
}

$xmlItems = ($ids | ForEach-Object { "<webresource>{$_}</webresource>" }) -join ""
Invoke-DV POST "PublishXml" -Body @{ ParameterXml = "<importexportxml><webresources>$xmlItems</webresources></importexportxml>" } | Out-Null
Write-Output "Published. Cancel UI is live."
