<#
  15-register-plugins.ps1

  Registers the EasyDo.Plugins assembly and its two plug-in types into the
  alex_d365_easydo solution, then wires:

    WriteBackPlugin       -> SDK step on Update of alex_signaturerequest
                             (post-operation, asynchronous, filter alex_status).
                             Writes recipient answers back to Dynamics when a
                             request becomes Completed.

    ResolvePrefillPlugin  -> Custom API  alex_ResolvePrefill (global, action)
                             In  : SignatureRequestId (String)
                             Out : PrefillData        (String, JSON)
                             Returns the prefill_data the send flow passes to
                             easydo, read from the mapped source records.

  Idempotent: every component is looked up first and updated in place if it
  already exists. Build the assembly first:
      dotnet build src/plugins/EasyDo.Plugins -c Release
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$ErrorActionPreference = "Stop"
$sol = "alex_d365_easydo"
$solHeader = @{ "MSCRM.SolutionUniqueName" = $sol }

# ---- locate the built assembly ------------------------------------------
$dll = Join-Path $PSScriptRoot "..\plugins\EasyDo.Plugins\bin\Release\net462\EasyDo.Plugins.dll"
$dll = [System.IO.Path]::GetFullPath($dll)
if (-not (Test-Path $dll)) { throw "Assembly not found: $dll  (build it first: dotnet build src/plugins/EasyDo.Plugins -c Release)" }

$an       = [System.Reflection.AssemblyName]::GetAssemblyName($dll)
$version  = $an.Version.ToString()
$culture  = if ($an.CultureName) { $an.CultureName } else { "neutral" }
$token    = ($an.GetPublicKeyToken() | ForEach-Object { $_.ToString("x2") }) -join ""
$content  = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($dll))
$asmName  = "EasyDo.Plugins"
Write-Output "Assembly $asmName v$version culture=$culture token=$token ($([Math]::Round(((Get-Item $dll).Length/1kb),1)) KB)"

# ---- 1. plugin assembly (upsert) ----------------------------------------
$existing = (Invoke-DV GET "pluginassemblies?`$select=pluginassemblyid&`$filter=name eq '$asmName'").value
$asmBody = @{
    name           = $asmName
    content        = $content
    culture        = $culture
    version        = $version
    publickeytoken = $token
    sourcetype     = 0   # Database
    isolationmode  = 2   # Sandbox
}
if ($existing -and $existing.Count -gt 0) {
    $asmId = $existing[0].pluginassemblyid
    Invoke-DV PATCH "pluginassemblies($asmId)" -Body $asmBody | Out-Null
    Write-Output "Updated assembly $asmId"
} else {
    $r = Invoke-DV POST "pluginassemblies" -Body $asmBody -ExtraHeaders $solHeader -ReturnHeaders
    $asmId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "Created assembly $asmId"
}

# ---- 2. plugin types (upsert) -------------------------------------------
function Set-PluginType {
    param([string]$TypeName, [string]$Friendly)
    $f = (Invoke-DV GET "plugintypes?`$select=plugintypeid&`$filter=typename eq '$TypeName'").value
    $body = @{
        typename      = $TypeName
        friendlyname  = $Friendly
        name          = $TypeName
        "pluginassemblyid@odata.bind" = "/pluginassemblies($asmId)"
    }
    if ($f -and $f.Count -gt 0) {
        $id = $f[0].plugintypeid
        Invoke-DV PATCH "plugintypes($id)" -Body @{ friendlyname = $Friendly } | Out-Null
        Write-Host "  type exists $TypeName ($id)"
        return $id
    }
    $r = Invoke-DV POST "plugintypes" -Body $body -ExtraHeaders $solHeader -ReturnHeaders
    $id = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Host "  + type $TypeName ($id)"
    return $id
}
$writeBackTypeId = Set-PluginType -TypeName "EasyDo.Plugins.WriteBackPlugin"      -Friendly "EasyDo Write-Back"
$prefillTypeId   = Set-PluginType -TypeName "EasyDo.Plugins.ResolvePrefillPlugin" -Friendly "EasyDo Resolve Prefill"

# ---- 3. SDK step: WriteBack on Update of alex_signaturerequest ----------
$updateMsgId = (Invoke-DV GET "sdkmessages?`$select=sdkmessageid&`$filter=name eq 'Update'").value[0].sdkmessageid
$filter = (Invoke-DV GET ("sdkmessagefilters?`$select=sdkmessagefilterid&`$filter=" +
    "_sdkmessageid_value eq $updateMsgId and primaryobjecttypecode eq 'alex_signaturerequest'")).value
$stepName = "EasyDo WriteBack: alex_signaturerequest Update"
$stepBody = @{
    name                 = $stepName
    "sdkmessageid@odata.bind"  = "/sdkmessages($updateMsgId)"
    "plugintypeid@odata.bind"  = "/plugintypes($writeBackTypeId)"
    stage                = 40    # post-operation
    mode                 = 1     # asynchronous
    rank                 = 1
    supporteddeployment  = 0     # server only
    filteringattributes  = "alex_status"
    asyncautodelete      = $true
    description          = "Writes recipient answers back to Dynamics when a signature request is Completed."
}
if ($filter -and $filter.Count -gt 0) {
    $stepBody["sdkmessagefilterid@odata.bind"] = "/sdkmessagefilters($($filter[0].sdkmessagefilterid))"
}
$existingStep = (Invoke-DV GET "sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid&`$filter=name eq '$([uri]::EscapeDataString($stepName))'").value
if ($existingStep -and $existingStep.Count -gt 0) {
    $stepId = $existingStep[0].sdkmessageprocessingstepid
    $patch = $stepBody.Clone(); $patch.Remove("sdkmessageid@odata.bind"); $patch.Remove("plugintypeid@odata.bind")
    Invoke-DV PATCH "sdkmessageprocessingsteps($stepId)" -Body $patch | Out-Null
    Write-Output "  step exists ($stepId), updated"
} else {
    $r = Invoke-DV POST "sdkmessageprocessingsteps" -Body $stepBody -ExtraHeaders $solHeader -ReturnHeaders
    $stepId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "  + step ($stepId)"
}

# ---- 4. Custom API: alex_ResolvePrefill ---------------------------------
$apiName = "alex_ResolvePrefill"
$apiBody = @{
    uniquename       = $apiName
    name             = "ResolvePrefill"
    displayname      = "Resolve Prefill"
    description      = "Returns the easydo prefill_data (JSON) for a signature request, read from the mapped Dynamics source records."
    bindingtype      = 0       # Global
    isfunction       = $false
    isprivate        = $false
    allowedcustomprocessingsteptype = 0   # None
    "PluginTypeId@odata.bind" = "/plugintypes($prefillTypeId)"
}
$existingApi = (Invoke-DV GET "customapis?`$select=customapiid&`$filter=uniquename eq '$apiName'").value
if ($existingApi -and $existingApi.Count -gt 0) {
    $apiId = $existingApi[0].customapiid
    Invoke-DV PATCH "customapis($apiId)" -Body @{ "PluginTypeId@odata.bind" = "/plugintypes($prefillTypeId)"; description = $apiBody.description } | Out-Null
    Write-Output "Custom API exists ($apiId), relinked"
} else {
    $r = Invoke-DV POST "customapis" -Body $apiBody -ExtraHeaders $solHeader -ReturnHeaders
    $apiId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "+ Custom API alex_ResolvePrefill ($apiId)"
}

function Set-ApiRequestParam {
    param([string]$UniqueName, [string]$Name, [int]$Type, [bool]$Optional)
    $f = (Invoke-DV GET "customapirequestparameters?`$select=customapirequestparameterid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $apiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  req param exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name
        type = $Type; isoptional = $Optional
        "CustomAPIId@odata.bind" = "/customapis($apiId)"
    }
    Invoke-DV POST "customapirequestparameters" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + req param $UniqueName"
}
function Set-ApiResponseProp {
    param([string]$UniqueName, [string]$Name, [int]$Type)
    $f = (Invoke-DV GET "customapiresponseproperties?`$select=customapiresponsepropertyid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $apiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  resp prop exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name; type = $Type
        "CustomAPIId@odata.bind" = "/customapis($apiId)"
    }
    Invoke-DV POST "customapiresponseproperties" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + resp prop $UniqueName"
}
# Type 10 = String
Set-ApiRequestParam -UniqueName "SignatureRequestId" -Name "SignatureRequestId" -Type 10 -Optional $false
Set-ApiResponseProp -UniqueName "PrefillData"        -Name "PrefillData"        -Type 10

Write-Output "Done."
