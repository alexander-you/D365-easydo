<#
  32-register-tenant-contract-plugin.ps1

  Registers TenantContractCalcPlugin (in the shared EasyDo.Plugins assembly) and
  wires two pre-operation, synchronous SDK steps on alex_tenant_contract:

      Create  -> compute alex_n_contract_months + alex_m_total_contract
      Update  -> same, filtered to alex_dt_start, alex_dt_end, alex_m_monthly_rent

  The plug-in fills the two derived columns in-pipeline so they behave like
  calculated fields (the form shows them read-only). The steps are added to the
  PropertyAllocationBoard solution (the table's home); the assembly/type live in
  the shared alex_d365_easydo assembly.

  Idempotent. Build the assembly first:
      dotnet build src/plugins/EasyDo.Plugins -c Release
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$ErrorActionPreference = "Stop"
$Table   = "alex_tenant_contract"
$sol     = "PropertyAllocationBoard"
$solHeader = @{ "MSCRM.SolutionUniqueName" = $sol }

# ---- 1) upload / upsert the built assembly ------------------------------
$dll = Join-Path $PSScriptRoot "..\plugins\EasyDo.Plugins\bin\Release\net462\EasyDo.Plugins.dll"
$dll = [System.IO.Path]::GetFullPath($dll)
if (-not (Test-Path $dll)) { throw "Assembly not found: $dll  (build it first: dotnet build src/plugins/EasyDo.Plugins -c Release)" }

$an      = [System.Reflection.AssemblyName]::GetAssemblyName($dll)
$version = $an.Version.ToString()
$culture = if ($an.CultureName) { $an.CultureName } else { "neutral" }
$token   = ($an.GetPublicKeyToken() | ForEach-Object { $_.ToString("x2") }) -join ""
$content = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($dll))
$asmName = "EasyDo.Plugins"

$existingAsm = (Invoke-DV GET "pluginassemblies?`$select=pluginassemblyid&`$filter=name eq '$asmName'").value
$asmBody = @{ name = $asmName; content = $content; culture = $culture; version = $version; publickeytoken = $token; sourcetype = 0; isolationmode = 2 }
if ($existingAsm -and $existingAsm.Count -gt 0) {
    $asmId = $existingAsm[0].pluginassemblyid
    Invoke-DV PATCH "pluginassemblies($asmId)" -Body $asmBody | Out-Null
    Write-Output "Updated assembly $asmId (v$version)"
} else {
    $r = Invoke-DV POST "pluginassemblies" -Body $asmBody -ReturnHeaders
    $asmId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "Created assembly $asmId (v$version)"
}

# ---- 2) plugin type (upsert) --------------------------------------------
$typeName = "EasyDo.Plugins.TenantContractCalcPlugin"
$f = (Invoke-DV GET "plugintypes?`$select=plugintypeid&`$filter=typename eq '$typeName'").value
if ($f -and $f.Count -gt 0) {
    $typeId = $f[0].plugintypeid
    Invoke-DV PATCH "plugintypes($typeId)" -Body @{ friendlyname = "EasyDo Tenant Contract Calc" } | Out-Null
    Write-Output "  type exists $typeName ($typeId)"
} else {
    $r = Invoke-DV POST "plugintypes" -Body @{
        typename = $typeName; friendlyname = "EasyDo Tenant Contract Calc"; name = $typeName
        "pluginassemblyid@odata.bind" = "/pluginassemblies($asmId)"
    } -ReturnHeaders
    $typeId = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
    Write-Output "  + type $typeName ($typeId)"
}

# ---- 3) SDK steps: pre-operation, synchronous on Create + Update --------
function Set-CalcStep {
    param([string]$MessageName, [string]$FilteringAttributes)
    $msgId = (Invoke-DV GET "sdkmessages?`$select=sdkmessageid&`$filter=name eq '$MessageName'").value[0].sdkmessageid
    $flt = (Invoke-DV GET ("sdkmessagefilters?`$select=sdkmessagefilterid&`$filter=" +
        "_sdkmessageid_value eq $msgId and primaryobjecttypecode eq '$Table'")).value
    $name = "EasyDo TenantContractCalc: $Table $MessageName"
    $body = @{
        name                = $name
        "sdkmessageid@odata.bind" = "/sdkmessages($msgId)"
        "plugintypeid@odata.bind" = "/plugintypes($typeId)"
        stage               = 20    # pre-operation
        mode                = 0     # synchronous
        rank                = 1
        supporteddeployment = 0     # server only
        description         = "Computes alex_n_contract_months and alex_m_total_contract in-pipeline."
    }
    if ($FilteringAttributes) { $body["filteringattributes"] = $FilteringAttributes }
    if ($flt -and $flt.Count -gt 0) { $body["sdkmessagefilterid@odata.bind"] = "/sdkmessagefilters($($flt[0].sdkmessagefilterid))" }
    $ex = (Invoke-DV GET "sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid&`$filter=name eq '$([uri]::EscapeDataString($name))'").value
    if ($ex -and $ex.Count -gt 0) {
        $id = $ex[0].sdkmessageprocessingstepid
        $patch = $body.Clone(); $patch.Remove("sdkmessageid@odata.bind"); $patch.Remove("plugintypeid@odata.bind")
        Invoke-DV PATCH "sdkmessageprocessingsteps($id)" -Body $patch | Out-Null
        Write-Output "  step exists $MessageName ($id), updated"
    } else {
        $r = Invoke-DV POST "sdkmessageprocessingsteps" -Body $body -ExtraHeaders $solHeader -ReturnHeaders
        $id = ($r.Headers["OData-EntityId"] -replace '.*\(([0-9a-fA-F-]+)\).*', '$1')
        Write-Output "  + step $MessageName ($id)"
    }
}
Set-CalcStep -MessageName "Create"
Set-CalcStep -MessageName "Update" -FilteringAttributes "alex_dt_start,alex_dt_end,alex_m_monthly_rent"

Write-Output "Done. TenantContractCalcPlugin registered on $Table."
