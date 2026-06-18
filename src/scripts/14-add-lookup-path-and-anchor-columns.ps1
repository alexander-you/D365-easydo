<#
  14-add-lookup-path-and-anchor-columns.ps1

  Increment 3 (generic relationship mapping + write-back plugin).

  Until now a mapped field could come from the primary table or a single
  template-level Contact hop (alex_contactpath). Increment 3 makes the hop
  PER FIELD and allows ANY single lookup on the primary table (e.g.
  case -> product -> name, case -> account -> telephone1), not just contact.

  Two new columns:

    alex_templatefieldmapping.alex_LookupField
        Logical name of the lookup ON the primary table used to reach the table
        that holds the mapped column (alex_dynamicstable). Empty means the field
        lives directly on the primary table. Example: "primarycontactid" to map
        a column on the related contact, or the case->product lookup to map a
        product column.

    alex_signaturerequest.alex_PrimaryRecordId
        The anchor: the GUID of the primary record the signature request was
        raised for (a Case, Contract, etc.). The primary table is dynamic
        (it is alex_signaturetemplate.alex_primarytable), so a real polymorphic
        lookup cannot target it; the id is stored as text and combined with the
        template's primary table at runtime by the write-back / prefill plugin.

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$map = "alex_templatefieldmapping"
Write-Output "== $map =="
Add-DVColumn $map (New-DVString -Schema "alex_LookupField" -En "Lookup Path" -He "נתיב Lookup" -MaxLength 100 `
    -DescEn "Logical name of the lookup on the primary table used to reach the table that holds the mapped column. Empty means the column is directly on the primary table. Enables single-hop mapping such as case -> product -> name." `
    -DescHe "השם הלוגי של ה-lookup בטבלה הראשית שדרכו מגיעים לטבלה שבה נמצאת העמודה הממופה. ריק = העמודה נמצאת ישירות על הטבלה הראשית. מאפשר מיפוי בקפיצה אחת כגון פנייה -> מוצר -> שם.")

$req = "alex_signaturerequest"
Write-Output "== $req =="
Add-DVColumn $req (New-DVString -Schema "alex_PrimaryRecordId" -En "Primary Record" -He "רשומה ראשית" -MaxLength 100 `
    -DescEn "GUID of the primary record (e.g. the Case or Contract) this signature request was raised for. Combined with the template's primary table to read source values for prefill and to write recipient answers back. Set by the process that creates the request." `
    -DescHe "מזהה (GUID) של הרשומה הראשית (למשל הפנייה או החוזה) שעבורה נוצרה בקשת החתימה. משולב עם הטבלה הראשית של התבנית כדי לקרוא ערכי מקור למילוי מקדים ולכתוב חזרה את תשובות הנמען. נקבע על ידי התהליך שיוצר את הבקשה.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
