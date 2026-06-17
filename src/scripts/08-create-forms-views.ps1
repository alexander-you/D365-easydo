<#
  Creates a meaningful main form and useful system views for each table via Web API.
  - Forms: systemform records (type=2 Main) with bilingual tab/section/field labels.
  - Views: savedquery records (querytype=0 public) with FetchXml + LayoutXml.
  Attribute control types and labels are read from live metadata so the XML stays valid.
  Components are added to the alex_d365_easydo solution and published at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$SolHeader = @{ "MSCRM.SolutionUniqueName" = "alex_d365_easydo" }

# classid by attribute type
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

function Get-Esc([string]$s) { return [System.Security.SecurityElement]::Escape($s) }

# Returns a map: logicalname -> @{ Type; En; He } and table objecttypecode + primaryid
function Get-TableMeta {
    param([string]$Table)
    $md = Invoke-DV GET ("EntityDefinitions(LogicalName='$Table')?`$select=ObjectTypeCode,PrimaryIdAttribute,PrimaryNameAttribute" +
        "&`$expand=Attributes(`$select=LogicalName,AttributeType,DisplayName)")
    $map = @{}
    foreach ($a in $md.Attributes) {
        $en = $null; $he = $null
        if ($a.DisplayName -and $a.DisplayName.LocalizedLabels) {
            foreach ($l in $a.DisplayName.LocalizedLabels) {
                if ($l.LanguageCode -eq 1033) { $en = $l.Label }
                if ($l.LanguageCode -eq 1037) { $he = $l.Label }
            }
        }
        $map[$a.LogicalName] = @{ Type = $a.AttributeType; En = $en; He = $he }
    }
    return @{ Otc = $md.ObjectTypeCode; PrimaryId = $md.PrimaryIdAttribute; PrimaryName = $md.PrimaryNameAttribute; Attr = $map }
}

function New-FieldCell {
    param([hashtable]$Meta, [string]$Field)
    $a = $Meta.Attr[$Field]
    if (-not $a) { Write-Host "    (skip missing field $Field)"; return $null }
    $cid = $ClassId[$a.Type]
    if (-not $cid) { Write-Host "    (skip unsupported type $($a.Type) for $Field)"; return $null }
    $en = if ($a.En) { $a.En } else { $Field }
    $he = if ($a.He) { $a.He } else { $en }
    $cellId = "{" + [guid]::NewGuid().ToString() + "}"
    return @"
                <cell id="$cellId" showlabel="true">
                  <labels><label description="$(Get-Esc $en)" languagecode="1033" /><label description="$(Get-Esc $he)" languagecode="1037" /></labels>
                  <control id="$Field" classid="$cid" datafieldname="$Field" />
                </cell>
"@
}

function New-FormXml {
    param([hashtable]$Meta, [array]$Sections)
    # Sections: array of @{ En; He; Fields=@(...) }
    $secXml = ""
    $si = 0
    foreach ($s in $Sections) {
        $si++
        $rows = ""
        foreach ($f in $s.Fields) {
            $cell = New-FieldCell -Meta $Meta -Field $f
            if ($cell) { $rows += "              <row>`n$cell`n              </row>`n" }
        }
        if (-not $rows) { continue }
        $secXml += @"
            <section name="sec_$si" showlabel="true" showbar="false" columns="1" labelwidth="180" celllabelalignment="Left" celllabelposition="Left">
              <labels><label description="$(Get-Esc $s.En)" languagecode="1033" /><label description="$(Get-Esc $s.He)" languagecode="1037" /></labels>
              <rows>
$rows              </rows>
            </section>
"@
    }
    return @"
<form>
  <tabs>
    <tab name="tab_general" expanded="true" verticallayout="true">
      <labels><label description="General" languagecode="1033" /><label description="כללי" languagecode="1037" /></labels>
      <columns>
        <column width="100%">
          <sections>
$secXml
          </sections>
        </column>
      </columns>
    </tab>
  </tabs>
</form>
"@
}

function New-MainForm {
    param([string]$Table, [hashtable]$Meta, [string]$NameEn, [string]$NameHe, [string]$DescEn, [string]$DescHe, [array]$Sections)
    $xml = New-FormXml -Meta $Meta -Sections $Sections
    # Update the existing main form (the auto-generated default) so it becomes meaningful.
    $existing = Invoke-DV GET "systemforms?`$select=formid,name&`$filter=objecttypecode eq '$Table' and type eq 2" -Silent
    if ($existing.value -and $existing.value.Count -gt 0) {
        $fid = $existing.value[0].formid
        Invoke-DV PATCH "systemforms($fid)" -Body @{ name = $NameEn; description = $DescEn; formxml = $xml } -ExtraHeaders $SolHeader | Out-Null
        Write-Output "  ~ updated main form: $Table / $NameEn"
        return
    }
    Invoke-DV POST "systemforms" -Body @{ type = 2; objecttypecode = $Table; name = $NameEn; description = $DescEn; formxml = $xml; formactivationstate = 1 } -ExtraHeaders $SolHeader | Out-Null
    Write-Output "  + main form: $Table / $NameEn"
}

function New-PublicView {
    param([string]$Table, [hashtable]$Meta, [string]$NameEn, [string]$DescEn, [array]$Columns, [string]$OrderBy, [bool]$IsDefault = $false)
    $existing = Invoke-DV GET "savedqueries?`$select=savedqueryid,name&`$filter=returnedtypecode eq '$Table' and name eq '$(Get-Esc $NameEn)'" -Silent
    $attrs = ""
    $cells = ""
    foreach ($c in $Columns) {
        if (-not $Meta.Attr.ContainsKey($c)) { continue }
        $attrs += "<attribute name=`"$c`" />"
        $w = if ($c -eq $Meta.PrimaryName) { 250 } else { 150 }
        $cells += "<cell name=`"$c`" width=`"$w`" />"
    }
    if (-not $OrderBy) { $OrderBy = $Meta.PrimaryName }
    $fetch = "<fetch version=`"1.0`" mapping=`"logical`" returntotalrecordcount=`"true`" no-lock=`"true`"><entity name=`"$Table`">$attrs<order attribute=`"$OrderBy`" descending=`"false`" /></entity></fetch>"
    $layout = "<grid name=`"resultset`" object=`"$($Meta.Otc)`" jump=`"$($Meta.PrimaryName)`" select=`"1`" icon=`"1`" preview=`"1`"><row name=`"result`" id=`"$($Meta.PrimaryId)`">$cells</row></grid>"
    if ($existing.value -and $existing.value.Count -gt 0) {
        $qid = $existing.value[0].savedqueryid
        Invoke-DV PATCH "savedqueries($qid)" -Body @{ description = $DescEn; fetchxml = $fetch; layoutxml = $layout } -ExtraHeaders $SolHeader | Out-Null
        Write-Output "  ~ updated view: $Table / $NameEn"
        return
    }
    Invoke-DV POST "savedqueries" -Body @{ returnedtypecode = $Table; name = $NameEn; description = $DescEn; fetchxml = $fetch; layoutxml = $layout; querytype = 0; isdefault = $IsDefault } -ExtraHeaders $SolHeader | Out-Null
    Write-Output "  + view: $Table / $NameEn"
}

# ======================================================================
Write-Output "Loading metadata..."
$m = @{}
foreach ($t in @('alex_signaturetemplate','alex_signaturerequest','alex_templatefieldmapping','alex_signaturerecipient','alex_signaturedocument','alex_integrationlog')) {
    $m[$t] = Get-TableMeta -Table $t
    Write-Output "  $t otc=$($m[$t].Otc)"
}

# ---------------- Signature Template ----------------
$t = 'alex_signaturetemplate'
Write-Output "== $t =="
New-MainForm -Table $t -Meta $m[$t] -NameEn "Information" -NameHe "מידע" -DescEn "Main form for a signature template." -DescHe "טופס ראשי לתבנית חתימה." -Sections @(
    @{ En="Template Details"; He="פרטי תבנית"; Fields=@('alex_name','alex_templatesummary','alex_isactive','alex_language','alex_defaultdeliverymethod') }
    @{ En="EasyDoc Configuration"; He="תצורת EasyDoc"; Fields=@('alex_externaltemplateid','alex_templateversion','alex_relateddynamicstable','alex_supportspreview','alex_supportsmultiplesigners','alex_lastsyncedon') }
)
New-PublicView -Table $t -Meta $m[$t] -NameEn "Active Signature Templates" -DescEn "All active signature templates available for use." -Columns @('alex_name','alex_isactive','alex_language','alex_defaultdeliverymethod','alex_externaltemplateid') -IsDefault $true
New-PublicView -Table $t -Meta $m[$t] -NameEn "All Signature Templates" -DescEn "Every signature template regardless of status." -Columns @('alex_name','alex_isactive','alex_templateversion','alex_lastsyncedon')

# ---------------- Signature Request ----------------
$t = 'alex_signaturerequest'
Write-Output "== $t =="
New-MainForm -Table $t -Meta $m[$t] -NameEn "Information" -NameHe "מידע" -DescEn "Main form for a signature request." -DescHe "טופס ראשי לבקשת חתימה." -Sections @(
    @{ En="Request Details"; He="פרטי בקשה"; Fields=@('alex_name','alex_status','alex_templateid','alex_relatedcontactid','alex_language','alex_isdraft') }
    @{ En="Tracking"; He="מעקב"; Fields=@('alex_senton','alex_completedon','alex_cancelledon','alex_ispreviewgenerated','alex_signinglink') }
    @{ En="Support & Diagnostics"; He="תמיכה ואבחון"; Fields=@('alex_externalformid','alex_externaldocumentid','alex_laststatuscheckon','alex_retrycount','alex_errorcode','alex_errormessage') }
)
New-PublicView -Table $t -Meta $m[$t] -NameEn "Active Signature Requests" -DescEn "Signature requests that are in progress." -Columns @('alex_name','alex_status','alex_relatedcontactid','alex_senton','alex_language') -IsDefault $true
New-PublicView -Table $t -Meta $m[$t] -NameEn "Completed Signature Requests" -DescEn "Signature requests that have been completed." -Columns @('alex_name','alex_status','alex_completedon','alex_relatedcontactid') -OrderBy 'alex_completedon'
New-PublicView -Table $t -Meta $m[$t] -NameEn "Requests Needing Attention" -DescEn "Failed or retrying requests that may need support." -Columns @('alex_name','alex_status','alex_errorcode','alex_retrycount','alex_laststatuscheckon')

# ---------------- Template Field Mapping ----------------
$t = 'alex_templatefieldmapping'
Write-Output "== $t =="
New-MainForm -Table $t -Meta $m[$t] -NameEn "Information" -NameHe "מידע" -DescEn "Main form for a template field mapping." -DescHe "טופס ראשי למיפוי שדות תבנית." -Sections @(
    @{ En="Mapping"; He="מיפוי"; Fields=@('alex_name','alex_templateid','alex_dynamicstable','alex_dynamicsfield','alex_defaultvalue') }
    @{ En="EasyDoc Field"; He="שדה EasyDoc"; Fields=@('alex_externalfieldname','alex_externalfieldid','alex_externalfieldtype') }
    @{ En="Behavior"; He="התנהגות"; Fields=@('alex_isrequired','alex_iseditablebeforesend','alex_isvisibletouser') }
)
New-PublicView -Table $t -Meta $m[$t] -NameEn "All Field Mappings" -DescEn "All template field mappings." -Columns @('alex_name','alex_templateid','alex_dynamicsfield','alex_externalfieldname','alex_isrequired') -IsDefault $true

# ---------------- Signature Recipient ----------------
$t = 'alex_signaturerecipient'
Write-Output "== $t =="
New-MainForm -Table $t -Meta $m[$t] -NameEn "Information" -NameHe "מידע" -DescEn "Main form for a signature recipient." -DescHe "טופס ראשי לנמען חתימה." -Sections @(
    @{ En="Recipient"; He="נמען"; Fields=@('alex_name','alex_recipienttype','alex_contactid','alex_externalrecipientname','alex_email','alex_phone','alex_preferredlanguage') }
    @{ En="Signing"; He="חתימה"; Fields=@('alex_signaturerequestid','alex_signingorder','alex_recipientstatus','alex_recipientsigninglink') }
    @{ En="Tracking"; He="מעקב"; Fields=@('alex_recipientsenton','alex_viewedon','alex_signedon','alex_externalprofileid') }
)
New-PublicView -Table $t -Meta $m[$t] -NameEn "All Recipients" -DescEn "All signature recipients." -Columns @('alex_name','alex_recipienttype','alex_email','alex_recipientstatus','alex_signingorder') -IsDefault $true
New-PublicView -Table $t -Meta $m[$t] -NameEn "Pending Recipients" -DescEn "Recipients who have not yet signed." -Columns @('alex_name','alex_email','alex_recipientstatus','alex_recipientsenton')

# ---------------- Signature Document ----------------
$t = 'alex_signaturedocument'
Write-Output "== $t =="
New-MainForm -Table $t -Meta $m[$t] -NameEn "Information" -NameHe "מידע" -DescEn "Main form for a signature document." -DescHe "טופס ראשי למסמך חתימה." -Sections @(
    @{ En="Document"; He="מסמך"; Fields=@('alex_name','alex_signaturerequestid','alex_documenttype','alex_filename','alex_mimetype','alex_issigned') }
    @{ En="Storage & Source"; He="אחסון ומקור"; Fields=@('alex_documentfile','alex_externalfileid','alex_retrievedon') }
)
New-PublicView -Table $t -Meta $m[$t] -NameEn "All Documents" -DescEn "All signature documents." -Columns @('alex_name','alex_documenttype','alex_filename','alex_issigned','alex_retrievedon') -IsDefault $true
New-PublicView -Table $t -Meta $m[$t] -NameEn "Signed Documents" -DescEn "Final signed documents." -Columns @('alex_name','alex_filename','alex_retrievedon') -OrderBy 'alex_retrievedon'

# ---------------- Integration Log (elastic) ----------------
$t = 'alex_integrationlog'
Write-Output "== $t =="
try {
    New-MainForm -Table $t -Meta $m[$t] -NameEn "Information" -NameHe "מידע" -DescEn "Main form for an integration log entry." -DescHe "טופס ראשי לרשומת יומן אינטגרציה." -Sections @(
        @{ En="Event"; He="אירוע"; Fields=@('alex_name','alex_eventtype','alex_operationname','alex_direction','alex_result','alex_summary') }
        @{ En="Timing"; He="תזמון"; Fields=@('alex_startedon','alex_completedon','alex_durationms') }
        @{ En="Correlation & Errors"; He="מתאם ושגיאות"; Fields=@('alex_signaturerequestref','alex_correlationid','alex_externalreference','alex_errorcode','alex_errormessage') }
    )
} catch { Write-Output "  (elastic form not supported: $($_.Exception.Message))" }
try {
    New-PublicView -Table $t -Meta $m[$t] -NameEn "Recent Integration Events" -DescEn "Most recent integration events with EasyDoc." -Columns @('alex_name','alex_eventtype','alex_direction','alex_result','alex_startedon') -OrderBy 'alex_startedon' -IsDefault $true
    New-PublicView -Table $t -Meta $m[$t] -NameEn "Integration Failures" -DescEn "Integration events that failed." -Columns @('alex_name','alex_eventtype','alex_result','alex_errorcode','alex_startedon')
} catch { Write-Output "  (elastic view not supported: $($_.Exception.Message))" }

# ======================================================================
Write-Output "Publishing customizations..."
Invoke-DV POST "PublishAllXml" | Out-Null
Write-Output "All forms and views processed and published."
