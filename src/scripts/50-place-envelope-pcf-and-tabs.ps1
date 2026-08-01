<#
  50-place-envelope-pcf-and-tabs.ps1

  Puts the Envelope Composition PCF on the alex_signaturetemplate main form and
  wires the tab-toggle web resource, fully via the Web API (no maker portal).

  What it does (idempotent / re-runnable):
    1. Uploads (or updates) the envelopeTabToggle.js web resource + publishes it.
    2. Fetches the template main form that hosts the field-mapping PCF.
    3. Renames the field-mapping tab -> "tab_documenttemplate".
    4. Clones the field-mapping control binding (controlDescription) into a new
       binding for the Envelope Composition PCF on the alex_envelopehost column.
    5. Clones the field-mapping tab -> a new "tab_envelope" tab that hosts the
       Envelope Composition control.
    6. Registers EasyDo.EnvelopeTabs.onLoad (form OnLoad) + the form library so
       exactly one of the two tabs is shown, based on alex_isenvelope.
    7. PATCHes the form + PublishAllXml.

  Prereq: 49-add-envelope-pcf-host-column.ps1 (alex_envelopehost column) and the
  EnvelopeComposition PCF must already be imported (pac pcf push).
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null
$ErrorActionPreference = "Stop"

$mainName  = "alex_d365_easydo"
$solHeader = @{ "MSCRM.SolutionUniqueName" = $mainName }
$jsPath    = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\webresources\envelopeTabToggle.js"))
$jsName    = "alex_/scripts/envelopeTabToggle.js"

function NewGuidB { "{" + ([guid]::NewGuid().ToString()) + "}" }
function NewGuidP { ([guid]::NewGuid().ToString()) }

# ---- 1. upload the tab-toggle web resource + publish ----------------------
if (-not (Test-Path $jsPath)) { throw "Web resource not found: $jsPath" }
$jsB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($jsPath))
$wr = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$jsName'").value
if (-not $wr -or $wr.Count -eq 0) {
    Invoke-DV POST "webresourceset" -Body @{ name = $jsName; displayname = "easydo - Envelope tab toggle"; webresourcetype = 3; content = $jsB64 } -ExtraHeaders $solHeader -Silent | Out-Null
    $wrId = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$jsName'").value[0].webresourceid
    Write-Output "web resource CREATED ($wrId)"
} else {
    $wrId = $wr[0].webresourceid
    Invoke-DV PATCH "webresourceset($wrId)" -Body @{ content = $jsB64 } | Out-Null
    Write-Output "web resource UPDATED ($wrId)"
}
Invoke-DV POST "PublishXml" -Body @{ ParameterXml = "<importexportxml><webresources><webresource>{$wrId}</webresource></webresources></importexportxml>" } | Out-Null

# ---- 1b. ensure the EnvelopeComposition control is in the solution ---------
# `pac pcf push` imports the control org-wide (via a temp solution) but does NOT
# add it to alex_d365_easydo. A form that references a control missing from the
# solution can fail to render its custom controls, so we add it explicitly.
$ccName = "alex_EasyDo.EnvelopeComposition"
$cc = (Invoke-DV GET "customcontrols?`$select=customcontrolid&`$filter=name eq '$ccName'").value
if ($cc -and $cc.Count -gt 0) {
    try {
        Invoke-DV POST "AddSolutionComponent" -Body @{ ComponentId = $cc[0].customcontrolid; ComponentType = 66; SolutionUniqueName = $mainName; AddRequiredComponents = $false } | Out-Null
        Write-Output "EnvelopeComposition control ensured in solution ($($cc[0].customcontrolid))"
    } catch {
        Write-Output "EnvelopeComposition control already in solution (skip)"
    }
} else {
    Write-Output "WARNING: customcontrol '$ccName' not found - run 'pac pcf push' from src/pcf-envelope first."
}

# ---- 2. fetch the template main form hosting the field-mapping PCF ---------
$forms = (Invoke-DV GET "systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq 'alex_signaturetemplate' and type eq 2").value
$form  = $forms | Where-Object { $_.formxml -match 'alex_pcfhost' } | Select-Object -First 1
if (-not $form) { throw "Template main form with alex_pcfhost not found." }
$formId = $form.formid
Write-Output "Form: $($form.name) ($formId)"

[xml]$doc  = $form.formxml
$formEl    = $doc.DocumentElement

# ---- 3. locate the field-mapping control + its tab; rename the tab ---------
$pcfCtrl = $doc.SelectSingleNode("//control[@datafieldname='alex_pcfhost']")
if (-not $pcfCtrl) { throw "alex_pcfhost control not found in form." }
$pcfUid  = $pcfCtrl.uniqueid
$docTab  = $doc.SelectSingleNode("//tab[.//control[@datafieldname='alex_pcfhost']]")
if (-not $docTab) { throw "Tab hosting alex_pcfhost not found." }
$docTab.SetAttribute("name", "tab_documenttemplate")
$tabs = $docTab.ParentNode
Write-Output "Renamed host tab -> tab_documenttemplate (control uid $pcfUid)"

# ---- 4. remove any prior envelope tab + binding (re-run safety) ------------
$oldEnvTab = $doc.SelectSingleNode("//tab[@name='tab_envelope']")
if ($oldEnvTab) {
    $oldCtrl = $oldEnvTab.SelectSingleNode(".//control[@datafieldname='alex_envelopehost']")
    if ($oldCtrl) {
        $oldUid = $oldCtrl.uniqueid
        $oldCd  = $doc.SelectSingleNode("//controlDescription[@forControl='$oldUid']")
        if ($oldCd) { [void]$oldCd.ParentNode.RemoveChild($oldCd) }
    }
    [void]$oldEnvTab.ParentNode.RemoveChild($oldEnvTab)
    Write-Output "Removed existing tab_envelope (re-run)"
}

# ---- 5. clone the control binding (controlDescription) for the envelope ----
$envUid = NewGuidB
$cd = $doc.SelectSingleNode("//controlDescription[@forControl='$pcfUid']")
if (-not $cd) { throw "controlDescription for alex_pcfhost not found." }
$cdClone = $cd.CloneNode($true)
$cdClone.SetAttribute("forControl", $envUid)
foreach ($dfn in $cdClone.SelectNodes(".//datafieldname")) { $dfn.InnerText = "alex_envelopehost" }
foreach ($cc in $cdClone.SelectNodes(".//customControl[@name]")) {
    $cc.SetAttribute("name", "alex_EasyDo.EnvelopeComposition")
    foreach ($hf in $cc.SelectNodes(".//hostField")) { $hf.InnerText = "alex_envelopehost" }
}
[void]$cd.ParentNode.AppendChild($cdClone)
Write-Output "Added controlDescription for envelope (forControl $envUid)"

# ---- 6. clone the tab -> tab_envelope, rebind its control -----------------
$envTab = $docTab.CloneNode($true)
$envTab.SetAttribute("name", "tab_envelope")
$envTab.SetAttribute("id", (NewGuidP))
$tabLbl = $envTab.SelectSingleNode("./labels/label")
# מעטפה
if ($tabLbl) { $tabLbl.SetAttribute("description", (-join ([int[]]@(0x05DE,0x05E2,0x05D8,0x05E4,0x05D4) | ForEach-Object { [char]$_ }))) }
foreach ($sec in $envTab.SelectNodes(".//section")) { $sec.SetAttribute("id", (NewGuidP)) }
$envCtrl = $envTab.SelectSingleNode(".//control[@datafieldname='alex_pcfhost']")
$envCell = $envCtrl.ParentNode
$envCell.SetAttribute("id", (NewGuidB))
$cellLbl = $envCell.SelectSingleNode("./labels/label")
# הרכב מעטפה
if ($cellLbl) { $cellLbl.SetAttribute("description", -join ([int[]]@(0x05D4,0x05E8,0x05DB,0x05D1,0x20,0x05DE,0x05E2,0x05D8,0x05E4,0x05D4) | ForEach-Object { [char]$_ })) }
$envCtrl.SetAttribute("id", "alex_envelopehost")
$envCtrl.SetAttribute("datafieldname", "alex_envelopehost")
$envCtrl.SetAttribute("uniqueid", $envUid)
[void]$tabs.InsertAfter($envTab, $docTab)
Write-Output "Added tab_envelope hosting alex_envelopehost (EnvelopeComposition)"

# ---- 7. register the OnLoad handler (events after <tabs>) ------------------
$events = $formEl.SelectSingleNode("./events")
if (-not $events) {
    $events = $doc.CreateElement("events")
    [void]$formEl.InsertAfter($events, $tabs)
}
foreach ($h in @($events.SelectNodes(".//Handler[@libraryName='$jsName']"))) {
    $ev = $h.ParentNode.ParentNode
    [void]$h.ParentNode.RemoveChild($h)
    if (-not $ev.SelectSingleNode(".//Handler")) { [void]$ev.ParentNode.RemoveChild($ev) }
}
$onload = $events.SelectSingleNode("./event[@name='onload']")
if (-not $onload) {
    $onload = $doc.CreateElement("event")
    $onload.SetAttribute("name", "onload")
    $onload.SetAttribute("application", "false")
    [void]$events.AppendChild($onload)
}
$handlers = $onload.SelectSingleNode("./Handlers")
if (-not $handlers) { $handlers = $doc.CreateElement("Handlers"); [void]$onload.AppendChild($handlers) }
$h = $doc.CreateElement("Handler")
$h.SetAttribute("functionName", "EasyDo.EnvelopeTabs.onLoad")
$h.SetAttribute("libraryName", $jsName)
$h.SetAttribute("handlerUniqueId", (NewGuidB))
$h.SetAttribute("enabled", "true")
$h.SetAttribute("parameters", "")
$h.SetAttribute("passExecutionContext", "true")
[void]$handlers.AppendChild($h)

# ---- 8. register the form library (formLibraries = last child) ------------
$libs = $formEl.SelectSingleNode("./formLibraries")
if (-not $libs) {
    $libs = $doc.CreateElement("formLibraries")
    [void]$formEl.AppendChild($libs)
}
foreach ($l in @($libs.SelectNodes("./Library[@name='$jsName']"))) { [void]$libs.RemoveChild($l) }
$lib = $doc.CreateElement("Library")
$lib.SetAttribute("name", $jsName)
$lib.SetAttribute("libraryUniqueId", (NewGuidB))
[void]$libs.AppendChild($lib)
Write-Output "Registered OnLoad handler + form library ($jsName)"

# ---- 9. PATCH the form + publish ------------------------------------------
Invoke-DV PATCH "systemforms($formId)" -Body @{ formxml = $doc.OuterXml } | Out-Null
Invoke-DV POST "PublishAllXml" -Body @{} | Out-Null
Write-Output "Form updated + published. Done."
