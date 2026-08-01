<#
  59-lockdown-forms-and-assoc-views.ps1

  Hardening pass over the easydo signature data tables. Two goals:

  1. READ-ONLY MAIN FORMS
     Every business record in this solution is written by cloud flows / plugins /
     the send-wizard PCF - never hand-edited. So if an end user ever lands on a
     raw main form we lock it: every field control gets disabled="true", making
     the whole form read-only. (Same technique already used for the envelope
     item form in script 57.)

  2. MEANINGFUL ASSOCIATED VIEWS  (querytype = 2)
     ~99.9% of these tables are reached through a related / associated grid, so
     the associated view is what users actually see. For each table we rebuild
     that view with a hand-picked set of meaningful columns and a sensible sort
     order, and we give it a FULL, properly localized name in both English (1033)
     and Hebrew (1037) via SetLocLabels - e.g. "Signature Field Value Associated
     View" / "ערך שדה חתימה - תצוגה משויכת".

  Scope: the 9 signature *data* tables. The two admin-config tables
  (alex_easydosettings, alex_easydoentityconfig) are intentionally left editable
  because they are configured by admins through the Admin Center, not raw forms.

  Idempotent + re-runnable. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$SolHeader = @{ "MSCRM.SolutionUniqueName" = "alex_d365_easydo" }

$ClassId = @{
    String   = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
    Memo     = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
    Integer  = "{C6D124CA-7EDA-4a60-AAD6-1F44F8FB6E5E}"
    BigInt   = "{C6D124CA-7EDA-4a60-AAD6-1F44F8FB6E5E}"
    DateTime = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
    Boolean  = "{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}"
    Picklist = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
    Lookup   = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
    Customer = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
    Owner    = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
    Money    = "{533B9E00-756B-4312-95A0-DC888637AC78}"
}

function Get-TableMeta {
    param([string]$Table)
    $md = Invoke-DV GET ("EntityDefinitions(LogicalName='$Table')?`$select=ObjectTypeCode,PrimaryIdAttribute,PrimaryNameAttribute" +
        "&`$expand=Attributes(`$select=LogicalName,AttributeType)") -Silent
    $map = @{}
    foreach ($a in $md.Attributes) { $map[$a.LogicalName] = $a.AttributeType }
    return @{ Otc = $md.ObjectTypeCode; PrimaryId = $md.PrimaryIdAttribute; PrimaryName = $md.PrimaryNameAttribute; Attr = $map }
}

# --- 1. read-only main forms -------------------------------------------------
function Set-FormsReadOnly {
    param([string]$Table)
    $forms = Invoke-DV GET "systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$Table' and type eq 2" -Silent
    if (-not $forms.value -or $forms.value.Count -eq 0) { Write-Output "    (no main form for $Table)"; return }
    foreach ($f in $forms.value) {
        $xml = $f.formxml
        if (-not $xml) { continue }
        # Force every field control to disabled="true".
        $xml = [regex]::Replace($xml, 'disabled\s*=\s*"[^"]*"', 'disabled="true"')          # normalize existing
        $xml = [regex]::Replace($xml, '<control\b(?![^>]*\bdisabled=)', '<control disabled="true"') # add where missing
        try {
            Invoke-DV PATCH "systemforms($($f.formid))" -Body @{ formxml = $xml } -ExtraHeaders $SolHeader | Out-Null
            Write-Output "    ~ locked form '$($f.name)'"
        } catch { Write-Output "    ! form '$($f.name)' patch failed: $($_.Exception.Message)" }
    }
}

# --- 2. associated view (columns + sort + bilingual name) --------------------
function Set-AssociatedView {
    param(
        [string]$Table, [hashtable]$Meta, [string[]]$Columns,
        [string]$OrderBy, [bool]$Descending, [string]$NameEn, [string]$NameHe
    )
    $q = Invoke-DV GET "savedqueries?`$select=savedqueryid,name&`$filter=returnedtypecode eq '$Table' and querytype eq 2" -Silent
    if (-not $q.value -or $q.value.Count -eq 0) { Write-Output "    (no associated view for $Table)"; return }
    $qid = $q.value[0].savedqueryid

    $attrs = ""; $cells = ""
    foreach ($c in $Columns) {
        if (-not $Meta.Attr.ContainsKey($c)) { Write-Output "      (skip missing col $c)"; continue }
        $attrs += "<attribute name=`"$c`" />"
        $t = $Meta.Attr[$c]
        $w = if ($c -eq $Meta.PrimaryName) { 260 }
             elseif ($t -eq 'Lookup' -or $t -eq 'Customer' -or $t -eq 'Owner') { 200 }
             elseif ($t -eq 'DateTime') { 150 }
             elseif ($t -eq 'Boolean') { 110 }
             elseif ($t -eq 'Memo') { 300 }
             else { 150 }
        $cells += "<cell name=`"$c`" width=`"$w`" />"
    }
    if (-not $OrderBy) { $OrderBy = $Meta.PrimaryName }
    $desc = if ($Descending) { "true" } else { "false" }
    $fetch = "<fetch version=`"1.0`" mapping=`"logical`" returntotalrecordcount=`"true`" no-lock=`"true`"><entity name=`"$Table`">$attrs<order attribute=`"$OrderBy`" descending=`"$desc`" /></entity></fetch>"
    $layout = "<grid name=`"resultset`" object=`"$($Meta.Otc)`" jump=`"$($Meta.PrimaryName)`" select=`"1`" icon=`"1`" preview=`"1`"><row name=`"result`" id=`"$($Meta.PrimaryId)`">$cells</row></grid>"

    Invoke-DV PATCH "savedqueries($qid)" -Body @{ fetchxml = $fetch; layoutxml = $layout } -ExtraHeaders $SolHeader | Out-Null

    # Bilingual, fully-descriptive view name (per-language, not a single string).
    $loc = @{
        EntityMoniker = @{ savedqueryid = $qid; '@odata.type' = 'Microsoft.Dynamics.CRM.savedquery' }
        AttributeName = 'name'
        Labels        = @(
            @{ LanguageCode = 1033; Label = $NameEn },
            @{ LanguageCode = 1037; Label = $NameHe }
        )
    }
    Invoke-DV POST "SetLocLabels" -Body $loc | Out-Null
    Write-Output "    ~ associated view rebuilt + named '$NameHe' / '$NameEn'"
}

# ============================================================================
# Table plan: form-lock + associated-view columns / sort / bilingual name.
# ============================================================================
$plan = @(
    @{ t = 'alex_signaturerequest'; lock = $true
       en = 'Signature Request Associated View'; he = 'בקשת חתימה - תצוגה משויכת'
       cols = @('alex_name','alex_status','alex_relatedcontactid','alex_senton','alex_completedon','alex_laststatuscheckon')
       order = 'alex_senton'; desc = $true }

    @{ t = 'alex_signaturerequestitem'; lock = $true
       en = 'Signature Request Item Associated View'; he = 'פריט בקשת חתימה - תצוגה משויכת'
       cols = @('alex_sequence','alex_name','alex_templateid','alex_itemstatus','alex_signedon','alex_externalformid')
       order = 'alex_sequence'; desc = $false }

    @{ t = 'alex_signaturefieldvalue'; lock = $true
       en = 'Signature Field Value Associated View'; he = 'ערך שדה חתימה - תצוגה משויכת'
       cols = @('alex_name','alex_fieldname','alex_fieldlabel','alex_value','alex_direction','alex_isreadonly')
       order = 'alex_fieldname'; desc = $false }

    @{ t = 'alex_signaturerecipient'; lock = $true
       en = 'Signature Recipient Associated View'; he = 'נמען לחתימה - תצוגה משויכת'
       cols = @('alex_name','alex_recipienttype','alex_email','alex_phone','alex_recipientstatus','alex_signingorder','alex_signedon')
       order = 'alex_signingorder'; desc = $false }

    @{ t = 'alex_signaturedocument'; lock = $true
       en = 'Signature Document Associated View'; he = 'מסמך חתימה - תצוגה משויכת'
       cols = @('alex_name','alex_documenttype','alex_filename','alex_issigned','alex_retrievedon')
       order = 'alex_retrievedon'; desc = $true }

    @{ t = 'alex_signaturetemplate'; lock = $true
       en = 'Signature Template Associated View'; he = 'תבנית חתימה - תצוגה משויכת'
       cols = @('alex_name','alex_isactive','alex_language','alex_defaultdeliverymethod','alex_externaltemplateid','alex_lastsyncedon')
       order = 'alex_name'; desc = $false }

    @{ t = 'alex_templatefieldmapping'; lock = $true
       en = 'Template Field Mapping Associated View'; he = 'מיפוי שדות תבנית - תצוגה משויכת'
       cols = @('alex_name','alex_dynamicsfield','alex_externalfieldname','alex_isrequired','alex_isvisibletouser','alex_iseditablebeforesend')
       order = 'alex_name'; desc = $false }

    @{ t = 'alex_envelopetemplateitem'; lock = $true
       en = 'Envelope Item Associated View'; he = 'פריט מעטפה - תצוגה משויכת'
       cols = @('alex_sequence','alex_name','alex_templateid','alex_defaultroleid','alex_externaltemplateid','alex_lastsyncedon')
       order = 'alex_sequence'; desc = $false }

    @{ t = 'alex_integrationlog'; lock = $true
       en = 'Integration Log Associated View'; he = 'יומן אינטגרציה - תצוגה משויכת'
       cols = @('alex_name','alex_eventtype','alex_direction','alex_result','alex_startedon','alex_durationms')
       order = 'alex_startedon'; desc = $true }
)

foreach ($p in $plan) {
    Write-Output "== $($p.t) =="
    $meta = Get-TableMeta -Table $p.t
    if ($p.lock) { Set-FormsReadOnly -Table $p.t }
    Set-AssociatedView -Table $p.t -Meta $meta -Columns $p.cols -OrderBy $p.order -Descending $p.desc -NameEn $p.en -NameHe $p.he
}

Write-Output "Publishing customizations..."
Invoke-DV POST "PublishAllXml" | Out-Null
Write-Output "Done. Main forms locked read-only + associated views rebuilt and bilingually named."
