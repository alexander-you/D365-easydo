<#
  60-add-copylink-columns.ps1

  Governance for the envelope "copy signing link" capability.

  Model: a single global default, overridable per template.

    alex_easydosettings.alex_AllowCopyLink (Boolean, default Yes)
        Org-wide default. When Yes, copying the signing link is allowed unless a
        template explicitly blocks it. Managed from the easydo Admin Center
        (Global send settings drawer).

    alex_signaturetemplate.alex_CopyLinkMode (Choice: Inherit / Allow / Block)
        Per-template override. Inherit (default) = follow the global default;
        Allow / Block force the behaviour for documents built from that template.

  Effective permission (evaluated by the consumer, e.g. viewer/PCF - follow-up):
        Inherit -> global alex_allowcopylink
        Allow   -> always allowed
        Block   -> never allowed

  Re-runnable: New-DVGlobalChoice and Add-DVColumn are idempotent. Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- Global choice for the per-template override -------------------------
New-DVGlobalChoice -Name "alex_copylinkmode" -En "Copy Link Mode" -He "מצב העתקת קישור" `
    -DescEn "Per-template override for whether the signing link may be copied." `
    -DescHe "עקיפה ברמת התבנית לגבי האם ניתן להעתיק את קישור החתימה." `
    -Options @(
        @{ Value = 626250000; En = "Inherit"; He = "ברירת מחדל גלובלית"; DescEn = "Follow the global default setting."; DescHe = "לפי ההגדרה הגלובלית." },
        @{ Value = 626250001; En = "Allow";   He = "מותר";               DescEn = "Always allow copying the signing link."; DescHe = "תמיד לאפשר העתקת קישור החתימה." },
        @{ Value = 626250002; En = "Block";   He = "חסום";               DescEn = "Never allow copying the signing link.";  DescHe = "אף פעם לא לאפשר העתקת קישור החתימה." }
    )

# ---- Global default toggle on the settings table -------------------------
$settings = "alex_easydosettings"
Write-Output "== $settings =="
Add-DVColumn $settings (New-DVBool -Schema "alex_AllowCopyLink" -En "Allow Copy Link" -He "אפשר העתקת קישור" `
    -DescEn "Org-wide default: when on, the signing link may be copied unless a template blocks it." `
    -DescHe "ברירת מחדל ארגונית: כאשר מופעל, ניתן להעתיק את קישור החתימה אלא אם תבנית חוסמת זאת." `
    -Default $true)

# ---- Per-template override choice ----------------------------------------
$tmpl = "alex_signaturetemplate"
Write-Output "== $tmpl =="
Add-DVColumn $tmpl (New-DVPicklistGlobal -Schema "alex_CopyLinkMode" -En "Copy Link Mode" -He "מצב העתקת קישור" `
    -DescEn "Overrides the global 'Allow Copy Link' default for documents built from this template." `
    -DescHe "עוקף את ברירת המחדל הגלובלית 'אפשר העתקת קישור' עבור מסמכים שנבנים מתבנית זו." `
    -GlobalOptionSetName "alex_copylinkmode")

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
