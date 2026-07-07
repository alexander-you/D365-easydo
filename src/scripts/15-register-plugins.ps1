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
$anchorTypeId    = Set-PluginType -TypeName "EasyDo.Plugins.PopulateAnchorPlugin" -Friendly "EasyDo Populate Anchor"
$wizardTypeId    = Set-PluginType -TypeName "EasyDo.Plugins.WizardIntakePlugin"   -Friendly "EasyDo Wizard Intake"
$ensureLookupTypeId = Set-PluginType -TypeName "EasyDo.Plugins.EnsureSignatureLookupPlugin" -Friendly "EasyDo Ensure Signature Lookup"

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

# ---- 5. SDK steps: PopulateAnchor on Create + Update of alex_signaturerequest ----
# Pre-operation, synchronous: fills alex_primaryrecordid from the launch context
# (alex_relatedtablename + alex_relatedrecordid, or the related contact) so the
# anchor is set automatically without the maker having to populate it.
function Set-AnchorStep {
    param([string]$MessageName, [string]$FilteringAttributes)
    $msgId = (Invoke-DV GET "sdkmessages?`$select=sdkmessageid&`$filter=name eq '$MessageName'").value[0].sdkmessageid
    $flt = (Invoke-DV GET ("sdkmessagefilters?`$select=sdkmessagefilterid&`$filter=" +
        "_sdkmessageid_value eq $msgId and primaryobjecttypecode eq 'alex_signaturerequest'")).value
    $name = "EasyDo PopulateAnchor: alex_signaturerequest $MessageName"
    $body = @{
        name                = $name
        "sdkmessageid@odata.bind" = "/sdkmessages($msgId)"
        "plugintypeid@odata.bind" = "/plugintypes($anchorTypeId)"
        stage               = 20    # pre-operation
        mode                = 0     # synchronous
        rank                = 1
        supporteddeployment = 0     # server only
        description         = "Auto-fills alex_primaryrecordid from the request's launch context."
    }
    if ($FilteringAttributes) { $body["filteringattributes"] = $FilteringAttributes }
    if ($flt -and $flt.Count -gt 0) { $body["sdkmessagefilterid@odata.bind"] = "/sdkmessagefilters($($flt[0].sdkmessagefilterid))" }
    $ex = (Invoke-DV GET "sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid&`$filter=name eq '$([uri]::EscapeDataString($name))'").value
    if ($ex -and $ex.Count -gt 0) {
        $id = $ex[0].sdkmessageprocessingstepid
        $patch = $body.Clone(); $patch.Remove("sdkmessageid@odata.bind"); $patch.Remove("plugintypeid@odata.bind")
        Invoke-DV PATCH "sdkmessageprocessingsteps($id)" -Body $patch | Out-Null
        Write-Output "  anchor step exists $MessageName ($id), updated"
    } else {
        $r = Invoke-DV POST "sdkmessageprocessingsteps" -Body $body -ExtraHeaders $solHeader -ReturnHeaders
        $id = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
        Write-Output "  + anchor step $MessageName ($id)"
    }
}
Set-AnchorStep -MessageName "Create"
Set-AnchorStep -MessageName "Update" -FilteringAttributes "alex_relatedrecordid,alex_relatedtablename,alex_relatedcontactid,alex_templateid"

# ---- 6. SDK steps: WizardIntake on Create of alex_signaturerequest ----
# The send wizard (PCF on a custom page) writes its full JSON into
# alex_wizardpayload on a new request. This plug-in turns that JSON into a real
# request without the page having to address columns/choices by display name:
#   PreValidation (stage 10): resolve template + related fields onto the Target
#                             BEFORE PopulateAnchor (stage 20) reads them.
#   PostOperation (stage 40): create recipient rows and flip status to
#                             Ready to Send (fires the send flow).
function Set-WizardStep {
    param([int]$Stage, [string]$NameSuffix)
    $msgId = (Invoke-DV GET "sdkmessages?`$select=sdkmessageid&`$filter=name eq 'Create'").value[0].sdkmessageid
    $flt = (Invoke-DV GET ("sdkmessagefilters?`$select=sdkmessagefilterid&`$filter=" +
        "_sdkmessageid_value eq $msgId and primaryobjecttypecode eq 'alex_signaturerequest'")).value
    $name = "EasyDo WizardIntake: alex_signaturerequest Create ($NameSuffix)"
    $body = @{
        name                = $name
        "sdkmessageid@odata.bind" = "/sdkmessages($msgId)"
        "plugintypeid@odata.bind" = "/plugintypes($wizardTypeId)"
        stage               = $Stage
        mode                = 0     # synchronous
        rank                = 1
        supporteddeployment = 0     # server only
        description         = "Parses alex_wizardpayload (send wizard JSON) into a full signature request."
    }
    if ($flt -and $flt.Count -gt 0) { $body["sdkmessagefilterid@odata.bind"] = "/sdkmessagefilters($($flt[0].sdkmessagefilterid))" }
    $ex = (Invoke-DV GET "sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid&`$filter=name eq '$([uri]::EscapeDataString($name))'").value
    if ($ex -and $ex.Count -gt 0) {
        $id = $ex[0].sdkmessageprocessingstepid
        $patch = $body.Clone(); $patch.Remove("sdkmessageid@odata.bind"); $patch.Remove("plugintypeid@odata.bind")
        Invoke-DV PATCH "sdkmessageprocessingsteps($id)" -Body $patch | Out-Null
        Write-Output "  wizard step exists $NameSuffix ($id), updated"
    } else {
        $r = Invoke-DV POST "sdkmessageprocessingsteps" -Body $body -ExtraHeaders $solHeader -ReturnHeaders
        $id = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
        Write-Output "  + wizard step $NameSuffix ($id)"
    }
}
Set-WizardStep -Stage 10 -NameSuffix "PreValidation"
Set-WizardStep -Stage 40 -NameSuffix "PostOperation"

# ---- 7. Custom API: alex_AttachSignedPdf --------------------------------
# Creates the signed-PDF note on the request's PRIMARY business record (contact /
# entitlement / ...), called by the read-back flow instead of attaching to the
# signature request itself.
$attachTypeId = Set-PluginType -TypeName "EasyDo.Plugins.AttachSignedPdfPlugin" -Friendly "EasyDo Attach Signed PDF"
$attachApiName = "alex_AttachSignedPdf"
$attachApiBody = @{
    uniquename       = $attachApiName
    name             = "AttachSignedPdf"
    displayname      = "Attach Signed PDF"
    description      = "Attaches the signed PDF as a note on the signature request's primary business record."
    bindingtype      = 0       # Global
    isfunction       = $false
    isprivate        = $false
    allowedcustomprocessingsteptype = 0
    "PluginTypeId@odata.bind" = "/plugintypes($attachTypeId)"
}
$existingAttachApi = (Invoke-DV GET "customapis?`$select=customapiid&`$filter=uniquename eq '$attachApiName'").value
if ($existingAttachApi -and $existingAttachApi.Count -gt 0) {
    $attachApiId = $existingAttachApi[0].customapiid
    Invoke-DV PATCH "customapis($attachApiId)" -Body @{ "PluginTypeId@odata.bind" = "/plugintypes($attachTypeId)"; description = $attachApiBody.description } | Out-Null
    Write-Output "Custom API exists ($attachApiId), relinked"
} else {
    $r = Invoke-DV POST "customapis" -Body $attachApiBody -ExtraHeaders $solHeader -ReturnHeaders
    $attachApiId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "+ Custom API alex_AttachSignedPdf ($attachApiId)"
}
function Set-AttachReqParam {
    param([string]$UniqueName, [string]$Name, [int]$Type, [bool]$Optional)
    $f = (Invoke-DV GET "customapirequestparameters?`$select=customapirequestparameterid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $attachApiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  req param exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name
        type = $Type; isoptional = $Optional
        "CustomAPIId@odata.bind" = "/customapis($attachApiId)"
    }
    Invoke-DV POST "customapirequestparameters" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + req param $UniqueName"
}
function Set-AttachRespProp {
    param([string]$UniqueName, [string]$Name, [int]$Type)
    $f = (Invoke-DV GET "customapiresponseproperties?`$select=customapiresponsepropertyid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $attachApiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  resp prop exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name; type = $Type
        "CustomAPIId@odata.bind" = "/customapis($attachApiId)"
    }
    Invoke-DV POST "customapiresponseproperties" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + resp prop $UniqueName"
}
# Type 10 = String
Set-AttachReqParam -UniqueName "SignatureRequestId" -Name "SignatureRequestId" -Type 10 -Optional $false
Set-AttachReqParam -UniqueName "FileName"           -Name "FileName"           -Type 10 -Optional $true
Set-AttachReqParam -UniqueName "FileContent"        -Name "FileContent"        -Type 10 -Optional $false
Set-AttachRespProp -UniqueName "AnnotationId"       -Name "AnnotationId"        -Type 10

# ---- 8. Custom API: alex_EnsureSignatureLookup --------------------------
# Provisions the dedicated native lookup (alex_Related<table>Id) from the
# signature request back to a primary business table, so that table can show a
# subgrid of its signature requests. Called by the admin center when an admin
# enables a NEW table for sending (after an explicit "this is irreversible"
# confirmation). Metadata create is done server-side for reliability.
$ensureApiName = "alex_EnsureSignatureLookup"
$ensureApiBody = @{
    uniquename       = $ensureApiName
    name             = "EnsureSignatureLookup"
    displayname      = "Ensure Signature Lookup"
    description      = "Provisions the dedicated native lookup from the signature request back to a primary business table (idempotent)."
    bindingtype      = 0       # Global
    isfunction       = $false
    isprivate        = $false
    allowedcustomprocessingsteptype = 0
    "PluginTypeId@odata.bind" = "/plugintypes($ensureLookupTypeId)"
}
$existingEnsureApi = (Invoke-DV GET "customapis?`$select=customapiid&`$filter=uniquename eq '$ensureApiName'").value
if ($existingEnsureApi -and $existingEnsureApi.Count -gt 0) {
    $ensureApiId = $existingEnsureApi[0].customapiid
    Invoke-DV PATCH "customapis($ensureApiId)" -Body @{ "PluginTypeId@odata.bind" = "/plugintypes($ensureLookupTypeId)"; description = $ensureApiBody.description } | Out-Null
    Write-Output "Custom API exists ($ensureApiId), relinked"
} else {
    $r = Invoke-DV POST "customapis" -Body $ensureApiBody -ExtraHeaders $solHeader -ReturnHeaders
    $ensureApiId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "+ Custom API alex_EnsureSignatureLookup ($ensureApiId)"
}
function Set-EnsureReqParam {
    param([string]$UniqueName, [string]$Name, [int]$Type, [bool]$Optional)
    $f = (Invoke-DV GET "customapirequestparameters?`$select=customapirequestparameterid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $ensureApiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  req param exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name
        type = $Type; isoptional = $Optional
        "CustomAPIId@odata.bind" = "/customapis($ensureApiId)"
    }
    Invoke-DV POST "customapirequestparameters" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + req param $UniqueName"
}
function Set-EnsureRespProp {
    param([string]$UniqueName, [string]$Name, [int]$Type)
    $f = (Invoke-DV GET "customapiresponseproperties?`$select=customapiresponsepropertyid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $ensureApiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  resp prop exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name; type = $Type
        "CustomAPIId@odata.bind" = "/customapis($ensureApiId)"
    }
    Invoke-DV POST "customapiresponseproperties" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + resp prop $UniqueName"
}
# Type 10 = String, Type 0 = Boolean
Set-EnsureReqParam -UniqueName "TableLogicalName"       -Name "TableLogicalName"       -Type 10 -Optional $false
Set-EnsureRespProp -UniqueName "RelationshipSchemaName" -Name "RelationshipSchemaName" -Type 10
Set-EnsureRespProp -UniqueName "LookupLogicalName"      -Name "LookupLogicalName"      -Type 10
Set-EnsureRespProp -UniqueName "Created"                -Name "Created"                -Type 0

# ---- 9. Custom API: alex_AutoMapTemplateFields --------------------------
# Given a template, resolves every field mapping's export name
# (alex_externalexportname) into a Dynamics binding (alex_dynamicstable /
# alex_dynamicsfield / alex_lookupfield). Overwrites every row it can resolve.
# Called by the "Auto-map fields" ribbon button on the template form.
$autoMapTypeId = Set-PluginType -TypeName "EasyDo.Plugins.AutoMapTemplateFieldsPlugin" -Friendly "EasyDo Auto-Map Template Fields"
$autoMapApiName = "alex_AutoMapTemplateFields"
$autoMapApiBody = @{
    uniquename       = $autoMapApiName
    name             = "AutoMapTemplateFields"
    displayname      = "Auto-Map Template Fields"
    description      = "Resolves each template field mapping's export name to a Dynamics table.column binding. Overwrites every row it can resolve."
    bindingtype      = 0       # Global
    isfunction       = $false
    isprivate        = $false
    allowedcustomprocessingsteptype = 0
    "PluginTypeId@odata.bind" = "/plugintypes($autoMapTypeId)"
}
$existingAutoMapApi = (Invoke-DV GET "customapis?`$select=customapiid&`$filter=uniquename eq '$autoMapApiName'").value
if ($existingAutoMapApi -and $existingAutoMapApi.Count -gt 0) {
    $autoMapApiId = $existingAutoMapApi[0].customapiid
    Invoke-DV PATCH "customapis($autoMapApiId)" -Body @{ "PluginTypeId@odata.bind" = "/plugintypes($autoMapTypeId)"; description = $autoMapApiBody.description } | Out-Null
    Write-Output "Custom API exists ($autoMapApiId), relinked"
} else {
    $r = Invoke-DV POST "customapis" -Body $autoMapApiBody -ExtraHeaders $solHeader -ReturnHeaders
    $autoMapApiId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "+ Custom API alex_AutoMapTemplateFields ($autoMapApiId)"
}
function Set-AutoMapReqParam {
    param([string]$UniqueName, [string]$Name, [int]$Type, [bool]$Optional)
    $f = (Invoke-DV GET "customapirequestparameters?`$select=customapirequestparameterid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $autoMapApiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  req param exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name
        type = $Type; isoptional = $Optional
        "CustomAPIId@odata.bind" = "/customapis($autoMapApiId)"
    }
    Invoke-DV POST "customapirequestparameters" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + req param $UniqueName"
}
function Set-AutoMapRespProp {
    param([string]$UniqueName, [string]$Name, [int]$Type)
    $f = (Invoke-DV GET "customapiresponseproperties?`$select=customapiresponsepropertyid&`$filter=uniquename eq '$UniqueName' and _customapiid_value eq $autoMapApiId").value
    if ($f -and $f.Count -gt 0) { Write-Output "  resp prop exists $UniqueName"; return }
    $body = @{
        uniquename = $UniqueName; name = $Name; displayname = $Name; type = $Type
        "CustomAPIId@odata.bind" = "/customapis($autoMapApiId)"
    }
    Invoke-DV POST "customapiresponseproperties" -Body $body -ExtraHeaders $solHeader | Out-Null
    Write-Output "  + resp prop $UniqueName"
}
# Type 10 = String, Type 7 = Integer
Set-AutoMapReqParam -UniqueName "TemplateId" -Name "TemplateId" -Type 10 -Optional $false
Set-AutoMapRespProp -UniqueName "Matched"    -Name "Matched"    -Type 7
Set-AutoMapRespProp -UniqueName "Skipped"    -Name "Skipped"    -Type 7
Set-AutoMapRespProp -UniqueName "Message"    -Name "Message"    -Type 10

Write-Output "Done."
