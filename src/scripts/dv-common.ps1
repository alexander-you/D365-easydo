<#
  Dataverse Web API helper for the D365 Easydo solution build.

  Authentication only is obtained via Azure CLI; ALL metadata creation
  (tables, columns, relationships, choices, forms, views, solution) is performed
  through the Dataverse Web API per project requirements.

  No secrets are stored in this file. The access token is acquired at runtime.

  Usage:
    . .\src\scripts\dv-common.ps1
    Connect-Dataverse
    Invoke-DV GET "WhoAmI"

  Set the environment URL via $env:DV_URL or a git-ignored src/scripts/.env.ps1
  (copy from .env.example.ps1). The URL is never committed to the repository.
#>

# The Dataverse environment URL is NOT stored in the repository.
# Provide it via the DV_URL environment variable, or a local, git-ignored
# src/scripts/.env.ps1 file that sets $env:DV_URL.
$envFile = Join-Path $PSScriptRoot ".env.ps1"
if (Test-Path $envFile) { . $envFile }
$script:DV_URL = $env:DV_URL
if (-not $script:DV_URL) {
    throw "DV_URL is not set. Set `$env:DV_URL to your Dataverse environment URL, or create src/scripts/.env.ps1 (git-ignored)."
}
$script:DV_URL = $script:DV_URL.TrimEnd('/')
$script:DV_API = "$script:DV_URL/api/data/v9.2"
$script:DV_TOKEN = $null

function Connect-Dataverse {
    [CmdletBinding()]
    param()
    $script:DV_TOKEN = az account get-access-token --resource "$script:DV_URL/" --query "accessToken" -o tsv
    if (-not $script:DV_TOKEN) { throw "Failed to acquire Dataverse access token via az." }
    Write-Host "Connected to $script:DV_URL (token length $($script:DV_TOKEN.Length))"
}

function Get-DVHeaders {
    return @{
        Authorization        = "Bearer $script:DV_TOKEN"
        Accept               = "application/json"
        "OData-MaxVersion"   = "4.0"
        "OData-Version"      = "4.0"
        "Content-Type"       = "application/json; charset=utf-8"
        "Consistency"        = "Strong"
    }
}

function Invoke-DV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PATCH','PUT','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body,
        [hashtable]$ExtraHeaders,
        [switch]$ReturnHeaders,
        [switch]$Silent
    )
    if (-not $script:DV_TOKEN) { Connect-Dataverse }
    $headers = Get-DVHeaders
    if ($ExtraHeaders) { $ExtraHeaders.GetEnumerator() | ForEach-Object { $headers[$_.Key] = $_.Value } }
    $uri = if ($Path -match '^https?://') { $Path } else { "$script:DV_API/$Path" }
    $params = @{ Method = $Method; Uri = $uri; Headers = $headers; ErrorAction = 'Stop' }
    if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 30 -Compress)
    }
    try {
        $resp = Invoke-WebRequest @params
        $result = $null
        if ($resp.Content) { try { $result = $resp.Content | ConvertFrom-Json } catch { $result = $resp.Content } }
        if ($ReturnHeaders) { return [pscustomobject]@{ Body = $result; Headers = $resp.Headers; Status = [int]$resp.StatusCode } }
        return $result
    }
    catch {
        $msg = $_.Exception.Message
        $detail = $null
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
        if (-not $Silent) {
            Write-Host "DV ERROR ($Method $Path): $msg" -ForegroundColor Red
            if ($detail) { Write-Host $detail -ForegroundColor DarkYellow }
        }
        throw
    }
}

# Build a localized label (English 1033 + Hebrew 1037) for Dataverse metadata.
function New-DVLabel {
    param([Parameter(Mandatory)][string]$En, [Parameter(Mandatory)][string]$He)
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.Label"
        LocalizedLabels = @(
            @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $En; LanguageCode = 1033 },
            @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $He; LanguageCode = 1037 }
        )
    }
}
