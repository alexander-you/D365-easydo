<#
  20-extend-entityconfig-table.ps1

  Extends alex_easydoentityconfig with the columns the Form Send feature needs
  beyond the original minimal set. Idempotent (Add-DVColumn skips existing).

  New columns:
    alex_enableonform    (bool, default true)  - show the easydo button on the form
    alex_enableongrid    (bool, default false) - show it on the table's home grid
    alex_enableonsubgrid (bool, default false) - show it on subgrids of the table
    alex_buttonlabelhe   (string)              - optional Hebrew label override
    alex_buttonlabelen   (string)              - optional English label override
    alex_lastcheckedon   (datetime)            - last time the EnableRule queried config
    alex_notes           (memo)                - free admin notes
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

$t = "alex_easydoentityconfig"
Write-Output "== extending $t =="

Add-DVColumn $t (New-DVBool -Schema "alex_EnableOnForm" -En "Enable on Form" -He "הפעלה בטופס" -Default $true `
    -TrueEn "Enabled" -TrueHe "מופעל" -FalseEn "Disabled" -FalseHe "מושבת" `
    -DescEn "When enabled, the easydo send button appears on this table's form." `
    -DescHe "כאשר מופעל, כפתור השליחה של easydo מופיע בטופס של טבלה זו.")

Add-DVColumn $t (New-DVBool -Schema "alex_EnableOnGrid" -En "Enable on Grid" -He "הפעלה ברשימה" -Default $false `
    -TrueEn "Enabled" -TrueHe "מופעל" -FalseEn "Disabled" -FalseHe "מושבת" `
    -DescEn "When enabled, the easydo send button appears on this table's home grid (list view)." `
    -DescHe "כאשר מופעל, כפתור השליחה של easydo מופיע ברשימה הראשית (תצוגת רשימה) של טבלה זו.")

Add-DVColumn $t (New-DVBool -Schema "alex_EnableOnSubgrid" -En "Enable on Subgrid" -He "הפעלה ברשת משנה" -Default $false `
    -TrueEn "Enabled" -TrueHe "מופעל" -FalseEn "Disabled" -FalseHe "מושבת" `
    -DescEn "When enabled, the easydo send button appears on subgrids of this table embedded in other forms." `
    -DescHe "כאשר מופעל, כפתור השליחה של easydo מופיע ברשתות משנה של טבלה זו המוטמעות בטפסים אחרים.")

Add-DVColumn $t (New-DVString -Schema "alex_ButtonLabelHe" -En "Button Label (Hebrew)" -He "תווית כפתור (עברית)" -MaxLength 100 `
    -DescEn "Optional Hebrew label override for the easydo send button on this table. Leave blank to use the default." `
    -DescHe "דריסת תווית עברית אופציונלית לכפתור השליחה של easydo בטבלה זו. השאר ריק לשימוש בברירת המחדל.")

Add-DVColumn $t (New-DVString -Schema "alex_ButtonLabelEn" -En "Button Label (English)" -He "תווית כפתור (אנגלית)" -MaxLength 100 `
    -DescEn "Optional English label override for the easydo send button on this table. Leave blank to use the default." `
    -DescHe "דריסת תווית אנגלית אופציונלית לכפתור השליחה של easydo בטבלה זו. השאר ריק לשימוש בברירת המחדל.")

Add-DVColumn $t (New-DVDateTime -Schema "alex_LastCheckedOn" -En "Last Checked On" -He "נבדק לאחרונה ב" `
    -DescEn "Timestamp of the most recent time the ribbon EnableRule evaluated this configuration." `
    -DescHe "חותמת הזמן של הפעם האחרונה שבה כלל ההפעלה של הריבון בדק תצורה זו.")

Add-DVColumn $t (New-DVMemo -Schema "alex_Notes" -En "Notes" -He "הערות" -MaxLength 2000 `
    -DescEn "Free-form administrator notes about this table's easydo send configuration." `
    -DescHe "הערות חופשיות של מנהל המערכת לגבי תצורת השליחה של easydo עבור טבלה זו.")

Write-Output "Done."
