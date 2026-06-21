<#
  19-deploy-global-formbutton.ps1

  Installs ONE global "Send easydo document" button on every table's form via the
  APPLICATION RIBBON (table template), and controls its visibility per table at
  runtime with a CustomRule EnableRule that reads alex_easydoentityconfig.

  The button is installed once (design time, by this script). Admins only add
  alex_easydoentityconfig rows with alex_sendenabled = true to surface the button
  on a table - no redeploy, no per-entity work, no runtime export/import.

  Verified global location (RetrieveApplicationRibbon on this org):
    Mscrm.Form.{!EntityLogicalName}.MainTab.Save.Controls._children  (Sequence 35)

  Mechanism:
    1. Upload the updated formSend.js web resource + PublishXml.
    2. Ensure a staging solution exists and add the APPLICATION RIBBON to it
       (AddSolutionComponent type 50). This makes the export declare the ribbon
       correctly: <RootComponent type="50" schemaName=":RibbonDiffXml" .../>.
    3. Export the staging solution -> a valid shell with an EMPTY <RibbonDiffXml>.
    4. Populate that RibbonDiffXml's empty <CustomActions/>, <CommandDefinitions/>
       and RuleDefinitions <EnableRules/> with our global button + command + rule.
    5. ImportSolution + PublishAllXml.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$ErrorActionPreference = "Stop"
$prefix    = "alex"
$stageName = "alextmpappribbon"
$jsPath    = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\webresources\formSend.js"))
$jsName    = "alex_/scripts/formSend.js"

# Hebrew labels built from code points so they survive any console/transport encoding.
function Heb([int[]]$c) { -join ($c | ForEach-Object { [char]$_ }) }
$label   = Heb @(0x05E9,0x05DC,0x05D9,0x05D7,0x05EA,0x20,0x05DE,0x05E1,0x05DE,0x05DA,0x20,0x65,0x61,0x73,0x79,0x64,0x6F)               # "שליחת מסמך easydo"
$tipDesc = Heb @(0x05E4,0x05EA,0x05D7,0x20,0x05D0,0x05EA,0x20,0x05D0,0x05E9,0x05E3,0x20,0x05E9,0x05DC,0x05D9,0x05D7,0x05EA,0x20,0x05D4,0x05DE,0x05E1,0x05DE,0x05DA,0x20,0x05E9,0x05DC,0x20,0x65,0x61,0x73,0x79,0x64,0x6F)  # "פתח את אשף שליחת המסמך של easydo"

# ---- 1. upload formSend.js + publish -------------------------------------
if (-not (Test-Path $jsPath)) { throw "Web resource not found: $jsPath" }
$jsB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($jsPath))
$wr = (Invoke-DV GET "webresourceset?`$select=webresourceid&`$filter=name eq '$jsName'").value
if (-not $wr -or $wr.Count -eq 0) { throw "Web resource '$jsName' not found - upload it first." }
$wrId = $wr[0].webresourceid
Invoke-DV PATCH "webresourceset($wrId)" -Body @{ content = $jsB64 } | Out-Null
Invoke-DV POST "PublishXml" -Body @{ ParameterXml = "<importexportxml><webresources><webresource>{$wrId}</webresource></webresources></importexportxml>" } | Out-Null
Write-Output "formSend.js uploaded + published ($wrId)"

# ---- 2. ensure staging solution + add the application ribbon to it --------
$pub = (Invoke-DV GET "publishers?`$select=publisherid&`$filter=customizationprefix eq '$prefix'").value[0].publisherid
$s = (Invoke-DV GET "solutions?`$select=solutionid&`$filter=uniquename eq '$stageName'").value
if (-not $s -or $s.Count -eq 0) {
    Invoke-DV POST "solutions" -Body @{ uniquename = $stageName; friendlyname = "easydo app-ribbon staging"; version = "1.0.0.0"; "publisherid@odata.bind" = "/publishers($pub)" } | Out-Null
    Write-Output "Staging solution '$stageName' created"
} else {
    Write-Output "Staging solution '$stageName' exists"
}

# The application ribbon is the org's single UNMANAGED ribboncustomization row
# with no entity. Adding it (type 50) makes the export declare it correctly.
$rc = (Invoke-DV GET "ribboncustomizations?`$filter=entity eq null and ismanaged eq false&`$select=ribboncustomizationid").value
if (-not $rc -or $rc.Count -ne 1) { throw "Expected exactly one unmanaged application ribbon row, found $($rc.Count)." }
$rcId = $rc[0].ribboncustomizationid
try {
    Invoke-DV POST "AddSolutionComponent" -Body @{ ComponentId = $rcId; ComponentType = 50; SolutionUniqueName = $stageName; AddRequiredComponents = $false } -Silent | Out-Null
    Write-Output "Application ribbon added to staging ($rcId)"
} catch {
    Write-Output "Application ribbon already in staging (or add skipped): $rcId"
}

# ---- 3. export the staging shell (now contains an empty RibbonDiffXml) ----
$exp = Invoke-DV POST "ExportSolution" -Body @{ SolutionName = $stageName; Managed = $false }
$zipBytes = [Convert]::FromBase64String($exp.ExportSolutionFile)
Write-Output "Exported staging shell ($($zipBytes.Length) bytes)"

# ---- 4. build the ribbon fragments ---------------------------------------
$btnId  = "alex.global.Form.EasyDoSend.Button"
$caId   = "alex.global.Form.EasyDoSend.CustomAction"
$cmdId  = "alex.global.Form.EasyDoSend.Command"
$ruleId = "alex.global.Form.EasyDoSend.EnableRule"
$loc    = "Mscrm.Form.{!EntityLogicalName}.MainTab.Save.Controls._children"

$customAction = "<CustomAction Id=`"$caId`" Location=`"$loc`" Sequence=`"35`"><CommandUIDefinition><Button Id=`"$btnId`" Command=`"$cmdId`" Sequence=`"35`" LabelText=`"$label`" ToolTipTitle=`"$label`" ToolTipDescription=`"$tipDesc`" TemplateAlias=`"o1`" ModernImage=`"WordTemplates`" /></CommandUIDefinition></CustomAction>"
$commandDef = "<CommandDefinition Id=`"$cmdId`"><EnableRules><EnableRule Id=`"$ruleId`" /></EnableRules><DisplayRules /><Actions><JavaScriptFunction FunctionName=`"EasyDo.FormSend.launch`" Library=`"`$webresource:$jsName`"><CrmParameter Value=`"PrimaryControl`" /></JavaScriptFunction></Actions></CommandDefinition>"
$enableRuleDef = "<EnableRule Id=`"$ruleId`"><CustomRule FunctionName=`"EasyDo.FormSend.isEnabled`" Library=`"`$webresource:$jsName`" Default=`"false`"><CrmParameter Value=`"PrimaryControl`" /></CustomRule></EnableRule>"

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
if ($cust -match [regex]::Escape($caId)) { throw "Global button already present in the exported app ribbon - aborting to avoid duplication." }

# Order matters: populate the (self-closed) RuleDefinitions <EnableRules /> before
# injecting the CommandDefinition, whose own <EnableRules> is NOT self-closed.
$cust = $cust.Replace('<EnableRules />', "<EnableRules>$enableRuleDef</EnableRules>")
$cust = $cust.Replace('<CommandDefinitions />', "<CommandDefinitions>$commandDef</CommandDefinitions>")
$cust = $cust.Replace('<CustomActions />', "<CustomActions>$customAction</CustomActions>")

$entry.Delete()
$fresh = $zip.CreateEntry("customizations.xml")
$writer = New-Object System.IO.StreamWriter($fresh.Open(), (New-Object System.Text.UTF8Encoding($false)))
$writer.Write($cust); $writer.Flush(); $writer.Close()
$zip.Dispose()
$newZip = $ms.ToArray(); $ms.Dispose()
Write-Output "Injected global button into application ribbon ($($newZip.Length) bytes)"

$importId = [guid]::NewGuid().ToString()
Invoke-DV POST "ImportSolution" -Body @{
    OverwriteUnmanagedCustomizations = $true
    PublishWorkflows                 = $false
    CustomizationFile                = [Convert]::ToBase64String($newZip)
    ImportJobId                      = $importId
} | Out-Null
Write-Output "ImportSolution submitted (job $importId)"

Invoke-DV POST "PublishAllXml" | Out-Null
Write-Output "PublishAllXml done. Global easydo form button deployed to the application ribbon."

# ---- 6. consolidate into the main solution + remove staging --------------
# Keep everything in the single shipping solution: ensure the application ribbon
# is also a component of alex_d365_easydo, then drop the temporary staging
# solution so re-runs never leave orphaned staging solutions behind.
$mainName = "alex_d365_easydo"
try {
    Invoke-DV POST "AddSolutionComponent" -Body @{ ComponentId = $rcId; ComponentType = 50; SolutionUniqueName = $mainName; AddRequiredComponents = $false } | Out-Null
    Write-Output "Application ribbon ensured in main solution '$mainName'"
} catch {
    Write-Output "Application ribbon already in '$mainName' (or add skipped): $($_.Exception.Message)"
}
$stage = (Invoke-DV GET "solutions?`$select=solutionid&`$filter=uniquename eq '$stageName'").value
if ($stage -and $stage.Count -gt 0) {
    Invoke-DV DELETE "solutions($($stage[0].solutionid))" | Out-Null
    Write-Output "Staging solution '$stageName' deleted (cleanup)."
}
