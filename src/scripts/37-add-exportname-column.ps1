# 37-add-exportname-column.ps1
# Auto-mapping support: the template sync now stores TWO names per field.
#   - alex_externalfieldname : the field DESCRIPTION (easydo placeholderLabel),
#                              shown to the admin in the mapping PCF.
#   - alex_externalexportname: the easydo EXPORT name (export.header) - the stable
#                              binding key used by alex_AutoMapTemplateFields to
#                              resolve each field to a Dynamics table.column.
# Binding key grammar (logical names, table-prefixed):
#   contact.fullname                          -> direct
#   incident.new_productid.name               -> single-target lookup hop
#   incident.customerid.contact.fullname      -> polymorphic hop (explicit target)
# Idempotent: Add-DVColumn is create-or-skip.
$ErrorActionPreference = "Stop"
. .\src\scripts\.env.ps1
. .\src\scripts\dv-common.ps1
. .\src\scripts\dv-meta.ps1
Connect-Dataverse | Out-Null

$exportName = New-DVString `
    -Schema "alex_ExternalExportName" `
    -En "Export Name" -He "שם ייצוא" `
    -DescEn "The easydo export name (export.header) for this field. Used as the binding key by the auto-mapping Custom API to resolve the field to a Dynamics table.column. Populated by the template sync." `
    -DescHe "שם הייצוא ב-easydo (export.header) עבור השדה. משמש כמפתח קישור עבור ה-Custom API של ההתאמה האוטומטית לפתרון השדה ל-table.column ב-Dynamics. מתמלא על ידי סנכרון התבניות." `
    -MaxLength 200

Add-DVColumn -TableLogical "alex_templatefieldmapping" -Attribute $exportName

Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. alex_externalexportname ensured + published."
