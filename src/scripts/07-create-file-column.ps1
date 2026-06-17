<#
  Adds the File column that stores the actual document binary (e.g. signed PDF)
  in Dataverse File storage on the Signature Document table.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_signaturedocument"
Add-DVColumn $t (New-DVFile -Schema "alex_DocumentFile" `
    -En "Document File" -He "קובץ מסמך" `
    -DescEn "The actual document file content (such as the signed PDF) stored securely in Dataverse." `
    -DescHe "תוכן קובץ המסמך בפועל (כגון ה-PDF החתום) המאוחסן באופן מאובטח ב-Dataverse." `
    -MaxSizeKB 32768)

Write-Output "File column processed."
