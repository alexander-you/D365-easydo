<#
  45-create-envelope-item-table.ps1

  ENVELOPE (multi-document) support - Phase 1 (schema only).

  easydo "envelope" = one recipient set that signs a BUNDLE of documents and
  gets ONE combined signing link and ONE combined PDF (probed live 2026-07-31,
  see /memories/repo/easydoc-api.md). The existing single-template path
  (alex_signaturerequest.alex_TemplateId) is left completely untouched; the
  envelope path runs in parallel and is selected by the new
  alex_IsMultiDocument flag on the request.

  What this script provisions (all additive, all idempotent):

  1) Global choice  alex_envelopeitemstatus
     Per-document status inside an envelope (each document is signed/declined
     independently, mirroring the easydo form status per bundle member).

  2) NEW child table  alex_SignatureRequestItem
     A junction row (request <-> template), ONE per document in the bundle.
     alex_signaturerequest stays the ENVELOPE HEADER (recipients / channels /
     log / status live at request level); each item carries the per-document
     easydo form id, step id, sequence and status.

     Columns:
       alex_Name              (primary)  - display name for the bundle item
       alex_SignatureRequestId (lookup)  - parent envelope header (required)
       alex_TemplateId        (lookup)   - which template/document this row is
       alex_Sequence          (int)      - signing order inside the envelope
       alex_ExternalFormId    (string)   - easydo form id for this document
       alex_StepId            (string)   - easydo step_id for this document
       alex_ItemStatus        (choice)   - per-document status
       alex_FillUrl           (url)      - per-document signing link
       alex_FormSlug          (string)   - easydo form slug (per-doc read-back)
       alex_SignedOn          (datetime) - when this document was signed

  3) Request-level envelope columns on alex_signaturerequest
       alex_IsMultiDocument   (bool)     - selects the envelope path (default OFF)
       alex_ExternalEnvelopeId (string)  - easydo envelope INSTANCE guid
       alex_EnvelopeFillUrl   (url)      - envelope-level combined signing link

  4) alex_TemplateId lookup on alex_signaturefieldvalue
     Scopes a prefill / read-back value to a SPECIFIC document in the bundle
     (a field name can repeat across bundle members). Optional / nullable so
     legacy single-template rows are unaffected.

  Re-runnable: New-DVGlobalChoice / New-DVTable / Add-DVColumn / New-DVLookup
  all skip components that already exist. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- 1) Global choice: per-document status inside an envelope -------------
New-DVGlobalChoice -Name "alex_envelopeitemstatus" `
    -En "Envelope Document Status" -He "סטטוס מסמך במעטפה" `
    -DescEn "Status of a single document inside a multi-document envelope. Each document in the bundle is signed or declined independently." `
    -DescHe "הסטטוס של מסמך בודד בתוך מעטפה מרובת-מסמכים. כל מסמך בחבילה נחתם או נדחה באופן עצמאי." `
    -Options @(
        @{ Value = 626220000; En = "Pending";              He = "ממתין";        DescEn = "The document is part of the envelope but has not started the signing flow yet."; DescHe = "המסמך חלק מהמעטפה אך תהליך החתימה שלו טרם החל." }
        @{ Value = 626220001; En = "Waiting For Signature"; He = "ממתין לחתימה";  DescEn = "The document was sent and is waiting for the recipient to sign it."; DescHe = "המסמך נשלח וממתין לכך שהנמען יחתום עליו." }
        @{ Value = 626220002; En = "Signed";                He = "נחתם";         DescEn = "The recipient has completed and signed this document."; DescHe = "הנמען השלים וחתם על מסמך זה." }
        @{ Value = 626220003; En = "Declined";              He = "נדחה";         DescEn = "The recipient declined to sign this document."; DescHe = "הנמען סירב לחתום על מסמך זה." }
        @{ Value = 626220004; En = "Expired";               He = "פג תוקף";      DescEn = "The document expired before it was signed."; DescHe = "תוקף המסמך פג בטרם נחתם." }
        @{ Value = 626220005; En = "Error";                 He = "שגיאה";        DescEn = "An error occurred while sending or processing this document."; DescHe = "אירעה שגיאה בעת שליחת המסמך או עיבודו." }
    )

# ---- 2) NEW child table: Signature Request Item --------------------------
$pn = New-DVPrimaryName -Schema "alex_Name" -En "Item Name" -He "שם פריט" `
        -DescEn "Display name of this envelope document item (usually the document/template name)." `
        -DescHe "שם התצוגה של פריט המסמך במעטפה (בדרך כלל שם המסמך/התבנית)."
New-DVTable -Schema "alex_SignatureRequestItem" `
    -En "Signature Request Item" -He "פריט בקשת חתימה" `
    -CollEn "Signature Request Items" -CollHe "פריטי בקשת חתימה" `
    -DescEn "A single document inside a multi-document envelope for a signature request. One row per document in the bundle, holding the per-document easydo form id, signing order and status." `
    -DescHe "מסמך בודד בתוך מעטפה מרובת-מסמכים עבור בקשת חתימה. שורה אחת לכל מסמך בחבילה, המחזיקה את מזהה טופס easydo, סדר החתימה והסטטוס של אותו מסמך." `
    -PrimaryName $pn

$t = "alex_signaturerequestitem"
Write-Output "== $t =="

Add-DVColumn $t (New-DVInt -Schema "alex_Sequence" -En "Signing Order" -He "סדר חתימה" `
    -DescEn "The order in which this document is signed inside the envelope. Lower numbers are signed first; documents with the same number can be signed in parallel." `
    -DescHe "הסדר שבו מסמך זה נחתם בתוך המעטפה. מספרים נמוכים נחתמים ראשונים; מסמכים עם אותו מספר יכולים להיחתם במקביל." `
    -Min 0 -Max 1000)

Add-DVColumn $t (New-DVString -Schema "alex_ExternalFormId" -En "easydo Form Id" -He "מזהה טופס easydo" -MaxLength 100 `
    -DescEn "The easydo form id of this document within the sent envelope instance (e.g. 3638290). Used to read back the signed values for this specific document." `
    -DescHe "מזהה טופס easydo של מסמך זה בתוך מופע המעטפה שנשלחה (לדוגמה 3638290). משמש לקריאה חזרה של הערכים החתומים עבור מסמך ספציפי זה.")

Add-DVColumn $t (New-DVString -Schema "alex_StepId" -En "easydo Step Id" -He "מזהה שלב easydo" -MaxLength 100 `
    -DescEn "The easydo step_id associated with this document in the envelope flow. Identifies the workflow step that produced this form." `
    -DescHe "מזהה השלב (step_id) ב-easydo המשויך למסמך זה בתהליך המעטפה. מזהה את שלב זרימת העבודה שהפיק טופס זה.")

Add-DVColumn $t (New-DVString -Schema "alex_FormSlug" -En "easydo Form Slug" -He "מזהה ייחודי לטופס easydo" -MaxLength 100 `
    -DescEn "The easydo form slug for this document, used to build the per-document signing link and to read back the form directly." `
    -DescHe "מזהה ה-slug של טופס easydo עבור מסמך זה, המשמש לבניית קישור החתימה של המסמך ולקריאה ישירה של הטופס.")

Add-DVColumn $t (New-DVPicklistGlobal -Schema "alex_ItemStatus" -En "Document Status" -He "סטטוס מסמך" -GlobalOptionSetName "alex_envelopeitemstatus" -Required "ApplicationRequired" `
    -DescEn "The current status of this single document inside the envelope (pending, waiting for signature, signed, declined, expired or error)." `
    -DescHe "הסטטוס הנוכחי של מסמך בודד זה בתוך המעטפה (ממתין, ממתין לחתימה, נחתם, נדחה, פג תוקף או שגיאה).")

Add-DVColumn $t (New-DVString -Schema "alex_FillUrl" -En "Document Signing Link" -He "קישור חתימה למסמך" -MaxLength 400 -Format "Url" `
    -DescEn "The per-document signing link that opens this specific document for the recipient. The whole bundle also has one combined link on the request." `
    -DescHe "קישור החתימה של המסמך הבודד, הפותח מסמך ספציפי זה עבור הנמען. לכל החבילה יש גם קישור מאוחד אחד על הבקשה.")

Add-DVColumn $t (New-DVDateTime -Schema "alex_SignedOn" -En "Signed On" -He "נחתם בתאריך" `
    -DescEn "The date and time this specific document was signed. Empty until the recipient completes this document." `
    -DescHe "התאריך והשעה שבהם מסמך ספציפי זה נחתם. ריק עד שהנמען משלים מסמך זה.")

# ---- 2b) Relationships for the item table --------------------------------
New-DVLookup -Schema "alex_SignatureRequestId" -En "Signature Request" -He "בקשת חתימה" `
    -DescEn "The envelope (signature request) this document item belongs to." `
    -DescHe "המעטפה (בקשת החתימה) שאליה שייך פריט מסמך זה." `
    -ReferencedTable "alex_signaturerequest" -ReferencingTable "alex_signaturerequestitem" `
    -RelationshipName "alex_signaturerequest_signaturerequestitem" -Required "ApplicationRequired"

New-DVLookup -Schema "alex_TemplateId" -En "Signature Template" -He "תבנית חתימה" `
    -DescEn "The template/document this envelope item represents." `
    -DescHe "התבנית/המסמך שאותם מייצג פריט מעטפה זה." `
    -ReferencedTable "alex_signaturetemplate" -ReferencingTable "alex_signaturerequestitem" `
    -RelationshipName "alex_signaturetemplate_signaturerequestitem" -Required "ApplicationRequired"

# ---- 3) Request-level envelope columns -----------------------------------
$req = "alex_signaturerequest"
Write-Output "== $req =="

Add-DVColumn $req (New-DVBool -Schema "alex_IsMultiDocument" -En "Multi-Document Envelope" -He "מעטפה מרובת-מסמכים" `
    -TrueEn "Envelope" -TrueHe "מעטפה" -FalseEn "Single Document" -FalseHe "מסמך יחיד" `
    -DescEn "When on, this request is a multi-document envelope: the recipient signs several documents (see the Signature Request Items) with one combined link. When off, the classic single-template path is used." `
    -DescHe "כאשר פעיל, בקשה זו היא מעטפה מרובת-מסמכים: הנמען חותם על מספר מסמכים (ראה את פריטי בקשת החתימה) עם קישור מאוחד אחד. כאשר כבוי, נעשה שימוש בנתיב הקלאסי של תבנית יחידה." `
    -Default $false)

Add-DVColumn $req (New-DVString -Schema "alex_ExternalEnvelopeId" -En "easydo Envelope Id" -He "מזהה מעטפה easydo" -MaxLength 100 `
    -DescEn "The easydo envelope instance id (GUID) returned when the envelope is sent. Used to poll the whole bundle status and to download the combined signed PDF." `
    -DescHe "מזהה מופע המעטפה ב-easydo (GUID) המוחזר בעת שליחת המעטפה. משמש למעקב אחר סטטוס כל החבילה ולהורדת קובץ ה-PDF החתום המאוחד.")

Add-DVColumn $req (New-DVString -Schema "alex_EnvelopeFillUrl" -En "Envelope Signing Link" -He "קישור חתימה למעטפה" -MaxLength 400 -Format "Url" `
    -DescEn "The single combined signing link that opens the whole envelope (all documents) for the recipient." `
    -DescHe "קישור החתימה המאוחד היחיד הפותח את כל המעטפה (כל המסמכים) עבור הנמען.")

# ---- 3b) Template-level flag: this template row is an envelope ------------
$tpl = "alex_signaturetemplate"
Write-Output "== $tpl =="

Add-DVColumn $tpl (New-DVBool -Schema "alex_IsEnvelope" -En "Is Envelope" -He "תבנית מעטפה" `
    -TrueEn "Envelope" -TrueHe "מעטפה" -FalseEn "Single Document" -FalseHe "מסמך יחיד" `
    -DescEn "When on, this template row represents an easydo ENVELOPE (a bundle of documents), not a single document. Its easydo template id is the envelope GUID sent to the Send Envelope operation. When off, it is a classic single-document template." `
    -DescHe "כאשר פעיל, שורת תבנית זו מייצגת מעטפת easydo (חבילת מסמכים), ולא מסמך יחיד. מזהה תבנית ה-easydo שלה הוא ה-GUID של המעטפה הנשלח לפעולת שליחת המעטפה. כאשר כבוי, מדובר בתבנית קלאסית של מסמך יחיד." `
    -Default $false)

# ---- 4) Scope a field value to a specific document -----------------------
New-DVLookup -Schema "alex_TemplateId" -En "Signature Template" -He "תבנית חתימה" `
    -DescEn "The specific document (template) in the envelope this field value belongs to. Empty for a classic single-document request. Distinguishes a repeated field name across bundle members." `
    -DescHe "המסמך (התבנית) הספציפי במעטפה שאליו שייך ערך שדה זה. ריק עבור בקשה קלאסית של מסמך יחיד. מבחין בין שם שדה החוזר על עצמו בין חברי החבילה." `
    -ReferencedTable "alex_signaturetemplate" -ReferencingTable "alex_signaturefieldvalue" `
    -RelationshipName "alex_signaturetemplate_signaturefieldvalue" -Required "None"

# ---- Publish -------------------------------------------------------------
Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done. Envelope schema (Phase 1) provisioned."
