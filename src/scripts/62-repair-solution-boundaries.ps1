<#
  Repairs two release-boundary issues in the EN development environment:
    - removes the Tenant Contract-specific EasyDo Documents subgrid and its
      cross-solution relationship from Signature Request;
    - adds the Template Gallery PCF to alex_d365_easydo before export.

  Safe to rerun. Run before creating release 2.0.0.1 or any later release.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null
$ErrorActionPreference = "Stop"

$mainName = "alex_d365_easydo"
$tenantContract = "alex_tenant_contract"
$relationshipName = "alex_alex_tenant_contract_signaturerequest"
$galleryName = "alex_EasyDo.EasyDoTemplateGallery"
$solHeader = @{ "MSCRM.SolutionUniqueName" = "PropertyAllocationBoard" }

# The Tenant Contract form is environment-specific. Remove the subgrid that uses
# EasyDo's request relationship before deleting that relationship.
$forms = (Invoke-DV GET "systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$tenantContract' and type eq 2").value
foreach ($form in $forms) {
    [xml]$xml = $form.formxml
  $sections = @($xml.SelectNodes("//*[local-name()='section'][.//*[local-name()='RelationshipName' and text()='$relationshipName'] ]"))
  $descriptions = @($xml.SelectNodes("//*[local-name()='controlDescription'][.//*[local-name()='RelationshipName' and text()='$relationshipName'] ]"))
    if ($sections.Count -eq 0 -and $descriptions.Count -eq 0) { continue }

    foreach ($section in $sections) { [void]$section.ParentNode.RemoveChild($section) }
    foreach ($description in $descriptions) { [void]$description.ParentNode.RemoveChild($description) }

    Invoke-DV PATCH "systemforms($($form.formid))" -Body @{ formxml = $xml.OuterXml } -ExtraHeaders $solHeader | Out-Null
    Write-Output "Removed Tenant Contract EasyDo subgrid from form '$($form.name)'."
}

# Dataverse evaluates relationship-delete dependencies against the published form.
Invoke-DV POST "PublishAllXml" -Body @{} | Out-Null

$relationship = $null
try { $relationship = Invoke-DV GET "RelationshipDefinitions(SchemaName='$relationshipName')?`$select=SchemaName" -Silent } catch { }
if ($relationship) {
    Invoke-DV DELETE "RelationshipDefinitions(SchemaName='$relationshipName')" | Out-Null
    Write-Output "Deleted relationship $relationshipName."
} else {
    Write-Output "Relationship $relationshipName is already absent."
}

$gallery = (Invoke-DV GET "customcontrols?`$select=customcontrolid&`$filter=name eq '$galleryName'").value | Select-Object -First 1
if (-not $gallery) { throw "Custom control '$galleryName' is not present. Build and run pac pcf push from src/pcf-template-gallery first." }
try {
    Invoke-DV POST "AddSolutionComponent" -Body @{ ComponentId = $gallery.customcontrolid; ComponentType = 66; SolutionUniqueName = $mainName; AddRequiredComponents = $false } | Out-Null
    Write-Output "Added Template Gallery to $mainName."
} catch {
    Write-Output "Template Gallery is already in $mainName."
}

Invoke-DV POST "PublishAllXml" -Body @{} | Out-Null
Write-Output "Published customizations."