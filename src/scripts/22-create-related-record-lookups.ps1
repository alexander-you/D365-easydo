<#
  22-create-related-record-lookups.ps1

  Item ג: dedicated, native lookups from each PRIMARY business table to the
  signature request, so a contact / entitlement / etc. record shows a real
  subgrid of its signature requests (and rollups work), instead of relying on
  the polymorphic text columns alex_relatedtablename + alex_relatedrecordid.

  Driver: the distinct, non-empty alex_primarytable values across all signature
  templates - exactly the set of tables a signature request can be anchored to.

  Convention (matches the pre-existing contact lookup alex_RelatedContactId):
      schema        = alex_Related<Pascal(table)>Id
      logical       = alex_related<table>id
      relationship  = alex_<table>_signaturerequest
      referenced    = <primary table>     referencing = alex_signaturerequest

  contact is skipped (alex_RelatedContactId already exists from script 06).
  Idempotent: New-DVLookup skips relationships that already exist.

  PopulateAnchorPlugin fills the dedicated lookup at request create/update time.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

function ConvertTo-Pascal {
    param([string]$Logical)
    if ([string]::IsNullOrEmpty($Logical)) { return $Logical }
    # Split on underscore so prefixed tables (alex_foo) read as AlexFoo.
    $parts = $Logical.Split('_') | Where-Object { $_ -ne "" }
    return ($parts | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ""
}

# Distinct primary tables actually used by templates.
$tables = (Invoke-DV GET "alex_signaturetemplates?`$select=alex_primarytable" -Silent).value |
    ForEach-Object { $_.alex_primarytable } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.ToLower() } |
    Sort-Object -Unique

Write-Output "Primary tables in use: $($tables -join ', ')"

foreach ($table in $tables) {
    if ($table -eq "contact") {
        Write-Output "  skip contact (alex_RelatedContactId already exists)"
        continue
    }

    $pascal  = ConvertTo-Pascal $table
    $schema  = "alex_Related${pascal}Id"
    $relName = "alex_${table}_signaturerequest"

    # Friendly display name from the referenced table's metadata (fallback to logical).
    $display = $table
    try {
        $meta = Invoke-DV GET "EntityDefinitions(LogicalName='$table')?`$select=DisplayName" -Silent
        $lbl = $meta.DisplayName.UserLocalizedLabel.Label
        if ($lbl) { $display = $lbl }
    } catch { }

    New-DVLookup -Schema $schema -En "Related $display" -He "רשומה משויכת ($display)" `
        -DescEn "The $display record this signature request was created for." `
        -DescHe "רשומת ה$display שעבורה נוצרה בקשת החתימה." `
        -ReferencedTable $table -ReferencingTable "alex_signaturerequest" `
        -RelationshipName $relName
}

# Publish so the new lookups are immediately usable on forms/subgrids.
Invoke-DV POST "PublishAllXml" -Silent | Out-Null
Write-Output "Done. Related-record lookups ensured + published."
