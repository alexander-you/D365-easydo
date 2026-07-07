<#
  Property Allocation Board — creates the "Tenant Contract" (alex_tenant_contract)
  table per the attached data dictionary (מבנה נתונים — חוזה לדייר).

  Target solution : PropertyAllocationBoard  (publisher AlexPropertyAllocation, prefix alex)
  Target env      : EN only (demo-contact-center-en) — DV_URL from src/scripts/.env.ps1

  Creates, idempotently and with bilingual EN/HE display names + descriptions:
    - 6 global choices (contract type, status, currency, frequency, method, room type)
    - the alex_tenant_contract table (Notes + Activities enabled -> files/notes)
    - all business columns (Parties, Type & Status, Period, Currency & Pricing,
      Payments & Deposit, Assignment & Property, Prep, Documents & Signature)
    - the Student/Tenant lookup to contact
    - a logical main form (grouped sections + a Notes tab) and public views
  Everything is added to the PropertyAllocationBoard solution and published.

  Web API only (per project convention). No secrets stored.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# Route ALL component creation to the Property Allocation Board solution.
$script:SolutionUnique = "PropertyAllocationBoard"
$SolutionUnique = "PropertyAllocationBoard"
$Table = "alex_tenant_contract"

# --- 0) Verify the target solution + publisher prefix ----------------------
$sol = Invoke-DV GET "solutions?`$select=uniquename,friendlyname,ismanaged,_publisherid_value&`$filter=uniquename eq '$SolutionUnique'"
if (-not $sol.value -or $sol.value.Count -eq 0) { throw "Solution '$SolutionUnique' not found in this environment." }
$pub = Invoke-DV GET "publishers($($sol.value[0]._publisherid_value))?`$select=uniquename,customizationprefix"
if ($pub.customizationprefix -ne "alex") { throw "Solution publisher prefix is '$($pub.customizationprefix)', expected 'alex'." }
Write-Output "Solution: $SolutionUnique (publisher $($pub.uniquename), prefix $($pub.customizationprefix)) managed=$($sol.value[0].ismanaged)"

# =========================================================================
# 1) GLOBAL CHOICES
# =========================================================================
Write-Output "== Global choices =="

New-DVGlobalChoice -Name "alex_contract_type" -En "Contract Type" -He "סוג חוזה" `
    -DescEn "Whether the tenant contract is an Israeli or an International contract." `
    -DescHe "האם חוזה הדייר הוא חוזה ישראלי או בינלאומי." `
    -Options @(
        @{ En="Israeli";       He="ישראלי";   DescEn="Israeli (domestic) tenant contract."; DescHe="חוזה דייר ישראלי (מקומי)." }
        @{ En="International";  He="בינלאומי"; DescEn="International (foreign student) tenant contract."; DescHe="חוזה דייר בינלאומי (סטודנט מחו""ל)." }
    )

New-DVGlobalChoice -Name "alex_contract_status" -En "Contract Status" -He "מצב החוזה" `
    -DescEn "Current business status of the tenant contract." `
    -DescHe "מצב עסקי נוכחי של חוזה הדייר." `
    -Options @(
        @{ En="Sent";      He="נשלח";     DescEn="The contract was sent to the tenant for signature."; DescHe="החוזה נשלח לדייר לחתימה." }
        @{ En="Active";    He="מתבצע";    DescEn="The contract is active and in effect."; DescHe="החוזה פעיל ובתוקף." }
        @{ En="Expired";   He="פג תוקף";  DescEn="The contract period has ended and it is no longer valid."; DescHe="תקופת החוזה הסתיימה והוא אינו בתוקף עוד." }
        @{ En="Inactive";  He="לא פעיל";  DescEn="The contract is inactive."; DescHe="החוזה אינו פעיל." }
    )

New-DVGlobalChoice -Name "alex_payment_currency" -En "Payment Currency" -He "מטבע התשלום" `
    -DescEn "The currency the tenant chose to pay in at signing." `
    -DescHe "המטבע שבו בחר הדייר לשלם במעמד החתימה." `
    -Options @(
        @{ En="ILS";  He="שקל";   DescEn="Israeli New Shekel (ILS)."; DescHe="שקל חדש (ILS)." }
        @{ En="USD";  He="דולר";  DescEn="US Dollar (USD)."; DescHe="דולר אמריקאי (USD)." }
    )

New-DVGlobalChoice -Name "alex_payment_frequency" -En "Payment Frequency" -He "תדירות תשלום" `
    -DescEn "How often the tenant is billed." `
    -DescHe "תדירות החיוב של הדייר." `
    -Options @(
        @{ En="Monthly";   He="חודשי";       DescEn="Billed every month."; DescHe="חיוב מדי חודש." }
        @{ En="Biannual";  He="חצי-שנתי";    DescEn="Billed twice a year (typical for international tenants)."; DescHe="חיוב פעמיים בשנה (נפוץ בחוזים בינלאומיים)." }
    )

New-DVGlobalChoice -Name "alex_room_type" -En "Room / Apartment Type" -He "סוג חדר/דירה" `
    -DescEn "Whether the accommodation is a single unit or shared with roommates." `
    -DescHe "האם המגורים הם יחידה בודדת או בשותפות עם דיירים נוספים." `
    -Options @(
        @{ En="Single";  He="יחיד";     DescEn="Single (private) room or apartment."; DescHe="חדר או דירה ליחיד (פרטי)." }
        @{ En="Shared";  He="שותפים";  DescEn="Room or apartment shared with roommates."; DescHe="חדר או דירה בשותפות." }
    )

# =========================================================================
# 2) TABLE
# =========================================================================
Write-Output "== Table $Table =="
$pn = New-DVPrimaryName -Schema "alex_name" -En "Contract Name / Number" -He "שם/מספר החוזה" `
        -DescEn "Name or number that identifies the tenant contract." `
        -DescHe "שם או מספר המזהה את חוזה הדייר."
New-DVTable -Schema "alex_tenant_contract" `
    -En "Tenant Contract" -He "חוזה לדייר" `
    -CollEn "Tenant Contracts" -CollHe "חוזים לדיירים" `
    -DescEn "A residential tenancy contract between the dormitory management and a student/tenant, including period, pricing, payments, deposit and signature status." `
    -DescHe "חוזה מגורים בין הנהלת המעונות לבין סטודנט/דייר, הכולל תקופה, תמחור, תשלומים, פיקדון ומצב חתימה." `
    -PrimaryName $pn -HasNotes $true -HasActivities $true | Out-Null

# =========================================================================
# 3) COLUMNS
# =========================================================================
Write-Output "== Columns =="

# --- Type & Status -------------------------------------------------------
Add-DVColumn $Table (New-DVPicklistGlobal -Schema "alex_os_contract_type" -En "Contract Type" -He "סוג חוזה" -GlobalOptionSetName "alex_contract_type" `
    -DescEn "Israeli or International." `
    -DescHe "ישראלי או בינלאומי.")
Add-DVColumn $Table (New-DVPicklistGlobal -Schema "alex_os_status" -En "Contract Status" -He "מצב החוזה" -GlobalOptionSetName "alex_contract_status" `
    -DescEn "Sent / Active / Expired / Inactive." `
    -DescHe "נשלח / מתבצע / פג תוקף / לא פעיל.")

# --- Contract Period -----------------------------------------------------
Add-DVColumn $Table (New-DVDateTime -Schema "alex_dt_start" -En "Authorization Start" -He "תחילת הרשאה" `
    -DescEn "Occupancy start date — the beginning of the residency period." `
    -DescHe "תאריך תחילת תקופת המגורים.")
Add-DVColumn $Table (New-DVDateTime -Schema "alex_dt_end" -En "Authorization End" -He "סיום הרשאה" `
    -DescEn "Occupancy end date — the end of the residency period." `
    -DescHe "תאריך סיום תקופת המגורים.")
Add-DVColumn $Table (New-DVInt -Schema "alex_n_contract_months" -En "Contract Duration (Months)" -He "מספר חודשי חוזה" -Min 0 -Max 120 `
    -DescEn "Contract length in months (for example when a preparatory program extends the term)." `
    -DescHe "אורך החוזה בחודשים (למשל בהארכת מכינה).")
Add-DVColumn $Table (New-DVString -Schema "alex_s_academic_year" -En "Academic Year" -He "שנה אקדמית" -MaxLength 20 `
    -DescEn "The academic year the contract applies to (for example 2025/2026)." `
    -DescHe "השנה האקדמית שאליה מתייחס החוזה (למשל 2025/2026).")

# --- Currency & Pricing --------------------------------------------------
Add-DVColumn $Table (New-DVPicklistGlobal -Schema "alex_os_payment_currency" -En "Payment Currency" -He "מטבע התשלום" -GlobalOptionSetName "alex_payment_currency" `
    -DescEn "ILS or USD, per the tenant's choice at signing." `
    -DescHe "שקל או דולר, לפי בחירת הדייר בחתימה.")
Add-DVColumn $Table (New-DVDecimal -Schema "alex_m_exchange_rate_locked" -En "Locked Exchange Rate" -He "שער חליפין נעול" -Precision 4 -Min 0 -Max 1000 `
    -DescEn "The USD exchange rate locked on the contract date." `
    -DescHe "שער הדולר שננעל ליום עריכת החוזה.")
Add-DVColumn $Table (New-DVDateTime -Schema "alex_dt_exchange_rate_date" -En "Exchange Rate Date" -He "תאריך נעילת שער" `
    -DescEn "The date the exchange rate was locked." `
    -DescHe "מועד נעילת שער החליפין.")
Add-DVColumn $Table (New-DVMoney -Schema "alex_m_monthly_rent" -En "Monthly Rent" -He "שכר דירה חודשי" `
    -DescEn "The monthly rent amount." `
    -DescHe "סכום שכר הדירה החודשי.")
Add-DVColumn $Table (New-DVMoney -Schema "alex_m_total_contract" -En "Total Contract Amount" -He "סה""כ החוזה" `
    -DescEn "The total value of the contract." `
    -DescHe "הסכום הכולל של החוזה.")

# --- Payments & Deposit --------------------------------------------------
Add-DVColumn $Table (New-DVPicklistGlobal -Schema "alex_os_payment_frequency" -En "Payment Frequency" -He "תדירות תשלום" -GlobalOptionSetName "alex_payment_frequency" `
    -DescEn "Monthly or biannual (international)." `
    -DescHe "חודשי או חצי-שנתי (בינלאומי).")
Add-DVColumn $Table (New-DVDateTime -Schema "alex_dt_deposit_refund" -En "Deposit Refund Date" -He "תאריך החזר פיקדון" `
    -DescEn "The date the deposit is refunded or offset at move-out." `
    -DescHe "מועד החזר או קיזוז הפיקדון בעזיבה.")

# --- Assignment & Property ----------------------------------------------
Add-DVColumn $Table (New-DVPicklistGlobal -Schema "alex_os_room_type" -En "Room / Apartment Type" -He "סוג חדר/דירה" -GlobalOptionSetName "alex_room_type" `
    -DescEn "Single or shared." `
    -DescHe "יחיד או שותפים.")

# --- Documents & Signature ----------------------------------------------
Add-DVColumn $Table (New-DVBool -Schema "alex_b_signed" -En "Contract Signed" -He "חוזה חתום" `
    -TrueEn "Signed" -TrueHe "חתום" -FalseEn "Not Signed" -FalseHe "לא חתום" `
    -DescEn "Whether the contract has been signed." `
    -DescHe "האם החוזה נחתם.")
Add-DVColumn $Table (New-DVDateTime -Schema "alex_dt_signed" -En "Signature Date" -He "תאריך חתימה" `
    -DescEn "The date the contract was signed." `
    -DescHe "מועד חתימת החוזה.")

# =========================================================================
# 4) LOOKUP — Student / Tenant -> contact
# =========================================================================
Write-Output "== Lookup =="
New-DVLookup -Schema "alex_id_student" -En "Student / Tenant" -He "סטודנט / דייר" `
    -DescEn "Lookup to the student contact who holds the contract." `
    -DescHe "הפנייה לסטודנט (איש הקשר) שהוא בעל החוזה." `
    -ReferencedTable "contact" -ReferencingTable "alex_tenant_contract" `
    -RelationshipName "alex_contact_tenant_contract"

# =========================================================================
# 5) MAIN FORM + VIEWS
# =========================================================================
Write-Output "== Form & Views =="
$SolHeader = Get-SolHeader

$ClassId = @{
    String   = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
    Memo     = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
    Integer  = "{C6D124CA-7EDA-4a60-AAD6-1F44F8FB6E5E}"
    DateTime = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
    Boolean  = "{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}"
    Picklist = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
    Lookup   = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
    Money    = "{533B9E00-756B-4312-95A0-DC888637AC78}"
    Decimal  = "{C3EFE0C3-0EC6-42be-8349-CBD9079DBD8F}"
}
function Get-Esc([string]$s) { return [System.Security.SecurityElement]::Escape($s) }

$md = Invoke-DV GET ("EntityDefinitions(LogicalName='$Table')?`$select=ObjectTypeCode,PrimaryIdAttribute,PrimaryNameAttribute" +
    "&`$expand=Attributes(`$select=LogicalName,AttributeType,DisplayName)")
$Attr = @{}
foreach ($a in $md.Attributes) {
    $en = $null; $he = $null
    if ($a.DisplayName -and $a.DisplayName.LocalizedLabels) {
        foreach ($l in $a.DisplayName.LocalizedLabels) {
            if ($l.LanguageCode -eq 1033) { $en = $l.Label }
            if ($l.LanguageCode -eq 1037) { $he = $l.Label }
        }
    }
    $Attr[$a.LogicalName] = @{ Type = $a.AttributeType; En = $en; He = $he }
}
$Otc = $md.ObjectTypeCode; $PrimaryId = $md.PrimaryIdAttribute; $PrimaryName = $md.PrimaryNameAttribute

# Fields computed by the TenantContractCalcPlugin -> shown read-only on the form.
$ReadOnlyFields = @('alex_n_contract_months', 'alex_m_total_contract')

function New-Cell([string]$Field) {
    $a = $Attr[$Field]
    if (-not $a) { Write-Host "    (skip missing $Field)"; return $null }
    $cid = $ClassId[$a.Type]
    if (-not $cid) { Write-Host "    (skip unsupported type $($a.Type) for $Field)"; return $null }
    $en = if ($a.En) { $a.En } else { $Field }
    $he = if ($a.He) { $a.He } else { $en }
    $disabled = if ($ReadOnlyFields -contains $Field) { ' disabled="true"' } else { '' }
    $cellId = "{" + [guid]::NewGuid().ToString() + "}"
    return @"
                <cell id="$cellId" showlabel="true">
                  <labels><label description="$(Get-Esc $en)" languagecode="1033" /><label description="$(Get-Esc $he)" languagecode="1037" /></labels>
                  <control id="$Field" classid="$cid" datafieldname="$Field"$disabled />
                </cell>
"@
}

$Sections = @(
    @{ En="Parties";               He="צדדים";              Fields=@('alex_name','alex_id_student') }
    @{ En="Type & Status";         He="סוג ומצב";           Fields=@('alex_os_contract_type','alex_os_status') }
    @{ En="Contract Period";       He="תקופת החוזה";        Fields=@('alex_dt_start','alex_dt_end','alex_n_contract_months','alex_s_academic_year') }
    @{ En="Currency & Pricing";    He="מטבע ותמחור";        Fields=@('alex_os_payment_currency','alex_m_monthly_rent','alex_m_total_contract','alex_m_exchange_rate_locked','alex_dt_exchange_rate_date') }
    @{ En="Payments & Deposit";    He="תשלומים ופיקדון";    Fields=@('alex_os_payment_frequency','alex_dt_deposit_refund') }
    @{ En="Assignment & Property"; He="שיבוץ ונכס";         Fields=@('alex_os_room_type') }
    @{ En="Documents & Signature"; He="מסמכים וחתימה";      Fields=@('alex_b_signed','alex_dt_signed') }
)

$secXml = ""
$si = 0
foreach ($s in $Sections) {
    $si++
    $rows = ""
    foreach ($f in $s.Fields) {
        $cell = New-Cell $f
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

# Notes control classid (classic Notes with attachments) for the "Notes" tab.
$notesClassId = "{06375649-C143-495E-A496-C962E5B4488E}"
$formXml = @"
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
    <tab name="tab_notes" expanded="true" verticallayout="true">
      <labels><label description="Notes &amp; Files" languagecode="1033" /><label description="הערות וקבצים" languagecode="1037" /></labels>
      <columns>
        <column width="100%">
          <sections>
            <section name="sec_notes" showlabel="false" showbar="false" columns="1">
              <labels><label description="Notes" languagecode="1033" /><label description="הערות" languagecode="1037" /></labels>
              <rows>
                <row>
                  <cell id="{$([guid]::NewGuid())}" showlabel="false" rowspan="12" colspan="1">
                    <control id="notescontrol" classid="$notesClassId" />
                  </cell>
                </row>
              </rows>
            </section>
          </sections>
        </column>
      </columns>
    </tab>
  </tabs>
</form>
"@

$existingForm = Invoke-DV GET "systemforms?`$select=formid&`$filter=objecttypecode eq '$Table' and type eq 2" -Silent
if ($existingForm.value -and $existingForm.value.Count -gt 0) {
    $fid = $existingForm.value[0].formid
    Invoke-DV PATCH "systemforms($fid)" -Body @{ name = "Information"; description = "Main form for a tenant contract."; formxml = $formXml } -ExtraHeaders $SolHeader | Out-Null
    Write-Output "  ~ updated main form"
} else {
    Invoke-DV POST "systemforms" -Body @{ type = 2; objecttypecode = $Table; name = "Information"; description = "Main form for a tenant contract."; formxml = $formXml; formactivationstate = 1 } -ExtraHeaders $SolHeader | Out-Null
    Write-Output "  + main form"
}

function New-View([string]$NameEn, [string]$DescEn, [array]$Columns, [string]$OrderBy, [bool]$IsDefault = $false) {
    $existing = Invoke-DV GET "savedqueries?`$select=savedqueryid&`$filter=returnedtypecode eq '$Table' and name eq '$(Get-Esc $NameEn)'" -Silent
    $attrs = ""; $cells = ""
    foreach ($c in $Columns) {
        if (-not $Attr.ContainsKey($c)) { continue }
        $attrs += "<attribute name=`"$c`" />"
        $w = if ($c -eq $PrimaryName) { 250 } else { 150 }
        $cells += "<cell name=`"$c`" width=`"$w`" />"
    }
    if (-not $OrderBy) { $OrderBy = $PrimaryName }
    $fetch = "<fetch version=`"1.0`" mapping=`"logical`" returntotalrecordcount=`"true`" no-lock=`"true`"><entity name=`"$Table`">$attrs<order attribute=`"$OrderBy`" descending=`"false`" /></entity></fetch>"
    $layout = "<grid name=`"resultset`" object=`"$Otc`" jump=`"$PrimaryName`" select=`"1`" icon=`"1`" preview=`"1`"><row name=`"result`" id=`"$PrimaryId`">$cells</row></grid>"
    if ($existing.value -and $existing.value.Count -gt 0) {
        $qid = $existing.value[0].savedqueryid
        Invoke-DV PATCH "savedqueries($qid)" -Body @{ description = $DescEn; fetchxml = $fetch; layoutxml = $layout } -ExtraHeaders $SolHeader | Out-Null
        Write-Output "  ~ updated view: $NameEn"
    } else {
        Invoke-DV POST "savedqueries" -Body @{ returnedtypecode = $Table; name = $NameEn; description = $DescEn; fetchxml = $fetch; layoutxml = $layout; querytype = 0; isdefault = $IsDefault } -ExtraHeaders $SolHeader | Out-Null
        Write-Output "  + view: $NameEn"
    }
}

New-View "Active Tenant Contracts" "Tenant contracts that are currently active." `
    @('alex_name','alex_id_student','alex_os_contract_type','alex_os_status','alex_dt_start','alex_dt_end') 'alex_dt_start' $true
New-View "All Tenant Contracts" "Every tenant contract regardless of status." `
    @('alex_name','alex_id_student','alex_os_contract_type','alex_os_payment_currency','alex_m_monthly_rent','alex_b_signed') 'alex_name'

# =========================================================================
Write-Output "Publishing customizations..."
Invoke-DV POST "PublishAllXml" | Out-Null
Write-Output "Done. alex_tenant_contract created in $SolutionUnique."
