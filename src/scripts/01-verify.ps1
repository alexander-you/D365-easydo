# Verifies Dataverse access, provisioned languages, and the target publisher.
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$who = Invoke-DV GET "WhoAmI"
Write-Output "WhoAmI.UserId = $($who.UserId)"
Write-Output "WhoAmI.OrganizationId = $($who.OrganizationId)"

$langs = Invoke-DV GET "RetrieveProvisionedLanguages"
Write-Output "ProvisionedLanguages = $($langs.RetrieveProvisionedLanguages -join ', ')"
$hasHe = $langs.RetrieveProvisionedLanguages -contains 1037
Write-Output "Hebrew(1037) provisioned = $hasHe"

$pub = Invoke-DV GET "publishers?`$select=friendlyname,uniquename,customizationprefix,publisherid&`$filter=customizationprefix eq 'alex'"
Write-Output "PublisherMatches = $(($pub.value | Measure-Object).Count)"
foreach ($p in $pub.value) {
    Write-Output ("  - friendly='{0}' unique='{1}' prefix='{2}' id={3}" -f $p.friendlyname, $p.uniquename, $p.customizationprefix, $p.publisherid)
}
