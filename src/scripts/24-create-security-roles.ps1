<#
  24-create-security-roles.ps1

  Creates (idempotently) the three easydo security roles and assigns their
  table privileges, then adds the roles to the alex_d365_easydo solution.

  These are ADD-ON roles: they grant access only to the eight easydo tables.
  They are designed to be combined with a Dataverse base role (e.g.
  "Basic User" / "Common Data Service User") that grants the platform-level
  privileges required to sign in and use model-driven apps.

  Roles and intent
  ----------------
    easydo Account Administrator
      Full control (Create/Read/Write/Delete/Append/AppendTo/Assign/Share)
      at Organization scope on all eight easydo tables. Manages templates,
      configuration and the admin center.

    easydo Sender
      Read-only on the configuration tables (template / field mapping /
      entity config) at Organization scope, and create/maintain the
      transaction records (request / recipient / document / field value)
      at Business Unit scope, so a team can see and back up each other's
      signature requests. Read access to the integration log (BU) to
      self-diagnose failed sends.

    easydo Viewer
      Read-only at Organization scope on every business table. The technical
      integration log is intentionally hidden from this role.

  Privilege depth mapping (Dataverse PrivilegeDepth)
  --------------------------------------------------
    User             -> Basic   (own records)
    Business Unit    -> Local   (records in the user's BU)
    Parent:Child BU  -> Deep
    Organization     -> Global  (all records)

  Re-running this script is safe: existing roles are reused and their full
  privilege set is replaced (ReplacePrivilegesRole) to match this definition.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$SolutionUniqueName = "alex_d365_easydo"
$RoleSolutionComponentType = 20   # Role

# ---- 1. Root business unit ----------------------------------------------
$rootBu = (Invoke-DV GET "businessunits?`$select=businessunitid&`$filter=_parentbusinessunitid_value eq null").value[0].businessunitid
Write-Host "Root business unit: $rootBu"

# ---- 2. Privilege catalogue (PrivilegeId per table per operation) --------
# Keys: C=Create R=Read W=Write D=Delete Ap=Append ApTo=AppendTo As=Assign Sh=Share
$P = @{
    "alex_signaturetemplate"   = @{ C="40c76154-f9f4-47b1-ba8e-e136f8238eae"; R="06106e9d-1c9d-45a7-8d7b-18be529021e5"; W="2109a44e-514b-4fa2-ad98-4f28eeac7e5f"; D="0130f5de-ac72-45d5-9011-ba5ac9600a15"; As="60993fe2-f75d-400f-b6be-b41ca0a40ec9"; Sh="201f4670-e7f6-474f-8091-7f689f576a16"; Ap="22c7c378-6dc1-4eaa-9d80-22aa262207f1"; ApTo="937d9afb-0b05-4e3d-8dbd-e5e1f91b60ae" }
    "alex_templatefieldmapping"= @{ C="5d1a6dae-f434-49dd-87d1-9238de097e47"; R="4406d54c-033b-450e-8f91-dfe50cc1e047"; W="f6397ab2-530d-47e0-8dde-18b4992170ef"; D="44933fef-a630-46fd-8bba-d6c7806cf4b0"; As="0dca7411-2d57-4cbe-9717-10ae9e414762"; Sh="a2f19443-e374-4329-a507-bec8883943bd"; Ap="0b0183a1-9027-43d3-bf70-76e6965566ea"; ApTo="0ee4337a-a8de-4061-b743-59df23abef1a" }
    "alex_easydoentityconfig"  = @{ C="5c836491-39a4-43fb-a0cf-e71275d073f7"; R="238029e5-4858-4bb1-bc19-51e044dce847"; W="6996332e-51fd-430a-9dd8-e3270448b1b4"; D="10b4e077-efaf-40da-b7c2-1ae4f1da8698"; As="9cff428f-a335-4f7c-b929-7205374ef25f"; Sh="871e20fc-4613-47e6-9321-ee363774bed4"; Ap="0f860e39-9c5d-418b-9207-c3928eb66c28"; ApTo="37a22507-3e45-4ffc-ab2e-5beefd56367b" }
    "alex_signaturerequest"    = @{ C="22a49264-c70f-4eac-a3dc-8f7707f89322"; R="f711e5c8-cbae-4cd7-b0c0-1baf3431e159"; W="91d9cf1e-a1df-4a74-990f-267754a82637"; D="8c8a1442-0a11-4f5f-b4b3-0d643cac7d17"; As="259b639d-264b-400f-9230-1691374c59c8"; Sh="34be3b98-2b14-4d48-b30a-6798e8d2fc43"; Ap="625d1bf6-ee35-4f30-851f-58aa82833e36"; ApTo="cf9bf4ac-f632-4a9d-adde-0e57faef77ef" }
    "alex_signaturerecipient"  = @{ C="c0b9c4d0-6309-470f-a900-8a1624c639d9"; R="7cb5d3ff-53c9-410e-88ff-e78041a1f02f"; W="4fc3f93c-5036-42ca-aa5b-af5afb7b0f71"; D="da32a4a8-e8e9-47f3-9f5d-8bed40fd02fb"; As="3e9231ba-e167-43a1-b6da-fa0402d10a83"; Sh="dd7535e8-0a27-4d35-b22a-3e6206d87ed6"; Ap="7a442502-d401-4bd6-a61d-8b3a8d5e4865"; ApTo="2a3fa8e1-578a-4a02-9332-b070b6b71742" }
    "alex_signaturedocument"   = @{ C="5cebc9b7-bc0e-421e-9cee-3aab69567fa8"; R="9e1e30d7-fd2c-4d5c-8141-8fc891973ddd"; W="3379a963-25cd-4d59-87e8-fdb518d3af80"; D="ec1a1506-867a-45b6-8942-0c2cedea269f"; As="1f9eb678-6df1-4530-ba28-22830f0b9675"; Sh="ad2e2eb7-e93d-4d57-bf12-c772908c99f1"; Ap="3ce61a77-51d6-4504-824e-5b9e5706d81d"; ApTo="aae38c3f-7b09-464c-a1c0-e635f8e4d50f" }
    "alex_signaturefieldvalue" = @{ C="546c4edf-1afa-4660-a8d5-977ec46f24b8"; R="c493322e-6e80-418a-8547-fc9d94f8c092"; W="68a27fa5-2ba1-4025-a59d-85b6ef6e298f"; D="3c4607a9-52fa-413c-ac38-5f343cfa19e0"; As="8d12de5c-541e-4926-a141-12407d6a420a"; Sh="980d6b90-b6ff-43da-bf7e-15edb07ff178"; Ap="3657558e-cea6-466c-9202-069e7ae7b837"; ApTo="c4c46121-c418-457b-9595-f144148326b5" }
    "alex_integrationlog"      = @{ C="cc41e374-ea16-43d5-87ee-0a70f3463b11"; R="5ae09d40-0ef1-4639-aa05-36565d11ad52"; W="a303b040-d4e9-4ea4-802b-b948d51f57a1"; D="b9bba0f1-86c4-4a5f-85ec-dd03716f8dd9"; As="9d90baaf-d81d-4eb8-8780-386192bae0e5"; Ap="77a3ed68-989d-4f19-85e2-2336246e5474"; ApTo="cdfed87a-db36-4c88-8b15-74fc3b80c5b8" }
}

$configTables = @("alex_signaturetemplate","alex_templatefieldmapping","alex_easydoentityconfig")
$txnTables    = @("alex_signaturerequest","alex_signaturerecipient","alex_signaturedocument","alex_signaturefieldvalue")

# Helper: emit a RolePrivilege object { PrivilegeId, Depth } using a string depth
function Priv($id, $depth) { return @{ PrivilegeId = $id; Depth = $depth } }

# ---- 3. Build the privilege set for each role ----------------------------

# --- easydo Account Administrator : full control, Global on every table ---
$adminPrivs = @()
foreach ($t in $P.Keys) {
    foreach ($op in @("C","R","W","D","Ap","ApTo","As","Sh")) {
        if ($P[$t].ContainsKey($op)) { $adminPrivs += Priv $P[$t][$op] "Global" }
    }
}

# --- easydo Sender --------------------------------------------------------
$senderPrivs = @()
# config tables: read (Global) + AppendTo (Global) so requests can reference them
foreach ($t in $configTables) {
    $senderPrivs += Priv $P[$t].R    "Global"
    $senderPrivs += Priv $P[$t].ApTo "Global"
}
# transaction tables: create/read/write/append/appendto at BU (Local)
foreach ($t in $txnTables) {
    $senderPrivs += Priv $P[$t].C    "Local"
    $senderPrivs += Priv $P[$t].R    "Local"
    $senderPrivs += Priv $P[$t].W    "Local"
    $senderPrivs += Priv $P[$t].Ap   "Local"
    $senderPrivs += Priv $P[$t].ApTo "Local"
}
# integration log: read only (BU) to self-diagnose failed sends
$senderPrivs += Priv $P["alex_integrationlog"].R "Local"

# --- easydo Viewer : read-only Global on every business table; log hidden --
$viewerPrivs = @()
foreach ($t in ($configTables + $txnTables)) {
    $viewerPrivs += Priv $P[$t].R "Global"
}

$roleDefs = @(
    @{ Name = "easydo Account Administrator"; Privs = $adminPrivs }
    @{ Name = "easydo Sender";                Privs = $senderPrivs }
    @{ Name = "easydo Viewer";                Privs = $viewerPrivs }
)

# ---- 4. Create / update each role ----------------------------------------
foreach ($def in $roleDefs) {
    $name = $def.Name

    $existing = (Invoke-DV GET "roles?`$select=roleid&`$filter=name eq '$name' and _businessunitid_value eq $rootBu").value
    if ($existing -and $existing.Count -gt 0) {
        $roleId = $existing[0].roleid
        Write-Host "Role '$name' already exists ($roleId) - reusing."
    }
    else {
        $body = @{
            name                      = $name
            "businessunitid@odata.bind" = "/businessunits($rootBu)"
        }
        $resp = Invoke-DV POST "roles" -Body $body -ReturnHeaders
        $loc = $resp.Headers["OData-EntityId"]
        if ($loc -is [array]) { $loc = $loc[0] }
        $roleId = ([regex]::Match($loc, "roles\(([0-9a-fA-F-]+)\)")).Groups[1].Value
        Write-Host "Created role '$name' ($roleId)."
    }

    # Replace the full privilege set so the role matches this definition exactly.
    Invoke-DV POST "roles($roleId)/Microsoft.Dynamics.CRM.ReplacePrivilegesRole" `
        -Body @{ Privileges = $def.Privs } | Out-Null
    Write-Host "  Assigned $($def.Privs.Count) privileges to '$name'."

    # Add the role to the solution (idempotent; ignore 'already a component').
    try {
        Invoke-DV POST "AddSolutionComponent" -Body @{
            ComponentId           = $roleId
            ComponentType         = $RoleSolutionComponentType
            SolutionUniqueName    = $SolutionUniqueName
            AddRequiredComponents = $false
        } -Silent | Out-Null
        Write-Host "  Added '$name' to solution $SolutionUniqueName."
    }
    catch {
        Write-Host "  '$name' solution add skipped (likely already present)." -ForegroundColor DarkYellow
    }
}

Write-Host "Done. Three easydo security roles are created, scoped and added to the solution." -ForegroundColor Green
