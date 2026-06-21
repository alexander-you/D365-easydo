<#
  15-backfill-template-roles-and-sendflag.ps1

  Backfills the new send-wizard template columns on the EXISTING templates:
    - alex_allowsendfromobject = true  (so current templates stay listable in
      the wizard; the new column default only applies to brand-new rows).
    - alex_rolesjson = compact JSON of the easydo signer roles, pulled live from
      GET /entity/me/templates/{externalId} -> payload.roles. The wizard renders
      one recipient slot per role (when 2+ named roles exist).

  Roles JSON shape: [{ "name": "עובד", "sequence": 1, "recipient": true }, ...]
  ordered by sequence. Single/empty generic roles are still written; the wizard
  treats a single role as the classic free-form recipients list.

  Re-runnable.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

$base = "https://api.easydo.co.il/api"
$h = @{ Authorization = "Bearer $env:EASYDOC_TOKEN" }

$templates = (Invoke-DV GET "alex_signaturetemplates?`$select=alex_signaturetemplateid,alex_name,alex_externaltemplateid" -Silent).value
Write-Output ("templates: " + $templates.Count)

foreach ($t in $templates) {
    $ext = $t.alex_externaltemplateid
    $id = $t.alex_signaturetemplateid
    $rolesJson = "[]"
    if ($ext) {
        try {
            $d = Invoke-RestMethod -Uri "$base/entity/me/templates/$ext" -Headers $h -Method GET
            $props = @($d.payload.roles.PSObject.Properties)
            $roles = foreach ($p in $props) {
                $r = $p.Value
                [ordered]@{
                    name      = [string]$r.placeholder.name
                    sequence  = [int]$r.sequence
                    recipient = [bool]$r.recipient
                }
            }
            $roles = @($roles | Sort-Object { $_.sequence })
            $rolesJson = ($roles | ConvertTo-Json -Compress -Depth 4)
            if (-not $rolesJson) { $rolesJson = "[]" }
            # ConvertTo-Json on a single object drops the array brackets; force array.
            if ($roles.Count -eq 1) { $rolesJson = "[" + $rolesJson + "]" }
        } catch {
            Write-Output ("  ! roles fetch failed for $ext : " + $_.Exception.Message)
        }
    }
    Invoke-DV PATCH "alex_signaturetemplates($id)" -Body @{
        alex_allowsendfromobject = $true
        alex_rolesjson           = $rolesJson
    } -Silent | Out-Null
    Write-Output ("  $($t.alex_name) [$ext] -> allowSend=true roles=$rolesJson")
}

Write-Output "Done."
