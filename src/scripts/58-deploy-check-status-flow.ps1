<#
  58-deploy-check-status-flow.ps1

  Creates + activates the on-demand "Check Signature Status" cloud flow.

  This flow is a DERIVATIVE of read-signature-results.flow.json (the 5-minute
  poller). It reuses that flow's proven single-form AND envelope read-back logic
  verbatim - only three things change:

    1. Trigger: Recurrence (every 5 min)  ->  SubscribeWebhookTrigger on
       alex_signaturerequest, filtering attribute alex_statuscheckrequestedon.
       The Documents PCF "Check status" button stamps that column, firing this
       flow for ONE request on demand.

    2. Both "list open ..." steps are scoped to the single triggering request id
       (single branch matches by alex_externalformid, envelope branch by
       alex_externalenvelopeid - only the relevant one returns a row).

    3. A final step stamps alex_statuschecklastrunon / alex_statuscheckstatus.

  Because the read-back bodies are identical to the poller, there is no risk of
  marking a request Completed without downloading its signed PDF.

  The derived definition is written to src/flows/check-signature-status.flow.json
  (so the repo has the artefact) and then deployed. Idempotent: updates the
  existing flow by name.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

$name       = 'Check Signature Status'
$flowDir    = Join-Path (Split-Path $PSScriptRoot -Parent) 'flows'
$sourceFile = Join-Path $flowDir 'read-signature-results.flow.json'
$outFile    = Join-Path $flowDir 'check-signature-status.flow.json'

# ---- 1) load the poller definition --------------------------------------
$j = Get-Content -Raw -Path $sourceFile | ConvertFrom-Json -Depth 100

# ---- 2) swap the trigger ------------------------------------------------
$trigger = [ordered]@{
    metadata = [ordered]@{ operationMetadataId = 'b7c1a2d3-0001-4a10-9c01-000000000001' }
    type     = 'OpenApiConnectionWebhook'
    inputs   = [ordered]@{
        host = [ordered]@{
            connectionName = 'shared_commondataserviceforapps'
            operationId    = 'SubscribeWebhookTrigger'
            apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
        }
        parameters = [ordered]@{
            'subscriptionRequest/message'             = 4
            'subscriptionRequest/entityname'          = 'alex_signaturerequest'
            'subscriptionRequest/scope'               = 4
            'subscriptionRequest/filteringattributes' = 'alex_statuscheckrequestedon'
        }
        authentication = "@parameters('`$authentication')"
    }
    runtimeConfiguration = [ordered]@{ concurrency = [ordered]@{ runs = 1 } }
}
$j.properties.definition.triggers = [pscustomobject]@{ When_status_check_is_requested = $trigger }

# ---- 3) scope both list steps to the single triggering request ----------
$reqIdExpr = "triggerOutputs()?['body/alex_signaturerequestid']"
$openStatuses = '(alex_status eq 626210002 or alex_status eq 626210003 or alex_status eq 626210004 or alex_status eq 626210005)'

$j.properties.definition.actions.List_open_signature_requests.inputs.parameters.'$filter' =
    "@concat('$openStatuses and alex_externalformid ne null and alex_signaturerequestid eq ', $reqIdExpr)"

$j.properties.definition.actions.List_open_envelope_requests.inputs.parameters.'$filter' =
    "@concat('$openStatuses and alex_externalenvelopeid ne null and alex_signaturerequestid eq ', $reqIdExpr)"

# ---- 4) stamp the check result after both branches ----------------------
$stamp = [ordered]@{
    runAfter = [ordered]@{ Process_each_open_envelope = @('Succeeded') }
    metadata = [ordered]@{ operationMetadataId = 'b7c1a2d3-0002-4a10-9c01-000000000002' }
    type     = 'OpenApiConnection'
    inputs   = [ordered]@{
        host = [ordered]@{
            connectionName = 'shared_commondataserviceforapps'
            operationId    = 'UpdateRecord'
            apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
        }
        parameters = [ordered]@{
            entityName                       = 'alex_signaturerequests'
            recordId                         = "@triggerOutputs()?['body/alex_signaturerequestid']"
            'item/alex_statuschecklastrunon' = '@utcNow()'
            'item/alex_statuscheckstatus'    = 'OK'
        }
        authentication = "@parameters('`$authentication')"
    }
}
$j.properties.definition.actions | Add-Member -NotePropertyName 'Stamp_status_check_result' -NotePropertyValue ([pscustomobject]$stamp) -Force

# ---- 5) serialize + normalize connection names to live ------------------
$clientdata = $j | ConvertTo-Json -Depth 100
$clientdata = $clientdata.Replace('shared_alex-5feasydoc-5f5849d39a0feaf28d', 'shared_alex-5feasydo-5f5849d39a0feaf28d')
$clientdata = $clientdata.Replace('alex_EasyDoc', 'alex_easydo')
if ($clientdata -match '5feasydoc') { throw 'Stale connection name still present after normalization.' }
$null = $clientdata | ConvertFrom-Json   # sanity

Set-Content -Path $outFile -Value $clientdata -Encoding UTF8
Write-Output ("Wrote derived flow -> $outFile  (clientdata length: " + $clientdata.Length + ")")

# ---- 6) deploy (create or update by name) -------------------------------
$headers = @{ 'MSCRM.SolutionUniqueName' = 'alex_d365_easydo' }
$existing = Invoke-DV GET ("workflows?`$select=workflowid,statecode&`$filter=category eq 5 and name eq '" + $name + "'")
if ($existing.value.Count -gt 0) {
    $wid = $existing.value[0].workflowid
    Write-Output ("Flow exists ($wid) -> deactivate, patch clientdata, reactivate.")
    Invoke-DV PATCH ("workflows($wid)") -Body @{ statecode = 0; statuscode = 1 } | Out-Null
    Invoke-DV PATCH ("workflows($wid)") -Body @{ clientdata = $clientdata } -ExtraHeaders $headers | Out-Null
    Invoke-DV PATCH ("workflows($wid)") -Body @{ statecode = 1; statuscode = 2 } | Out-Null
    Write-Output "Existing flow updated + reactivated."
    return
}

$body = @{
    category      = 5
    type          = 1
    name          = $name
    primaryentity = 'none'
    clientdata    = $clientdata
    statecode     = 0
    statuscode    = 1
}
$created = Invoke-DV POST 'workflows' -Body $body -ExtraHeaders ($headers + @{ Prefer = 'return=representation' })
$wid = $created.workflowid
Write-Output ("Flow created: " + $wid)
Invoke-DV PATCH ("workflows($wid)") -Body @{ statecode = 1; statuscode = 2 } | Out-Null
Write-Output "Flow activated. On-demand status check is live."
