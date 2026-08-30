<#
  60-add-language-options.ps1

  Adds Russian and Arabic to the alex_language global choice so the recipient
  signing-interface language matches easydo's per-assignee `language` parameter
  (he / en / ru / ar). The choice is shared by:
    * alex_signaturerecipient.alex_preferredlanguage  (the signing language)
    * alex_signaturerequest.alex_language             (document / UI language)
    * alex_signaturetemplate.alex_language

  Existing values: Hebrew = 626210000, English = 626210001.
  New values:      Russian = 626210002, Arabic = 626210003.

  Idempotent.
#>
. "$PSScriptRoot\dv-common.ps1"
Connect-Dataverse

$optionSet = "alex_language"
$newOptions = @(
    @{ Value = 626210002; En = "Russian"; He = "רוסית";
       DescEn = "Russian language for recipient communication and the signing interface.";
       DescHe = "שפה רוסית לתקשורת עם הנמען ולממשק החתימה." },
    @{ Value = 626210003; En = "Arabic"; He = "ערבית";
       DescEn = "Arabic language and right-to-left presentation for the signing interface.";
       DescHe = "שפה ערבית ותצוגה מימין לשמאל לממשק החתימה." }
)

$existing = Invoke-DV GET "GlobalOptionSetDefinitions(Name='$optionSet')/Microsoft.Dynamics.CRM.OptionSetMetadata?`$select=Name,Options"
$existingValues = @($existing.Options | ForEach-Object { $_.Value })

foreach ($o in $newOptions) {
    if ($existingValues -contains $o.Value) {
        Write-Host "Option $($o.Value) ($($o.En)) already present. Skipping." -ForegroundColor Yellow
        continue
    }
    $body = @{
        OptionSetName = $optionSet
        Value         = $o.Value
        Label         = (New-DVLabel -En $o.En -He $o.He)
        Description   = (New-DVLabel -En $o.DescEn -He $o.DescHe)
    }
    Invoke-DV POST "InsertOptionValue" -Body $body | Out-Null
    Write-Host "Added option $($o.Value) ($($o.En) / $($o.He)) to $optionSet." -ForegroundColor Green
}

# Publish so the new options are available immediately.
Invoke-DV POST "PublishAllXml" | Out-Null
Write-Host "Published all customizations." -ForegroundColor Green
