<#
  57-create-item-form.ps1

  Main form for alex_signaturerequestitem (envelope document item).

  Each row is a single document inside a multi-document envelope. Its fields are
  written by the read/check flows (easydo form id, status, signing link, signed
  date), so the whole form is exposed READ-ONLY - users open an item to inspect
  it, never to edit it. Editing happens through the envelope send / poll flows.

  Fields shown (all disabled): alex_name, alex_signaturerequestid, alex_templateid,
  alex_sequence, alex_itemstatus, alex_externalformid, alex_stepid, alex_formslug,
  alex_fillurl, alex_signedon.

  Also refreshes a couple of useful public views. Idempotent: updates the existing
  main form / views in place. Adds components to alex_d365_easydo and publishes.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$SolHeader = @{ "MSCRM.SolutionUniqueName" = "alex_d365_easydo" }

$ClassId = @{
    String   = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
    Memo     = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
    Integer  = "{C6D124CA-7EDA-4a60-AAD6-1F44F8FB6E5E}"
    DateTime = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
    Boolean  = "{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}"
    Picklist = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
    Lookup   = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
}

function Get-Esc([string]$s) { return [System.Security.SecurityElement]::Escape($s) }

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

# Read-only field cell (disabled="true")
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
                  <control id="$Field" classid="$cid" datafieldname="$Field" disabled="true" />
                </cell>
"@
}

function New-FormXml {
    param([hashtable]$Meta, [array]$Sections)
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
$t = 'alex_signaturerequestitem'
Write-Output "Loading metadata for $t ..."
$meta = Get-TableMeta -Table $t
Write-Output "  otc=$($meta.Otc)"

Write-Output "== $t =="
New-MainForm -Table $t -Meta $meta -NameEn "Information" -NameHe "מידע" `
    -DescEn "Read-only main form for a single document inside a multi-document envelope. Fields are maintained by the send / status-check flows." `
    -DescHe "טופס ראשי לקריאה בלבד עבור מסמך בודד בתוך מעטפה מרובת-מסמכים. השדות מתוחזקים על ידי זרימות השליחה ובדיקת הסטטוס." `
    -Sections @(
        @{ En="Document"; He="מסמך"; Fields=@('alex_name','alex_signaturerequestid','alex_templateid','alex_sequence','alex_itemstatus') }
        @{ En="easydo Tracking"; He="מעקב easydo"; Fields=@('alex_externalformid','alex_stepid','alex_formslug','alex_fillurl','alex_signedon') }
    )

New-PublicView -Table $t -Meta $meta -NameEn "Envelope Documents" `
    -DescEn "All documents that make up multi-document envelopes." `
    -Columns @('alex_name','alex_signaturerequestid','alex_sequence','alex_itemstatus','alex_signedon') -OrderBy 'alex_sequence' -IsDefault $true
New-PublicView -Table $t -Meta $meta -NameEn "Documents Waiting For Signature" `
    -DescEn "Envelope documents that are still pending or waiting to be signed." `
    -Columns @('alex_name','alex_signaturerequestid','alex_itemstatus','alex_fillurl') -OrderBy 'alex_sequence'

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
