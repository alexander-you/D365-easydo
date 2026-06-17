<#
  Metadata builder helpers for Dataverse Web API table/column/choice creation.
  Depends on dv-common.ps1 (Connect-Dataverse, Invoke-DV, New-DVLabel).
  All create calls add components to the alex_d365_easydo solution via header.
#>

$script:SolutionUnique = "alex_d365_easydo"

function Get-SolHeader { return @{ "MSCRM.SolutionUniqueName" = $script:SolutionUnique } }

# ----- Attribute builders -------------------------------------------------

function New-DVPrimaryName {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe, [int]$MaxLength = 200)
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName    = $Schema
        MaxLength     = $MaxLength
        FormatName    = @{ Value = "Text" }
        RequiredLevel = @{ Value = "ApplicationRequired" }
        IsPrimaryName = $true
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
    }
}

function New-DVString {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe,
          [int]$MaxLength = 200, [string]$Required = "None", [string]$Format = "Text")
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName    = $Schema
        MaxLength     = $MaxLength
        FormatName    = @{ Value = $Format }
        RequiredLevel = @{ Value = $Required }
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
    }
}

function New-DVMemo {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe,
          [int]$MaxLength = 4000, [string]$Required = "None")
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
        SchemaName    = $Schema
        MaxLength     = $MaxLength
        RequiredLevel = @{ Value = $Required }
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
    }
}

function New-DVInt {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe,
          [int]$Min = 0, [int]$Max = 2147483647, [string]$Required = "None")
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
        SchemaName    = $Schema
        MinValue      = $Min
        MaxValue      = $Max
        RequiredLevel = @{ Value = $Required }
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
    }
}

function New-DVDateTime {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe,
          [string]$Required = "None", [string]$Format = "DateAndTime")
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
        SchemaName    = $Schema
        Format        = $Format
        DateTimeBehavior = @{ Value = "UserLocal" }
        RequiredLevel = @{ Value = $Required }
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
    }
}

function New-DVBool {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe,
          [string]$TrueEn = "Yes", [string]$TrueHe = "כן", [string]$FalseEn = "No", [string]$FalseHe = "לא",
          [bool]$Default = $false)
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
        SchemaName    = $Schema
        DefaultValue  = $Default
        RequiredLevel = @{ Value = "None" }
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
        OptionSet     = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.BooleanOptionSetMetadata"
            TrueOption  = @{ Value = 1; Label = (New-DVLabel -En $TrueEn -He $TrueHe) }
            FalseOption = @{ Value = 0; Label = (New-DVLabel -En $FalseEn -He $FalseHe) }
        }
    }
}

function New-DVPicklistGlobal {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe,
          [string]$GlobalOptionSetName, [string]$Required = "None")
    $osId = (Invoke-DV GET "GlobalOptionSetDefinitions(Name='$GlobalOptionSetName')?`$select=MetadataId").MetadataId
    if (-not $osId) { throw "Global option set '$GlobalOptionSetName' not found." }
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
        SchemaName    = $Schema
        RequiredLevel = @{ Value = $Required }
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
        "GlobalOptionSet@odata.bind" = "/GlobalOptionSetDefinitions($osId)"
    }
}

function New-DVFile {
    param([string]$Schema, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe, [int]$MaxSizeKB = 32768)
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.FileAttributeMetadata"
        SchemaName    = $Schema
        MaxSizeInKB   = $MaxSizeKB
        RequiredLevel = @{ Value = "None" }
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
    }
}

# ----- Table / column / choice operations ---------------------------------

function Test-DVTable {
    param([string]$LogicalName)
    try {
        $r = Invoke-DV GET "EntityDefinitions(LogicalName='$LogicalName')?`$select=LogicalName,MetadataId" -Silent
        return $r
    } catch { return $null }
}

function New-DVTable {
    param(
        [string]$Schema, [string]$En, [string]$He, [string]$CollEn, [string]$CollHe,
        [string]$DescEn, [string]$DescHe, [hashtable]$PrimaryName,
        [string]$TableType = "Standard", [bool]$HasNotes = $false, [bool]$HasActivities = $false
    )
    $logical = $Schema.ToLower()
    $exists = Test-DVTable -LogicalName $logical
    if ($exists) { Write-Output "Table exists: $logical (MetadataId $($exists.MetadataId))"; return $exists.MetadataId }

    $body = @{
        "@odata.type"          = "Microsoft.Dynamics.CRM.EntityMetadata"
        SchemaName             = $Schema
        DisplayName            = (New-DVLabel -En $En -He $He)
        DisplayCollectionName  = (New-DVLabel -En $CollEn -He $CollHe)
        Description            = (New-DVLabel -En $DescEn -He $DescHe)
        OwnershipType          = "UserOwned"
        TableType              = $TableType
        HasActivities          = $HasActivities
        HasNotes               = $HasNotes
        IsActivity             = $false
        Attributes             = @($PrimaryName)
    }
    if ($TableType -eq "Elastic") {
        # Elastic tables share virtual-entity validation; charts are not supported.
        $body.CanCreateCharts = @{ Value = $false }
    }
    $res = Invoke-DV POST "EntityDefinitions" -Body $body -ExtraHeaders (Get-SolHeader) -ReturnHeaders
    Write-Output "Created table $logical (status $($res.Status), type $TableType)"
    $v = Test-DVTable -LogicalName $logical
    return $v.MetadataId
}

function Add-DVColumn {
    param([string]$TableLogical, [hashtable]$Attribute)
    $schema = $Attribute.SchemaName
    $logical = $schema.ToLower()
    # idempotency: skip if already present
    try {
        $existing = Invoke-DV GET "EntityDefinitions(LogicalName='$TableLogical')/Attributes(LogicalName='$logical')?`$select=LogicalName" -Silent
        if ($existing) { Write-Output "  column exists: $logical"; return }
    } catch { }
    Invoke-DV POST "EntityDefinitions(LogicalName='$TableLogical')/Attributes" -Body $Attribute -ExtraHeaders (Get-SolHeader) | Out-Null
    Write-Output "  + column $logical"
}

function New-DVGlobalChoice {
    param([string]$Name, [string]$En, [string]$He, [string]$DescEn, [string]$DescHe, [array]$Options)
    # Options: array of @{ Value=; En=; He=; DescEn=; DescHe= }
    try {
        $existing = Invoke-DV GET "GlobalOptionSetDefinitions(Name='$Name')?`$select=Name" -Silent
        if ($existing) { Write-Output "Choice exists: $Name"; return }
    } catch { }
    $opts = foreach ($o in $Options) {
        $opt = @{ Label = (New-DVLabel -En $o.En -He $o.He) }
        if ($null -ne $o.Value -and $o.Value -gt 0) { $opt.Value = $o.Value }
        if ($o.DescEn) { $opt.Description = (New-DVLabel -En $o.DescEn -He $o.DescHe) }
        $opt
    }
    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
        Name          = $Name
        OptionSetType = "Picklist"
        IsGlobal      = $true
        DisplayName   = (New-DVLabel -En $En -He $He)
        Description   = (New-DVLabel -En $DescEn -He $DescHe)
        Options       = @($opts)
    }
    Invoke-DV POST "GlobalOptionSetDefinitions" -Body $body -ExtraHeaders (Get-SolHeader) | Out-Null
    Write-Output "Created choice: $Name"
}

function New-DVLookup {
    param(
        [string]$Schema,            # alex_Template
        [string]$En, [string]$He, [string]$DescEn, [string]$DescHe,
        [string]$ReferencedTable,   # alex_signaturetemplate
        [string]$ReferencingTable,  # alex_signaturerequest
        [string]$RelationshipName,  # alex_signaturetemplate_signaturerequest
        [string]$Required = "None"
    )
    try {
        $existing = Invoke-DV GET "RelationshipDefinitions(SchemaName='$RelationshipName')?`$select=SchemaName" -Silent
        if ($existing) { Write-Output "  relationship exists: $RelationshipName"; return }
    } catch { }
    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata"
        SchemaName               = $RelationshipName
        ReferencedEntity         = $ReferencedTable
        ReferencingEntity        = $ReferencingTable
        Lookup = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
            SchemaName    = $Schema
            RequiredLevel = @{ Value = $Required }
            DisplayName   = (New-DVLabel -En $En -He $He)
            Description   = (New-DVLabel -En $DescEn -He $DescHe)
        }
        CascadeConfiguration = @{
            Assign = "NoCascade"; Delete = "RemoveLink"; Merge = "NoCascade";
            Reparent = "NoCascade"; Share = "NoCascade"; Unshare = "NoCascade"
        }
    }
    Invoke-DV POST "RelationshipDefinitions" -Body $body -ExtraHeaders (Get-SolHeader) | Out-Null
    Write-Output "  + lookup $Schema ($ReferencingTable -> $ReferencedTable)"
}
