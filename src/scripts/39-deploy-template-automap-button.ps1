<#
  39-deploy-template-automap-button.ps1

  Installs an "Auto-map fields" button on the alex_signaturetemplate FORM ribbon.
  Clicking it calls the alex_AutoMapTemplateFields Custom API for the current
  template, which resolves each field mapping's export name into a Dynamics
  table.column binding (overwriting every resolvable row), then refreshes the form.

  Same application-ribbon staging technique as 19-deploy-global-formbutton.ps1, but:
    - the CustomAction Location is scoped to alex_signaturetemplate ONLY, so the
      button appears solely on the template form (no global visibility, no rule);
    - a different CustomAction/Command Id set, so it MERGES alongside the existing
      global send button (application-ribbon import merges custom actions by Id).

  Mechanism:
    1. Upload the templateAutoMap.js web resource + PublishXml.
    2. Ensure a staging solution + add the APPLICATION RIBBON to it (type 50).
    3. Export the staging solution -> a valid shell with an EMPTY <RibbonDiffXml>.
    4. Inject our CustomAction + CommandDefinition into that empty RibbonDiffXml.
    5. ImportSolution + PublishAllXml, then consolidate + drop the staging solution.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

$ErrorActionPreference = "Stop"
$prefix    = "alex"
$stageName = "alextmptplribbon"
$mainName  = "alex_d365_easydo"
$jsPath    = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\webresources\templateAutoMap.js"))
$jsName    = "alex_/scripts/templateAutoMap.js"
$iconPath  = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\webresources\icons\autoMapIcon.svg"))
$iconName  = "alex_/icons/autoMapIcon.svg"

function Heb([int[]]$c) { -join ($c | ForEach-Object { [char]$_ }) }
# "התאמה אוטומטית של שדות"
$label = Heb @(0x05D4,0x05EA,0x05D0,0x05DE,0x05D4,0x20,0x05D0,0x05D5,0x05D8,0x05D5,0x05DE,0x05D8,0x05D9,0x05EA,0x20,0x05E9,0x05DC,0x20,0x05E9,0x05D3,0x05D5,0x05EA)

# ---- 1. upload templateAutoMap.js (create or update) + publish -----------
if (-not (Test-Path $jsPath)) { throw "Web resource not found: $jsPath" }
$jsB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($jsPath))
$solHeader = @{ "MSCRM.SolutionUniqueName" = $mainName }
$wr = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$jsName'").value
if (-not $wr -or $wr.Count -eq 0) {
    Invoke-DV POST "webresourceset" -Body @{ name = $jsName; displayname = "easydo - Template auto-map"; webresourcetype = 3; content = $jsB64 } -ExtraHeaders $solHeader -Silent | Out-Null
    $wrId = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$jsName'").value[0].webresourceid
    Write-Output "templateAutoMap.js CREATED ($wrId)"
} else {
    $wrId = $wr[0].webresourceid
    Invoke-DV PATCH "webresourceset($wrId)" -Body @{ content = $jsB64 } | Out-Null
    Write-Output "templateAutoMap.js UPDATED ($wrId)"
}
Invoke-DV POST "PublishXml" -Body @{ ParameterXml = "<importexportxml><webresources><webresource>{$wrId}</webresource></webresources></importexportxml>" } | Out-Null
Write-Output "templateAutoMap.js published ($wrId)"

# ---- 1b. upload the button icon (SVG, webresourcetype 11) + publish -------
if (-not (Test-Path $iconPath)) { throw "Icon not found: $iconPath" }
$iconB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($iconPath))
$ic = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$iconName'").value
if (-not $ic -or $ic.Count -eq 0) {
    Invoke-DV POST "webresourceset" -Body @{ name = $iconName; displayname = "easydo - Auto-map icon"; webresourcetype = 11; content = $iconB64 } -ExtraHeaders $solHeader -Silent | Out-Null
    $iconId = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$iconName'").value[0].webresourceid
    Write-Output "autoMapIcon.svg CREATED ($iconId)"
} else {
    $iconId = $ic[0].webresourceid
    Invoke-DV PATCH "webresourceset($iconId)" -Body @{ content = $iconB64 } | Out-Null
    Write-Output "autoMapIcon.svg UPDATED ($iconId)"
}
Invoke-DV POST "PublishXml" -Body @{ ParameterXml = "<importexportxml><webresources><webresource>{$iconId}</webresource></webresources></importexportxml>" } | Out-Null
Write-Output "autoMapIcon.svg published ($iconId)"

# ---- 1c. ensure both web resources live in the main solution --------------
foreach ($wrGuid in @($wrId, $iconId)) {
    try { Invoke-DV POST "AddSolutionComponent" -Body @{ ComponentId = $wrGuid; ComponentType = 61; SolutionUniqueName = $mainName; AddRequiredComponents = $false } -Silent | Out-Null } catch {}
}
Write-Output "Web resources ensured in main solution '$mainName'"

# ---- 2. ensure staging solution + add the application ribbon to it --------
$pub = (Invoke-DV GET "publishers?`$select=publisherid&`$filter=customizationprefix eq '$prefix'").value[0].publisherid
$s = (Invoke-DV GET "solutions?`$select=solutionid&`$filter=uniquename eq '$stageName'").value
if (-not $s -or $s.Count -eq 0) {
    Invoke-DV POST "solutions" -Body @{ uniquename = $stageName; friendlyname = "easydo template-ribbon staging"; version = "1.0.0.0"; "publisherid@odata.bind" = "/publishers($pub)" } | Out-Null
    Write-Output "Staging solution '$stageName' created"
} else {
    Write-Output "Staging solution '$stageName' exists"
}

$rc = (Invoke-DV GET "ribboncustomizations?`$filter=entity eq null and ismanaged eq false&`$select=ribboncustomizationid").value
if (-not $rc -or $rc.Count -ne 1) { throw "Expected exactly one unmanaged application ribbon row, found $($rc.Count)." }
$rcId = $rc[0].ribboncustomizationid
try {
    Invoke-DV POST "AddSolutionComponent" -Body @{ ComponentId = $rcId; ComponentType = 50; SolutionUniqueName = $stageName; AddRequiredComponents = $false } -Silent | Out-Null
    Write-Output "Application ribbon added to staging ($rcId)"
} catch {
    Write-Output "Application ribbon already in staging (or add skipped): $rcId"
}

# ---- 3. export the staging shell (empty RibbonDiffXml) -------------------
$exp = Invoke-DV POST "ExportSolution" -Body @{ SolutionName = $stageName; Managed = $false }
$zipBytes = [Convert]::FromBase64String($exp.ExportSolutionFile)
Write-Output "Exported staging shell ($($zipBytes.Length) bytes)"

# ---- 4. build the ribbon fragments (global button, shown only on the
#         signature-template form via a CustomRule enable rule) --------------
$btnId  = "alex.template.Form.AutoMap.Button"
$caId   = "alex.template.Form.AutoMap.CustomAction"
$cmdId  = "alex.template.Form.AutoMap.Command"
$ruleId = "alex.template.Form.AutoMap.EnableRule"
$loc    = "Mscrm.Form.{!EntityLogicalName}.MainTab.Save.Controls._children"

$customAction = "<CustomAction Id=`"$caId`" Location=`"$loc`" Sequence=`"41`"><CommandUIDefinition><Button Id=`"$btnId`" Command=`"$cmdId`" Sequence=`"41`" LabelText=`"$label`" ToolTipTitle=`"$label`" ToolTipDescription=`"$label`" TemplateAlias=`"o1`" ModernImage=`"`$webresource:$iconName`" /></CommandUIDefinition></CustomAction>"
$button = "<Button Id=`"$btnId`" Command=`"$cmdId`" Sequence=`"41`" LabelText=`"$label`" ToolTipTitle=`"$label`" ToolTipDescription=`"$label`" TemplateAlias=`"o1`" ModernImage=`"`$webresource:$iconName`" />"
$commandDef = "<CommandDefinition Id=`"$cmdId`"><EnableRules><EnableRule Id=`"$ruleId`" /></EnableRules><DisplayRules /><Actions><JavaScriptFunction FunctionName=`"EasyDo.AutoMap.run`" Library=`"`$webresource:$jsName`"><CrmParameter Value=`"PrimaryControl`" /></JavaScriptFunction></Actions></CommandDefinition>"
$enableRuleDef = "<EnableRule Id=`"$ruleId`"><CustomRule FunctionName=`"EasyDo.AutoMap.isEnabled`" Library=`"`$webresource:$jsName`" Default=`"false`"><CrmParameter Value=`"PrimaryControl`" /></CustomRule></EnableRule>"

# ---- 5. inject into the empty RibbonDiffXml, re-zip, import, publish ------
Add-Type -AssemblyName System.IO.Compression
$ms = New-Object System.IO.MemoryStream
$ms.Write($zipBytes, 0, $zipBytes.Length)
$ms.Position = 0
$zip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Update, $true)
$entry = $zip.GetEntry("customizations.xml")
if (-not $entry) { throw "customizations.xml missing from exported staging solution." }
$reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
$cust = $reader.ReadToEnd(); $reader.Close()

if ($cust -notmatch '<RibbonDiffXml') { throw "Exported shell has no RibbonDiffXml - AddSolutionComponent step failed." }

# The application-ribbon export is CUMULATIVE: it already contains the existing
# global buttons, so the CustomActions / CommandDefinitions / RuleDefinitions
# EnableRules blocks are populated (NOT self-closed). Append our fragments before
# the relevant closing tags (falling back to the empty self-closed tag on a
# never-customized org). Idempotent: skip only when our button is already
# byte-identical (icon included); otherwise inject fresh or refresh in place.
$doImport = $true
if ($cust.Contains($button)) {
    Write-Output "Auto-map button already up to date (icon present); skipping ribbon import (web resources still refreshed)."
    $doImport = $false
    $zip.Dispose()
    $ms.Dispose()
} elseif ($cust.Contains($btnId)) {
    # Button exists but differs (e.g. an earlier deploy had no icon): replace the
    # whole <Button .../> element in place via index splice (no regex, so the
    # label and $webresource token that contain '$' are inserted literally).
    $bs = $cust.IndexOf('<Button Id="' + $btnId + '"')
    $be = $cust.IndexOf('/>', $bs) + 2
    $cust = $cust.Substring(0, $bs) + $button + $cust.Substring($be)
    Write-Output "Refreshed existing auto-map button (added/updated icon)."
} else {
    if ($cust.Contains('<CustomActions />')) { $cust = $cust.Replace('<CustomActions />', "<CustomActions>$customAction</CustomActions>") }
    else { $cust = $cust.Replace('</CustomActions>', "$customAction</CustomActions>") }

    if ($cust.Contains('<CommandDefinitions />')) { $cust = $cust.Replace('<CommandDefinitions />', "<CommandDefinitions>$commandDef</CommandDefinitions>") }
    else { $cust = $cust.Replace('</CommandDefinitions>', "$commandDef</CommandDefinitions>") }

    # RuleDefinitions' EnableRules is the LAST </EnableRules> in the document
    # (CommandDefinitions' own EnableRules block comes earlier).
    if ($cust.Contains('<EnableRules />')) {
        $cust = $cust.Replace('<EnableRules />', "<EnableRules>$enableRuleDef</EnableRules>")
    } else {
        $li = $cust.LastIndexOf('</EnableRules>')
        $cust = $cust.Substring(0, $li) + $enableRuleDef + $cust.Substring($li)
    }
    Write-Output "Injected new template auto-map button into application ribbon."
}

if ($doImport) {
    $entry.Delete()
    $fresh = $zip.CreateEntry("customizations.xml")
    $writer = New-Object System.IO.StreamWriter($fresh.Open(), (New-Object System.Text.UTF8Encoding($false)))
    $writer.Write($cust); $writer.Flush(); $writer.Close()
    $zip.Dispose()
    $newZip = $ms.ToArray(); $ms.Dispose()
    Write-Output "Application ribbon customizations.xml rewritten ($($newZip.Length) bytes)"

    $importId = [guid]::NewGuid().ToString()
    Invoke-DV POST "ImportSolution" -Body @{
        OverwriteUnmanagedCustomizations = $true
        PublishWorkflows                 = $false
        CustomizationFile                = [Convert]::ToBase64String($newZip)
        ImportJobId                      = $importId
    } | Out-Null
    Write-Output "ImportSolution submitted (job $importId)"

    Invoke-DV POST "PublishAllXml" | Out-Null
    Write-Output "PublishAllXml done. Template auto-map button deployed."
}

# ---- 6. consolidate into the main solution + remove staging --------------
try {
    Invoke-DV POST "AddSolutionComponent" -Body @{ ComponentId = $rcId; ComponentType = 50; SolutionUniqueName = $mainName; AddRequiredComponents = $false } | Out-Null
    Write-Output "Application ribbon ensured in main solution '$mainName'"
} catch {
    Write-Output "Application ribbon already in '$mainName' (or add skipped): $($_.Exception.Message)"
}
$stage = (Invoke-DV GET "solutions?`$select=solutionid&`$filter=uniquename eq '$stageName'").value
if ($stage -and $stage.Count -gt 0) {
    Invoke-DV DELETE "solutions($($stage[0].solutionid))" | Out-Null
    Write-Output "Staging solution '$stageName' removed"
}
