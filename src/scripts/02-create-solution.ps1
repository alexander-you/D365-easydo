# Creates (idempotently) the unmanaged solution "D365 easydo" tied to the
# AlexanderYurpolsky publisher. Web API only.
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$publisherId   = "24874714-daa9-49d0-a3bf-95672249c221"   # AlexanderYurpolsky, prefix alex
$solutionUnique = "alex_d365_easydo"
$solutionName   = "D365 easydo"

# Check if the solution already exists
$existing = Invoke-DV GET "solutions?`$select=solutionid,uniquename,friendlyname,ismanaged,version&`$filter=uniquename eq '$solutionUnique'"
if ($existing.value -and $existing.value.Count -gt 0) {
    $s = $existing.value[0]
    Write-Output "Solution already exists: $($s.uniquename) v$($s.version) managed=$($s.ismanaged) id=$($s.solutionid)"
    return
}

$body = @{
    uniquename            = $solutionUnique
    friendlyname          = $solutionName
    version               = "1.0.0.0"
    description           = "Digital signature integration between Dynamics 365 and easydo (Power Platform MVP). Created via Dataverse Web API."
    "publisherid@odata.bind" = "/publishers($publisherId)"
}
$res = Invoke-DV POST "solutions" -Body $body -ReturnHeaders
Write-Output "Solution created. Status=$($res.Status)"

$verify = Invoke-DV GET "solutions?`$select=solutionid,uniquename,friendlyname,ismanaged,version&`$filter=uniquename eq '$solutionUnique'"
$v = $verify.value[0]
Write-Output ("Verified: {0} v{1} managed={2} id={3}" -f $v.uniquename, $v.version, $v.ismanaged, $v.solutionid)
