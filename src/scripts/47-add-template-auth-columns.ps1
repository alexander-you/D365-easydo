<#
  47-add-template-auth-columns.ps1

  Identification & authentication feature (step 2 - schema).

  Both single templates and envelope templates in easydo expose recipient
  authentication settings (probed 2026-07-31 live):
    - pin          : a PIN the recipient must enter before signing.
    - auth_method  : how the recipient authenticates (e.g. PIN / OTP-SMS).
  Both levels are PUT-updatable (single template PUT /entity/me/templates/{id}
  and envelope PUT /entity/me/envelopes/{id} both returned 200).

  This script adds the D365-side ADMIN DEFAULTS for those settings on the shared
  alex_signaturetemplate row (which stores BOTH single documents and envelopes,
  distinguished by alex_isenvelope). They are surfaced in the Template Field
  Mapping PCF as a new "Identification & authentication" section, NOT as new form
  fields. The send flow will later read them as fall-backs and inject them into
  the easydo send (with an optional per-send override).

  Columns added to alex_signaturetemplate (all additive, all default OFF/None so
  existing templates are unaffected):

    alex_PinMode              (choice)  None / Fixed PIN / Variable PIN (from field)
    alex_PinValue             (string)  the fixed PIN value (used when mode = Fixed)
    alex_PinSourceField       (string)  easydo field / mapping name to read the PIN
                                        from the source object (used when mode = Variable)
    alex_PinAllowSendOverride (bool)    may the sender change/enter the PIN at send time
    alex_AuthMethod           (choice)  None / PIN / OTP (SMS) recipient auth method

  SECURITY NOTE: a fixed PIN is stored as plain text. Prefer the Variable mode
  (PIN taken from a field on the source record) so no static secret is stored.

  Re-runnable: New-DVGlobalChoice / Add-DVColumn skip existing components.
  Publishes at the end.
#>
. "$PSScriptRoot\dv-common.ps1"
. "$PSScriptRoot\dv-meta.ps1"
Connect-Dataverse

# ---- Global choices ---------------------------------------------------
New-DVGlobalChoice -Name "alex_pinmode" -En "PIN Mode" -He "מצב PIN" `
    -DescEn "How the recipient PIN is determined for a document or envelope." `
    -DescHe "כיצד נקבע קוד ה-PIN של הנמען עבור מסמך או מעטפה." `
    -Options @(
        @{ Value = 1; En = "No PIN";                 He = "ללא PIN";
           DescEn = "The recipient is not asked for a PIN.";
           DescHe = "הנמען אינו מתבקש להזין PIN." },
        @{ Value = 2; En = "Fixed PIN";              He = "PIN קבוע";
           DescEn = "A single fixed PIN value is used for every send.";
           DescHe = "נעשה שימוש בערך PIN קבוע אחד עבור כל שליחה." },
        @{ Value = 3; En = "Variable PIN (from field)"; He = "PIN משתנה (משדה)";
           DescEn = "The PIN is read at send time from a field on the source record (for example an ID or phone number).";
           DescHe = "ה-PIN נקרא בזמן השליחה משדה ברשומת המקור (לדוגמה מספר זהות או טלפון)." }
    )

New-DVGlobalChoice -Name "alex_authmethod" -En "Authentication Method" -He "שיטת אימות" `
    -DescEn "How the recipient proves their identity before signing." `
    -DescHe "כיצד הנמען מאמת את זהותו לפני החתימה." `
    -Options @(
        @{ Value = 1; En = "None";       He = "ללא";
           DescEn = "No additional authentication before signing.";
           DescHe = "אין אימות נוסף לפני החתימה." },
        @{ Value = 2; En = "PIN";        He = "PIN";
           DescEn = "The recipient must enter a PIN before signing.";
           DescHe = "הנמען חייב להזין PIN לפני החתימה." },
        @{ Value = 3; En = "OTP (SMS)";  He = "OTP (SMS)";
           DescEn = "The recipient authenticates with a one-time code sent by SMS.";
           DescHe = "הנמען מאמת באמצעות קוד חד-פעמי הנשלח ב-SMS." }
    )

# ---- Template-level authentication defaults ---------------------------
$tpl = "alex_signaturetemplate"
Write-Output "== $tpl =="

Add-DVColumn $tpl (New-DVPicklistGlobal -Schema "alex_AuthMethod" -En "Authentication Method" -He "שיטת אימות" `
    -DescEn "Default recipient authentication method for documents sent from this template or envelope (None / PIN / OTP-SMS). Sent to easydo as auth_method; can be overridden per send when allowed." `
    -DescHe "שיטת אימות הנמען כברירת מחדל עבור מסמכים שנשלחים מתבנית או מעטפה זו (ללא / PIN / OTP-SMS). נשלח ל-easydo כ-auth_method; ניתן לדריסה בכל שליחה כאשר מותר." `
    -GlobalOptionSetName "alex_authmethod")

Add-DVColumn $tpl (New-DVPicklistGlobal -Schema "alex_PinMode" -En "PIN Mode" -He "מצב PIN" `
    -DescEn "Determines how the recipient PIN is set: no PIN, a fixed value, or a value read from a field on the source record at send time." `
    -DescHe "קובע כיצד נקבע ה-PIN של הנמען: ללא PIN, ערך קבוע, או ערך הנקרא משדה ברשומת המקור בזמן השליחה." `
    -GlobalOptionSetName "alex_pinmode")

Add-DVColumn $tpl (New-DVString -Schema "alex_PinValue" -En "Fixed PIN Value" -He "ערך PIN קבוע" -MaxLength 50 `
    -DescEn "The fixed PIN value sent to easydo when PIN Mode is 'Fixed PIN'. Stored as plain text - prefer Variable PIN to avoid storing a static secret." `
    -DescHe "ערך ה-PIN הקבוע שנשלח ל-easydo כאשר מצב ה-PIN הוא 'PIN קבוע'. מאוחסן כטקסט רגיל - עדיף PIN משתנה כדי להימנע מאחסון סוד סטטי.")

Add-DVColumn $tpl (New-DVString -Schema "alex_PinSourceField" -En "PIN Source Field" -He "שדה מקור ל-PIN" -MaxLength 200 `
    -DescEn "The easydo field / mapping name whose value is used as the PIN when PIN Mode is 'Variable PIN'. Resolved from the source record at send time (for example a government id or phone number)." `
    -DescHe "שם השדה / המיפוי ב-easydo שערכו משמש כ-PIN כאשר מצב ה-PIN הוא 'PIN משתנה'. נפתר מרשומת המקור בזמן השליחה (לדוגמה מספר זהות או טלפון).")

Add-DVColumn $tpl (New-DVBool -Schema "alex_PinAllowSendOverride" -En "Allow Changing PIN At Send" -He "אפשר שינוי PIN בעת שליחה" `
    -DescEn "When on, the sender can enter or change the PIN in the send wizard. When off, the template PIN setting is always used." `
    -DescHe "כאשר פעיל, השולח יכול להזין או לשנות את ה-PIN באשף השליחה. כאשר כבוי, נעשה תמיד שימוש בהגדרת ה-PIN של התבנית." `
    -Default $false)

Write-Output "Publishing..."
Invoke-DV -Method Post -Path "PublishAllXml" -Body @{} | Out-Null
Write-Output "Done."
