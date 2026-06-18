<#
  13-add-template-primary-table-columns.ps1

  Increment 2 (relationship-aware mapping). The signature template is built on
  ONE primary record (e.g. a Case / Eligibility / Contract). Most fields come
  from that base table; some need to come from the related Contact, reached via
  a single lookup hop chosen by the maker.

  Two template-level columns capture that:
    alex_primarytable - logical name of the base table the document is built on
    alex_contactpath  - logical name of the lookup on the base table used to
                        reach the Contact (e.g. primarycontactid). Empty when
                        the base table IS contact or no contact hop is needed.

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_signaturetemplate"
Write-Output "== $t =="

Add-DVColumn $t (New-DVString -Schema "alex_PrimaryTable" -En "Primary Table" -He "טבלה ראשית" -MaxLength 100 `
    -DescEn "Logical name of the base Dynamics table this document is built on (e.g. incident). Fields are mapped from this table or from a related Contact." `
    -DescHe "השם הלוגי של טבלת הבסיס ב-Dynamics שעליה בנוי המסמך (למשל incident). השדות ממופים מטבלה זו או מאיש קשר קשור.")

Add-DVColumn $t (New-DVString -Schema "alex_ContactPath" -En "Contact Path" -He "נתיב לאיש קשר" -MaxLength 100 `
    -DescEn "Logical name of the lookup on the primary table used to reach the Contact for personal details (e.g. primarycontactid). Leave empty when the primary table is contact." `
    -DescHe "השם הלוגי של ה-lookup בטבלה הראשית שדרכו מגיעים לאיש הקשר לפרטים אישיים (למשל primarycontactid). יש להשאיר ריק כאשר הטבלה הראשית היא איש קשר.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
