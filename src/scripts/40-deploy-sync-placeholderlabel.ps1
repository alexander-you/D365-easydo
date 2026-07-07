# 40-deploy-sync-placeholderlabel.ps1
# Patches the live "Auto Sync EasyDo Templates" flow clientdata so that:
#   - payload.data (2D array) is flattened once per template (Select -> Filter -> Compose/json)
#   - each field looks up its cell by name (Find_cell)
#   - alex_externalfieldname = placeholderLabel (friendly description shown in the mapping PCF)
#   - alex_externalexportname = header (the binding key consumed by the auto-map plugin)
# String-splice on minified clientdata; every replacement must match exactly once.

. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
Connect-Dataverse | Out-Null

$wid = 'bf47806d-d16e-f111-ab0c-7ced8d726840'
$w = Invoke-DV GET ("workflows($wid)?`$select=clientdata")
$cd = $w.clientdata
Write-Output ("clientdata length before: " + $cd.Length)

function Apply-One($text, $old, $new, $label) {
  $count = ([regex]::Matches($text, [regex]::Escape($old))).Count
  if ($count -ne 1) { throw ("[$label] expected 1 match, found $count") }
  return $text.Replace($old, $new)
}

# --- flatten actions injected before the Apply_to_each_field loop ---
$flatten = @'
"Select_field_rows":{"runAfter":{"Update_template_roles":["Succeeded"]},"metadata":{"operationMetadataId":"c1a10001-0001-4a10-9c01-000000000201"},"type":"Select","inputs":{"from":"@coalesce(body('Get_template_detail')?['payload']?['data'], json('[]'))","select":"@slice(string(item()), 1, -1)"}},"Filter_nonempty_row_str":{"runAfter":{"Select_field_rows":["Succeeded"]},"metadata":{"operationMetadataId":"c1a10001-0002-4a10-9c01-000000000202"},"type":"Query","inputs":{"from":"@body('Select_field_rows')","where":"@greater(length(item()), 0)"}},"Flatten_fields":{"runAfter":{"Filter_nonempty_row_str":["Succeeded"]},"metadata":{"operationMetadataId":"c1a10001-0003-4a10-9c01-000000000203"},"type":"Compose","inputs":"@json(concat('[', join(body('Filter_nonempty_row_str'), ','), ']'))"},
'@

$findCell = @'
"Find_cell":{"runAfter":{},"metadata":{"operationMetadataId":"c1a10001-0004-4a10-9c01-000000000204"},"type":"Query","inputs":{"from":"@coalesce(outputs('Flatten_fields'), json('[]'))","where":"@equals(coalesce(item()?['name'], ''), items('Apply_to_each_field')?['name'])"}},
'@

# R1: insert flatten before the loop + add Find_cell + rewire List_existing_field.runAfter
$r1old = @'
"Apply_to_each_field":{"foreach":"@outputs('Get_template_detail')?['body/data_headers']","actions":{"List_existing_field":{"runAfter":{},
'@
$loopStart = @'
"Apply_to_each_field":{"foreach":"@outputs('Get_template_detail')?['body/data_headers']","actions":{
'@
$listStart = @'
"List_existing_field":{"runAfter":{"Find_cell":["Succeeded"]},
'@
$r1new = $flatten + $loopStart + $findCell + $listStart
$cd = Apply-One $cd $r1old $r1new 'R1 flatten+findcell'

# R2: Apply_to_each_field runAfter Update_template_roles -> Flatten_fields
$r2old = @'
"runAfter":{"Update_template_roles":["Succeeded"]},"metadata":{"operationMetadataId":"a1f0c1e2-000c-4a10-9c01-00000000000c"},"type":"Foreach"}
'@
$r2new = @'
"runAfter":{"Flatten_fields":["Succeeded"]},"metadata":{"operationMetadataId":"a1f0c1e2-000c-4a10-9c01-00000000000c"},"type":"Foreach"}
'@
$cd = Apply-One $cd $r2old $r2new 'R2 loop runAfter'

# R3: Update_field parameters
$r3old = @'
"recordId":"@first(outputs('List_existing_field')?['body/value'])?['alex_templatefieldmappingid']","item/alex_name":"@coalesce(items('Apply_to_each_field')?['header'], items('Apply_to_each_field')?['name'])","item/alex_externalfieldname":"@items('Apply_to_each_field')?['header']","item/alex_externalfieldtype":"@items('Apply_to_each_field')?['type']"
'@
$r3new = @'
"recordId":"@first(outputs('List_existing_field')?['body/value'])?['alex_templatefieldmappingid']","item/alex_name":"@coalesce(items('Apply_to_each_field')?['header'], items('Apply_to_each_field')?['name'])","item/alex_externalfieldname":"@coalesce(first(body('Find_cell'))?['placeholderLabel'], items('Apply_to_each_field')?['header'], items('Apply_to_each_field')?['name'])","item/alex_externalexportname":"@items('Apply_to_each_field')?['header']","item/alex_externalfieldtype":"@items('Apply_to_each_field')?['type']"
'@
$cd = Apply-One $cd $r3old $r3new 'R3 Update_field'

# R4: Create_field parameters
$r4old = @'
"item/alex_externalfieldid":"@items('Apply_to_each_field')?['name']","item/alex_externalfieldname":"@items('Apply_to_each_field')?['header']","item/alex_externalfieldtype":"@items('Apply_to_each_field')?['type']"
'@
$r4new = @'
"item/alex_externalfieldid":"@items('Apply_to_each_field')?['name']","item/alex_externalfieldname":"@coalesce(first(body('Find_cell'))?['placeholderLabel'], items('Apply_to_each_field')?['header'], items('Apply_to_each_field')?['name'])","item/alex_externalexportname":"@items('Apply_to_each_field')?['header']","item/alex_externalfieldtype":"@items('Apply_to_each_field')?['type']"
'@
$cd = Apply-One $cd $r4old $r4new 'R4 Create_field'

Write-Output ("clientdata length after: " + $cd.Length)

# sanity: must be valid JSON
$null = $cd | ConvertFrom-Json
Write-Output "clientdata parses as JSON: OK"

$headers = @{ 'MSCRM.SolutionUniqueName' = 'alex_d365_easydo' }
Invoke-DV PATCH ("workflows($wid)") -Body @{ clientdata = $cd } -ExtraHeaders $headers | Out-Null
Write-Output "clientdata PATCHed. Sync flow updated."
