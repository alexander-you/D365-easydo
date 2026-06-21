<#
  21-add-wizard-payload-column.ps1

  Send Wizard intake column.

  The send wizard (PCF on a custom page) outputs a single JSON envelope that
  describes everything needed to raise a signature request: the chosen template
  (external id), the recipients, draft/send mode, document language and the
  launch context (table + record). The custom page cannot safely write all of
  that with Power Fx because canvas formulas reference Dataverse columns and
  choices by their localized DISPLAY names, which break when the UI language
  changes.

  Instead the page writes the raw JSON into ONE column on a new
  alex_signaturerequest row, and a server-side plugin (logical names, language
  independent) parses it and fills in everything else (template lookup, related
  table/record, language, draft, recipients) and flips the status to
  "Ready to Send". This keeps the page formula to a single trivial Patch.

    alex_signaturerequest.alex_WizardPayload
        Raw JSON produced by the send wizard's OutputJson. Consumed once by the
        WizardIntake plugin on create; ignored thereafter.

  Re-runnable: Add-DVColumn is idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$req = "alex_signaturerequest"
Write-Output "== $req =="
Add-DVColumn $req (New-DVMemo -Schema "alex_WizardPayload" -En "Wizard Payload" -He "מטען האשף" -MaxLength 8000 `
    -DescEn "Raw JSON emitted by the send wizard. Parsed once by the WizardIntake plugin on create to populate the template, related record, language, draft flag and recipients, then ignored." `
    -DescHe "מטען ה-JSON הגולמי שמפיק אשף השליחה. מנותח פעם אחת על ידי תוסף WizardIntake בעת היצירה כדי למלא את התבנית, הרשומה המשויכת, השפה, מצב הטיוטה והנמענים, ולאחר מכן מתעלמים ממנו.")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
