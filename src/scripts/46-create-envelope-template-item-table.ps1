<#
  46-create-envelope-template-item-table.ps1

  ENVELOPE membership (template composition) - additive schema.

  A synced envelope is one alex_signaturetemplate row (alex_isenvelope = true).
  Until now the DOCUMENTS that make up an envelope were resolved live from easydo
  (GetEnvelope) only at send time and were NOT stored in Dataverse, so an envelope
  template showed no member documents in the UI.

  This script adds a small child table that persists the envelope composition so
  the member documents are visible under the envelope template row. It is filled
  automatically by the two template-sync flows (one row per member document).

  NOTE: this is the ENVELOPE DEFINITION (which documents belong to the envelope),
  which is different from alex_signaturerequestitem (the per-document rows created
  at RUNTIME when an actual signature request/envelope is sent).

  What this script provisions (all additive, all idempotent):

    NEW child table  alex_EnvelopeTemplateItem  ("Envelope Item" / "פריט מעטפה")
      alex_Name              (primary)  - member document name
      alex_Sequence          (int)      - order of the document inside the envelope
      alex_ExternalTemplateId (string)  - easydo template id of the member document
      alex_DefaultRoleId     (int)      - default easydo role id of the member document
      alex_LastSyncedOn      (datetime) - last time this membership row was synced
      alex_EnvelopeId        (lookup)   - the envelope template row (required)
      alex_TemplateId        (lookup)   - the member document's standalone template row (optional)

  The alex_TemplateId lookup demonstrates that the SAME document can be both a
  standalone template AND a member of an envelope: it points to the member's own
  single-document alex_signaturetemplate row (synced via GetTemplates).

  Re-runnable: New-DVTable / Add-DVColumn / New-DVLookup skip existing components.
  Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- NEW child table: Envelope Template Item -----------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Document Name" -He "שם מסמך" `
        -DescEn "The display name of the member document inside the envelope (the document/template title)." `
        -DescHe "שם התצוגה של המסמך החבר בתוך המעטפה (כותרת המסמך/התבנית)."
New-DVTable -Schema "alex_EnvelopeTemplateItem" `
    -En "Envelope Item" -He "פריט מעטפה" `
    -CollEn "Envelope Items" -CollHe "פריטים במעטפה" `
    -DescEn "A single document that belongs to an envelope template (the envelope's composition). One row per document inside the envelope, showing its order and default role. This is the envelope DEFINITION, not a runtime signature request item." `
    -DescHe "מסמך בודד השייך לתבנית מעטפה (הרכב המעטפה). שורה אחת לכל מסמך בתוך המעטפה, המציגה את הסדר ותפקיד ברירת המחדל שלו. זהו הגדרת המעטפה, ולא פריט של בקשת חתימה בזמן ריצה." `
    -PrimaryName $pn

$t = "alex_envelopetemplateitem"
Write-Output "== $t =="

Add-DVColumn $t (New-DVInt -Schema "alex_Sequence" -En "Order In Envelope" -He "סדר במעטפה" `
    -DescEn "The order in which this document appears/is signed inside the envelope. Lower numbers come first; documents with the same number can be handled in parallel." `
    -DescHe "הסדר שבו מסמך זה מופיע/נחתם בתוך המעטפה. מספרים נמוכים מופיעים ראשונים; מסמכים עם אותו מספר יכולים להיות מטופלים במקביל." `
    -Min 0 -Max 1000)

Add-DVColumn $t (New-DVString -Schema "alex_ExternalTemplateId" -En "easydo Template Id" -He "מזהה תבנית easydo" -MaxLength 100 `
    -DescEn "The easydo template id of this member document (for example 68854). Matches the external template id of the member's standalone template row." `
    -DescHe "מזהה תבנית ה-easydo של מסמך חבר זה (לדוגמה 68854). תואם למזהה התבנית החיצוני של שורת התבנית העצמאית של החבר.")

Add-DVColumn $t (New-DVInt -Schema "alex_DefaultRoleId" -En "Default Role Id" -He "מזהה תפקיד ברירת מחדל" `
    -DescEn "The default easydo assignee role id for this document inside the envelope (for example 1 for the first signer, 2 for a second signer). Used when building the envelope recipients." `
    -DescHe "מזהה תפקיד החותם (role_id) של easydo כברירת מחדל עבור מסמך זה בתוך המעטפה (לדוגמה 1 עבור החותם הראשון, 2 עבור חותם שני). משמש בעת בניית נמעני המעטפה." `
    -Min 0 -Max 1000000)

Add-DVColumn $t (New-DVDateTime -Schema "alex_LastSyncedOn" -En "Last Synced On" -He "סונכרן לאחרונה" `
    -DescEn "The date and time this envelope membership row was last refreshed from easydo by the template sync." `
    -DescHe "התאריך והשעה שבהם שורת חברוּת המעטפה רועננה לאחרונה מ-easydo על ידי סנכרון התבניות.")

# ---- Relationships -------------------------------------------------------
New-DVLookup -Schema "alex_EnvelopeId" -En "Envelope" -He "מעטפה" `
    -DescEn "The envelope template row this document belongs to." `
    -DescHe "שורת תבנית המעטפה שאליה שייך מסמך זה." `
    -ReferencedTable "alex_signaturetemplate" -ReferencingTable "alex_envelopetemplateitem" `
    -RelationshipName "alex_signaturetemplate_envelopeitem_envelope" -Required "ApplicationRequired"

New-DVLookup -Schema "alex_TemplateId" -En "Document Template" -He "תבנית המסמך" `
    -DescEn "The member document's own standalone template row. Shows that the same document can be both a standalone template and a member of an envelope. Empty if the member is not synced as a standalone template." `
    -DescHe "שורת התבנית העצמאית של המסמך החבר. מדגים שאותו מסמך יכול להיות גם תבנית עצמאית וגם חבר במעטפה. ריק אם החבר אינו מסונכרן כתבנית עצמאית." `
    -ReferencedTable "alex_signaturetemplate" -ReferencingTable "alex_envelopetemplateitem" `
    -RelationshipName "alex_signaturetemplate_envelopeitem_template" -Required "None"

# ---- Publish -------------------------------------------------------------
Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done. Envelope membership table provisioned."
