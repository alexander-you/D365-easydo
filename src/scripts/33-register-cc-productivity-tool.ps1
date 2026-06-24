<#
  33-register-cc-productivity-tool.ps1

  Registers the easydo "Send for signature" Contact Center productivity tool and
  wires it into a Contact Center agent experience profile's productivity pane,
  entirely through the Dataverse Web API.

  WHY THIS LIVES OUTSIDE THE PORTABLE SOLUTION
  --------------------------------------------
  The msdyn_panetoolconfiguration / msdyn_panetabconfiguration records reference
  the agent-experience-profile entities that only exist where Customer Service /
  Contact Center is installed. To keep alex_d365_easydo importable into plain
  Dataverse environments, these registration records are created in the ACTIVE
  (default) solution (no MSCRM.SolutionUniqueName header) and are NEVER added to
  alex_d365_easydo. Run this script only in Contact Center environments, AFTER
  the EasyDo.ContactCenterPane PCF control has been pushed (pac pcf push).

  HOST CONTROL
  ------------
  The tool is a Control-type tool (msdyn_type = 0) bound to the PCF control
  'alex_EasyDo.ContactCenterPane' (src/pcf-contactcenter), a thin iframe wrapper
  around the alex_/html/contactCenterPane.html web resource. A custom tool must
  be a Control or a Custom Page; an HTML web resource cannot be registered
  directly, and custom pages have no working Dataverse Web API at runtime.

  The script is idempotent: it looks the records up by unique name and PATCHes
  them when they already exist, otherwise POSTs new ones.
#>

. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse | Out-Null

# --- Configuration ----------------------------------------------------------
$controlName  = "alex_EasyDo.ContactCenterPane"          # registered PCF control
$toolUnique   = "alex_easydo_cc_signature_tool"
$toolName     = "easydo - שליחה לחתימה"
$tabUnique    = "alex_easydo_cc_signature_tool_config_cc1_contactcenteragentexperienceprofile_pane_tab"
$tabName      = "easydo signature cc1_contactcenteragentexperienceprofile pane tab"
$tabOrder     = 40
$tabTooltip   = "easydo - שליחה לחתימה"

# Productivity pane of the "Contact center agent experience profile"
# (msdyn_appconfiguration 18c5913d-d322-f111-8341-7ced8d421ee7).
$paneId       = "1cc5913d-d322-f111-8341-7ced8d421ee7"

# --- 1) Tool configuration --------------------------------------------------
$existingTool = (Invoke-DV GET "msdyn_panetoolconfigurations?`$filter=msdyn_uniquename eq '$toolUnique'&`$select=msdyn_panetoolconfigurationid" -Silent).value
$toolDescription = "שליחת מסמך לחתימה ללקוח של השיחה הפעילה, ישירות מתוך סשן הנציג."
$toolBody = @{
    msdyn_name           = $toolName
    msdyn_uniquename     = $toolUnique
    msdyn_controlname    = $controlName
    msdyn_description    = $toolDescription
    msdyn_defaulticon    = "/WebResources/alex_/icons/sendIcon.svg"   # paper-plane send icon (alex_/icons/sendIcon.svg web resource)
    msdyn_type           = 0            # 0 = Control (פקד)
    msdyn_data           = "{}"
    msdyn_category       = 100000001    # Agent guidance (הדרכת סוכנים)
    msdyn_isglobal       = $false       # session tool (matches Knowledge search)
    msdyn_isconfigurable = $false
}
if ($existingTool -and $existingTool.Count -gt 0) {
    $toolId = $existingTool[0].msdyn_panetoolconfigurationid
    Invoke-DV PATCH "msdyn_panetoolconfigurations($toolId)" -Body $toolBody -Silent | Out-Null
    Write-Host "Updated tool config $toolId"
} else {
    Invoke-DV POST "msdyn_panetoolconfigurations" -Body $toolBody -Silent | Out-Null
    $toolId = (Invoke-DV GET "msdyn_panetoolconfigurations?`$filter=msdyn_uniquename eq '$toolUnique'&`$select=msdyn_panetoolconfigurationid" -Silent).value[0].msdyn_panetoolconfigurationid
    Write-Host "Created tool config $toolId"
}

# --- 2) Pane tab (wires the tool into the profile's productivity pane) -------
$existingTab = (Invoke-DV GET "msdyn_panetabconfigurations?`$filter=msdyn_uniquename eq '$tabUnique'&`$select=msdyn_panetabconfigurationid" -Silent).value
$tabBody = @{
    msdyn_name                              = $tabName
    msdyn_uniquename                        = $tabUnique
    msdyn_order                             = $tabOrder
    msdyn_isenabled                         = $true
    msdyn_tooltip                           = $tabTooltip
    "msdyn_ProductivityPaneId@odata.bind"   = "/msdyn_paneconfigurations($paneId)"
    "msdyn_ToolId@odata.bind"               = "/msdyn_panetoolconfigurations($toolId)"
}
if ($existingTab -and $existingTab.Count -gt 0) {
    $tabId = $existingTab[0].msdyn_panetabconfigurationid
    Invoke-DV PATCH "msdyn_panetabconfigurations($tabId)" -Body $tabBody -Silent | Out-Null
    Write-Host "Updated pane tab $tabId"
} else {
    Invoke-DV POST "msdyn_panetabconfigurations" -Body $tabBody -Silent | Out-Null
    $tabId = (Invoke-DV GET "msdyn_panetabconfigurations?`$filter=msdyn_uniquename eq '$tabUnique'&`$select=msdyn_panetabconfigurationid" -Silent).value[0].msdyn_panetabconfigurationid
    Write-Host "Created pane tab $tabId"
}

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Host "Published. Tool=$toolId Tab=$tabId Pane=$paneId"
