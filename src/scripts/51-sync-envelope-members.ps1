# 51-sync-envelope-members.ps1
# Populates alex_envelopetemplateitem rows for every envelope template
# (alex_signaturetemplate where alex_isenvelope=true) by reading the envelope
# composition from easydo (GetEnvelope -> templates[]). Idempotent: matches an
# existing member row by (envelope, member external id) and updates it, else creates.
#
# This mirrors the member-sync section of sync-easydoc-templates.flow.json so it can
# be run on demand while the scheduled flow is being fixed.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'dv-common.ps1')
. (Join-Path $here '.env.ps1')
Connect-Dataverse | Out-Null

$apiBase = 'https://api.easydo.co.il/api'
$ez = @{ Authorization = "Bearer $($env:EASYDOC_TOKEN)" }

$envelopes = (Invoke-DV -Method GET -Path "alex_signaturetemplates?`$select=alex_signaturetemplateid,alex_name,alex_externaltemplateid&`$filter=alex_isenvelope eq true" -Silent).value
Write-Host "Envelope templates in Dataverse: $($envelopes.Count)"

$created = 0; $updated = 0

foreach ($env in $envelopes) {
    $envId = $env.alex_signaturetemplateid
    $extId = $env.alex_externaltemplateid
    Write-Host "`n== $($env.alex_name) (ext $extId) =="
    if ([string]::IsNullOrWhiteSpace($extId)) { Write-Host "  no external id, skip"; continue }

    try {
        $detail = Invoke-RestMethod -Method GET -Uri "$apiBase/entity/me/envelopes/$extId" -Headers $ez
    } catch {
        Write-Host "  GetEnvelope failed: $($_.Exception.Message)"; continue
    }

    $members = @($detail.templates)
    Write-Host "  members from easydo: $($members.Count)"

    foreach ($m in $members) {
        $memberExtId = [string]$m.id
        $memberName = if ([string]::IsNullOrWhiteSpace([string]$m.name)) { $memberExtId } else { [string]$m.name }
        $sequence = if ($null -eq $m.sequence) { 0 } else { [int]$m.sequence }
        $roleId = 0
        $firstAssignee = @($m.assignees) | Select-Object -First 1
        if ($firstAssignee) {
            if ($null -ne $firstAssignee.role_id) { $roleId = [int]$firstAssignee.role_id }
            elseif ($null -ne $firstAssignee.template_role_id) { $roleId = [int]$firstAssignee.template_role_id }
        }

        # resolve local member template (for the TemplateId lookup) by external id
        $localTemplate = (Invoke-DV -Method GET -Path "alex_signaturetemplates?`$select=alex_signaturetemplateid&`$filter=alex_externaltemplateid eq '$memberExtId'" -Silent).value | Select-Object -First 1

        $body = [ordered]@{
            'alex_name'              = $memberName
            'alex_externaltemplateid' = $memberExtId
            'alex_sequence'          = $sequence
            'alex_defaultroleid'     = $roleId
            'alex_lastsyncedon'      = (Get-Date).ToUniversalTime().ToString('o')
        }
        if ($localTemplate) {
            $body['alex_TemplateId@odata.bind'] = "/alex_signaturetemplates($($localTemplate.alex_signaturetemplateid))"
        }

        $existing = (Invoke-DV -Method GET -Path "alex_envelopetemplateitems?`$select=alex_envelopetemplateitemid&`$filter=_alex_envelopeid_value eq $envId and alex_externaltemplateid eq '$memberExtId'" -Silent).value | Select-Object -First 1

        if ($existing) {
            Invoke-DV PATCH "alex_envelopetemplateitems($($existing.alex_envelopetemplateitemid))" -Body $body | Out-Null
            $updated++
            Write-Host "  ~ updated: $memberName (seq $sequence, role $roleId)"
        } else {
            $body['alex_EnvelopeId@odata.bind'] = "/alex_signaturetemplates($envId)"
            Invoke-DV POST "alex_envelopetemplateitems" -Body $body | Out-Null
            $created++
            Write-Host "  + created: $memberName (seq $sequence, role $roleId)"
        }
    }
}

Write-Host "`nDone. created=$created updated=$updated"
