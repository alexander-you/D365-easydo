<#
  Creates the One-to-Many relationships (lookups) of the data model.
  Note: the elastic alex_integrationlog table does not support relationships,
  so it references the signature request via the string column
  alex_signaturerequestref instead of a lookup (by design).
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# Template (1) -> Field Mapping (N)
New-DVLookup -Schema "alex_TemplateId" -En "Signature Template" -He "תבנית חתימה" `
    -DescEn "The signature template this field mapping belongs to." `
    -DescHe "תבנית החתימה שאליה שייך מיפוי שדה זה." `
    -ReferencedTable "alex_signaturetemplate" -ReferencingTable "alex_templatefieldmapping" `
    -RelationshipName "alex_signaturetemplate_templatefieldmapping" -Required "ApplicationRequired"

# Template (1) -> Signature Request (N)
New-DVLookup -Schema "alex_TemplateId" -En "Signature Template" -He "תבנית חתימה" `
    -DescEn "The template used to generate this signature request." `
    -DescHe "התבנית ששימשה ליצירת בקשת חתימה זו." `
    -ReferencedTable "alex_signaturetemplate" -ReferencingTable "alex_signaturerequest" `
    -RelationshipName "alex_signaturetemplate_signaturerequest"

# Signature Request (1) -> Recipient (N)
New-DVLookup -Schema "alex_SignatureRequestId" -En "Signature Request" -He "בקשת חתימה" `
    -DescEn "The signature request this recipient is required to sign." `
    -DescHe "בקשת החתימה שנמען זה נדרש לחתום עליה." `
    -ReferencedTable "alex_signaturerequest" -ReferencingTable "alex_signaturerecipient" `
    -RelationshipName "alex_signaturerequest_signaturerecipient" -Required "ApplicationRequired"

# Signature Request (1) -> Document (N)
New-DVLookup -Schema "alex_SignatureRequestId" -En "Signature Request" -He "בקשת חתימה" `
    -DescEn "The signature request this document is associated with." `
    -DescHe "בקשת החתימה שאליה משויך מסמך זה." `
    -ReferencedTable "alex_signaturerequest" -ReferencingTable "alex_signaturedocument" `
    -RelationshipName "alex_signaturerequest_signaturedocument" -Required "ApplicationRequired"

# Contact (1) -> Recipient (N)  [recipient links to a Dynamics contact]
New-DVLookup -Schema "alex_ContactId" -En "Contact" -He "איש קשר" `
    -DescEn "The Dynamics 365 contact this recipient represents, when the recipient is an existing contact." `
    -DescHe "איש הקשר ב-Dynamics 365 שנמען זה מייצג, כאשר הנמען הוא איש קשר קיים." `
    -ReferencedTable "contact" -ReferencingTable "alex_signaturerecipient" `
    -RelationshipName "alex_contact_signaturerecipient"

# Contact (1) -> Signature Request (N)  [source business record for the MVP]
New-DVLookup -Schema "alex_RelatedContactId" -En "Related Contact" -He "איש קשר משויך" `
    -DescEn "The Dynamics 365 contact this signature request was created for." `
    -DescHe "איש הקשר ב-Dynamics 365 שעבורו נוצרה בקשת החתימה." `
    -ReferencedTable "contact" -ReferencingTable "alex_signaturerequest" `
    -RelationshipName "alex_contact_signaturerequest"

Write-Output "All relationships processed."
