import { IInputs, IOutputs } from "./generated/ManifestTypes";

/* =====================================================================
   easydo  -  Template Field Mapping  (PCF, model-driven form control)

   The control sits on a field of the alex_signaturetemplate form. It reads
   the open template record id from the page context and drives everything
   through context.webAPI + the metadata Web API:
     - lists Dynamics tables / columns dynamically (EntityDefinitions / Attributes)
     - loads the template's mapping rows (alex_templatefieldmapping)
     - saves table / column / lock / direction back to those rows
   alex_externalfieldname (the easydo binding, owned by sync) is never written.

   When there is no template context (e.g. PCF test harness) it falls back to
   an elegant demo dataset so it always looks complete.
   ===================================================================== */

type Lang = "en" | "he";

interface TableMeta { logical: string; display: string; }
interface ColMeta { logical: string; display: string; type: string; }

interface MappingRow {
  id: string;            // alex_templatefieldmappingid (empty in demo)
  external: string;      // alex_externalfieldname  (binding header, read only)
  externalId: string;    // alex_externalfieldid
  type: string;          // alex_externalfieldtype
  lookup: string;        // alex_lookupfield (lookup on primary table; empty = direct)
  table: string;         // alex_dynamicstable  (target table the column lives on)
  column: string;        // alex_dynamicsfield
  readOnly: boolean;     // alex_isreadonly
  visibleToUser: boolean;    // alex_isvisibletouser (show in send wizard data step)
  editableBeforeSend: boolean; // alex_iseditablebeforesend (user may edit it there)
  direction: number | null; // alex_direction (choice)
  dirty: boolean;
}

interface LookupMeta { logical: string; display: string; targets: string[]; }

const ENTITY = "alex_templatefieldmapping";
const TEMPLATE_ENTITY = "alex_signaturetemplate";
const DIR = { PREFILL: 626210000, READBACK: 626210001, BIDIR: 626210002 };
// Copy-link governance choice (alex_copylinkmode). Inherit follows the global
// admin default; Allow/Block override it for this template's documents.
const COPYLINK = { INHERIT: 626250000, ALLOW: 626250001, BLOCK: 626250002 };

/* ---- i18n --------------------------------------------------------- */
const I18N: Record<Lang, Record<string, string>> = {
  en: {
    dir: "ltr", langBtn: "עברית",
    brand: "Dynamics 365  ·  easydo Integration",
    title: "Template Field Mapping",
    subtitle: "Map each easydo form field to a Dynamics table and column. The easydo binding stays read only and remains owned by sync.",
    metadataLoaded: "Metadata loaded", metadataDemo: "Demo data",
    mapped: "mapped", directOnly: "Direct fields",
    save: "Save", saving: "Saving…", validate: "Validate", refresh: "Refresh", showLogical: "Show logical names", hideLogical: "Hide logical names",
    gridTitle: "Field mappings", gridMeta: "Rows from",
    search: "Search field",
    showSignatures: "Show signature fields",
    showUnmapped: "Show unmapped only",
    docLabel: "Document",
    thEasydo: "easydo field", thTable: "Dynamics table", thColumn: "Dynamics column", thType: "Type", thReadOnly: "Locked", thDirection: "Direction", thVisible: "In wizard", thEditable: "Editable on send", thStatus: "Status",
    tipEasydo: "The field name as defined on the document in easydo. Read-only and kept in sync automatically.",
    tipTable: "The Dynamics table the value that fills this field is taken from.",
    tipColumn: "The column on the selected table whose value fills this field in the document.",
    tipType: "The data type of the field (text, date, signature, and so on).",
    tipReadOnly: "When on, the value is locked in the document and the signer cannot edit it.",
    tipDirection: "Whether the value is prefilled into the document, read back after signing, or both.",
    tipVisible: "Whether this field is shown to the sender in the send wizard.",
    tipEditable: "When on, the sender can change the value in the wizard before sending; otherwise it stays fixed.",
    tipStatus: "Shows whether the field is mapped to a Dynamics column or still unmapped.",
    choose: "Choose…",
    locked: "Locked", editable: "Editable",
    shown: "Shown", hidden: "Hidden", editOn: "Editable", editOff: "Fixed",
    editLockedByTemplate: "Editing is off for this template",
    dirPrefill: "Prefill", dirReadback: "Read back", dirBidir: "Bidirectional",
    stMapped: "Mapped", stUnmapped: "Unmapped",
    recordContext: "Record context", sourceTable: "Source table", mappingTable: "Mapping table", solution: "Solution", prefix: "Prefix", template: "Template",
    summary: "Summary", total: "Fields", mappedN: "Mapped", lockedN: "Locked", bindings: "Bindings",
    saveBehavior: "Save behavior",
    saveNote: "Only the Dynamics table, column, lock and direction are written. The easydo binding (alex_externalfieldname) is never overwritten.",
    saved: "Mapping saved", nothingToSave: "No changes to save", validOk: "All mappings are valid", validFail: "Some fields are missing a table or column", refreshed: "Metadata refreshed", saveErr: "Save failed",
    loadingMeta: "Loading metadata…", loadingRows: "Loading field mappings…",
    demoTitle: "Demo preview", demoDesc: "No template record in context — showing sample data. Open this control on a template form to load live fields.",
    noRows: "This template has no synced fields yet", noRowsDesc: "Run the easydo template sync, then reopen this template.",
    primaryTableLabel: "Primary table", primaryHint: "The record this document is built on",
    tplSettings: "Template settings",
    sendFromObject: "Allow send from record", sendFromObjectHint: "Show this template in the send wizard launched from a record",
    prefillEdit: "Allow editing data on send", prefillEditHint: "Let the sender edit prefilled fields in the wizard before sending",
    onLbl: "On", offLbl: "Off",
    contactPathLabel: "Path to contact", contactPathNone: "No contact link",
    contactPathHint: "Which lookup on the primary record points to the signer contact",
    recipientLocked: "Lock recipient on send", recipientLockedHint: "The recipient resolved from the record is read-only — the sender cannot change it",
    copyLinkLabel: "Signing link", copyLinkHint: "Whether the signing link for documents from this template is shown in the results pane (open and copy)",
    copyLinkInherit: "Follow global setting", copyLinkAllow: "Always show", copyLinkBlock: "Always hide",
    expirySettings: "Document expiry",
    hasExpiry: "Document has expiry", hasExpiryHint: "The sent document is valid for a limited time and expires automatically",
    expiryDays: "Default validity (days)", expiryDaysHint: "How many days the document stays valid after it is sent",
    expiryOverride: "Allow changing at send", expiryOverrideHint: "Let the sender change the validity in the send wizard",
    authSection: "Identification & authentication",
    authMethodLabel: "Authentication method", authMethodHint: "How the recipient authenticates before signing",
    authNone: "None", authPin: "PIN", authOtp: "OTP (SMS)",
    pinModeLabel: "PIN", pinModeHint: "How the recipient PIN is determined",
    pinNone: "No PIN", pinFixed: "Fixed PIN", pinVariable: "Variable PIN (from field)",
    pinValueLabel: "Fixed PIN value", pinValueHint: "The PIN the recipient must enter", pinValuePlaceholder: "Enter a PIN…",
    pinSourceLabel: "PIN source field (primary table)", pinSourceHint: "A column on the primary record whose value is used as the PIN", pinSourceNone: "Choose a column…",
    pinOverride: "Allow changing PIN at send", pinOverrideHint: "Let the sender enter or change the PIN in the send wizard",
    otpPhoneLabel: "OTP phone source field (primary table)", otpPhoneHint: "A column on the primary record whose value is the phone number for the OTP SMS", otpPhoneNone: "Choose a column…",
    otpOverride: "Allow changing OTP phone at send", otpOverrideHint: "Let the sender enter or change the OTP phone number in the send wizard",
    choosePrimary: "Choose a base table…", contactDisplay: "Contact",
    viaSep: "via",
    configHint: "Pick the base table this document is built on. Each field can then map to a column on that table or on a single related record (one lookup hop).",
    thSource: "Source", formSaveHint: "Changes are saved with the record",
    loadFailed: "Could not load data from Dynamics"
  },
  he: {
    dir: "rtl", langBtn: "English",
    brand: "Dynamics 365  ·  אינטגרציית easydo",
    title: "מיפוי שדות תבנית",
    subtitle: "מפו כל שדה easydo לטבלה ועמודה ב‑Dynamics. קישור ה‑easydo נשאר לקריאה בלבד ובבעלות מנגנון הסנכרון.",
    metadataLoaded: "מטא‑דאטה נטען", metadataDemo: "נתוני דמו",
    mapped: "ממופים", directOnly: "שדות ישירים",
    save: "שמירה", saving: "שומר…", validate: "בדיקה", refresh: "רענון", showLogical: "הצג שמות לוגיים", hideLogical: "הסתר שמות לוגיים",
    gridTitle: "מיפויי שדות", gridMeta: "שורות מתוך",
    search: "חיפוש שדה",
    showSignatures: "הצג שדות חתימה",
    showUnmapped: "הצג לא ממופים בלבד",
    docLabel: "מסמך",
    thEasydo: "שדה easydo", thTable: "טבלת Dynamics", thColumn: "עמודת Dynamics", thType: "סוג", thReadOnly: "נעול", thDirection: "כיוון", thVisible: "באשף", thEditable: "עריכה בשליחה", thStatus: "סטטוס",
    tipEasydo: "שם השדה כפי שהוגדר במסמך ב‑easydo. לקריאה בלבד ומסונכרן אוטומטית.",
    tipTable: "הטבלה ב‑Dynamics שממנה נשלף הערך שימלא את השדה.",
    tipColumn: "העמודה בטבלה שנבחרה, שהערך שלה ממלא את השדה במסמך.",
    tipType: "סוג הנתון של השדה (טקסט, תאריך, חתימה וכדומה).",
    tipReadOnly: "כשמופעל, הערך ננעל במסמך והחותם לא יוכל לערוך אותו.",
    tipDirection: "האם הערך ממולא מראש למסמך, נקרא בחזרה לאחר החתימה, או שניהם.",
    tipVisible: "האם השדה מוצג לשולח באשף השליחה.",
    tipEditable: "כשמופעל, השולח יכול לשנות את הערך באשף לפני השליחה; אחרת הוא נשאר קבוע.",
    tipStatus: "מציין אם השדה ממופה לעמודה ב‑Dynamics או עדיין לא ממופה.",
    choose: "בחר…",
    locked: "נעול", editable: "ניתן לעריכה",
    shown: "מוצג", hidden: "מוסתר", editOn: "ניתן לעריכה", editOff: "קבוע",
    editLockedByTemplate: "עריכה כבויה ברמת התבנית",
    dirPrefill: "מילוי מקדים", dirReadback: "קריאה חזרה", dirBidir: "דו‑כיווני",
    stMapped: "ממופה", stUnmapped: "לא ממופה",
    recordContext: "הקשר רשומה", sourceTable: "טבלת מקור", mappingTable: "טבלת מיפוי", solution: "פתרון", prefix: "תחילית", template: "תבנית",
    summary: "סיכום", total: "שדות", mappedN: "ממופים", lockedN: "נעולים", bindings: "קישורים",
    saveBehavior: "התנהגות שמירה",
    saveNote: "נשמרים רק הטבלה, העמודה, הנעילה והכיוון. קישור ה‑easydo ‏(alex_externalfieldname) לעולם אינו נדרס.",
    saved: "המיפוי נשמר", nothingToSave: "אין שינויים לשמירה", validOk: "כל המיפויים תקינים", validFail: "בחלק מהשדות חסרה טבלה או עמודה", refreshed: "המטא‑דאטה רוענן", saveErr: "השמירה נכשלה",
    loadingMeta: "טוען מטא‑דאטה…", loadingRows: "טוען מיפויי שדות…",
    demoTitle: "תצוגת דמו", demoDesc: "אין רשומת תבנית בהקשר — מוצגים נתוני דוגמה. פתחו את הפקד על טופס תבנית כדי לטעון שדות חיים.",
    noRows: "לתבנית זו אין עדיין שדות מסונכרנים", noRowsDesc: "הריצו את סנכרון תבניות easydo ופתחו מחדש את התבנית.",
    primaryTableLabel: "טבלה ראשית", primaryHint: "הרשומה שעליה בנוי המסמך",
    tplSettings: "הגדרות תבנית",
    sendFromObject: "אפשר שליחה מתוך הרשומה", sendFromObjectHint: "הצגת התבנית באשף השליחה שנפתח מרשומה",
    prefillEdit: "אפשר עריכת נתונים בעת שליחה", prefillEditHint: "אפשרו לשולח לערוך שדות שמולאו מראש באשף לפני השליחה",
    onLbl: "פעיל", offLbl: "כבוי",
    contactPathLabel: "נתיב לאיש קשר", contactPathNone: "אין קישור לאיש קשר",
    contactPathHint: "איזה שדה lookup ברשומה הראשית מצביע על איש הקשר החותם",
    recipientLocked: "נעילת הנמען בשליחה", recipientLockedHint: "הנמען שנפתר מהרשומה לקריאה בלבד — השולח לא יכול לשנותו",
    copyLinkLabel: "קישור חתימה", copyLinkHint: "האם קישור החתימה של מסמכי תבנית זו מוצג בחלונית התוצאות (פתיחה והעתקה)",
    copyLinkInherit: "לפי הגדרת ברירת המחדל", copyLinkAllow: "הצג תמיד", copyLinkBlock: "הסתר תמיד",
    expirySettings: "תוקף המסמך",
    hasExpiry: "יש תוקף למסמך", hasExpiryHint: "המסמך שנשלח תקף לזמן מוגבל ופג‑תוקף אוטומטית",
    expiryDays: "תוקף ברירת מחדל (ימים)", expiryDaysHint: "כמה ימים המסמך נשאר בתוקף לאחר השליחה",
    expiryOverride: "אפשר שינוי בעת שליחה", expiryOverrideHint: "אפשרו לשולח לשנות את התוקף באשף השליחה",
    authSection: "הזדהות ואימות",
    authMethodLabel: "שיטת אימות", authMethodHint: "כיצד הנמען מאמת את זהותו לפני החתימה",
    authNone: "ללא", authPin: "PIN", authOtp: "OTP (SMS)",
    pinModeLabel: "PIN", pinModeHint: "כיצד נקבע ה‑PIN של הנמען",
    pinNone: "ללא PIN", pinFixed: "PIN קבוע", pinVariable: "PIN משתנה (משדה)",
    pinValueLabel: "ערך PIN קבוע", pinValueHint: "ה‑PIN שהנמען חייב להזין", pinValuePlaceholder: "הזינו PIN…",
    pinSourceLabel: "שדה מקור ל‑PIN (טבלה ראשית)", pinSourceHint: "עמודה ברשומה הראשית שערכה משמש כ‑PIN", pinSourceNone: "בחרו עמודה…",
    pinOverride: "אפשר שינוי PIN בעת שליחה", pinOverrideHint: "אפשרו לשולח להזין או לשנות את ה‑PIN באשף השליחה",
    otpPhoneLabel: "שדה מקור לטלפון OTP (טבלה ראשית)", otpPhoneHint: "עמודה ברשומה הראשית שערכה הוא מספר הטלפון עבור ה‑SMS של ה‑OTP", otpPhoneNone: "בחרו עמודה…",
    otpOverride: "אפשר שינוי טלפון OTP בעת שליחה", otpOverrideHint: "אפשרו לשולח להזין או לשנות את מספר הטלפון ל‑OTP באשף השליחה",
    choosePrimary: "בחרו טבלת בסיס…", contactDisplay: "איש קשר",
    viaSep: "דרך",
    configHint: "בחרו את טבלת הבסיס שעליה בנוי המסמך. כל שדה יכול להימפות לעמודה בטבלה זו או ברשומה קשורה אחת (קפיצת lookup אחת).",
    thSource: "מקור", formSaveHint: "השינויים נשמרים יחד עם הרשומה",
    loadFailed: "טעינת הנתונים מדינמיקס נכשלה"
  }
};

/* ---- demo fallback ------------------------------------------------ */
const DEMO_TABLES: Record<Lang, TableMeta[]> = {
  en: [{ logical: "contact", display: "Contact" }, { logical: "account", display: "Account" }, { logical: "incident", display: "Case" }, { logical: "product", display: "Product" }],
  he: [{ logical: "contact", display: "איש קשר" }, { logical: "account", display: "לקוח" }, { logical: "incident", display: "פנייה" }, { logical: "product", display: "מוצר" }]
};
const DEMO_COLS: Record<Lang, Record<string, ColMeta[]>> = {
  en: {
    contact: [
      { logical: "fullname", display: "Full Name", type: "Text" },
      { logical: "alex_governmentid", display: "Government ID", type: "Text" },
      { logical: "emailaddress1", display: "Email", type: "Email" },
      { logical: "mobilephone", display: "Mobile Phone", type: "Phone" },
      { logical: "address1_composite", display: "Address", type: "Text" },
      { logical: "birthdate", display: "Birthdate", type: "Date" }
    ],
    account: [{ logical: "name", display: "Account Name", type: "Text" }, { logical: "telephone1", display: "Main Phone", type: "Phone" }],
    incident: [{ logical: "title", display: "Case Title", type: "Text" }, { logical: "createdon", display: "Created On", type: "DateTime" }],
    product: [{ logical: "name", display: "Product Name", type: "Text" }, { logical: "productnumber", display: "Product ID", type: "Text" }]
  },
  he: {
    contact: [
      { logical: "fullname", display: "שם מלא", type: "טקסט" },
      { logical: "alex_governmentid", display: "מספר מזהה", type: "טקסט" },
      { logical: "emailaddress1", display: "דוא״ל", type: "דוא״ל" },
      { logical: "mobilephone", display: "טלפון נייד", type: "טלפון" },
      { logical: "address1_composite", display: "כתובת", type: "טקסט" },
      { logical: "birthdate", display: "תאריך לידה", type: "תאריך" }
    ],
    account: [{ logical: "name", display: "שם לקוח", type: "טקסט" }, { logical: "telephone1", display: "טלפון ראשי", type: "טלפון" }],
    incident: [{ logical: "title", display: "כותרת פנייה", type: "טקסט" }, { logical: "createdon", display: "נוצר בתאריך", type: "תאריך ושעה" }],
    product: [{ logical: "name", display: "שם מוצר", type: "טקסט" }, { logical: "productnumber", display: "מק\"ט מוצר", type: "טקסט" }]
  }
};
function demoRows(): MappingRow[] {
  return [
    { external: "contact.fullname", externalId: "custom_field_a", type: "input-text", lookup: "primarycontactid", table: "contact", column: "fullname", readOnly: true, direction: DIR.PREFILL },
    { external: "contact.alex_governmentid", externalId: "custom_field_b", type: "input-text", lookup: "primarycontactid", table: "contact", column: "alex_governmentid", readOnly: true, direction: DIR.PREFILL },
    { external: "contact.emailaddress1", externalId: "custom_field_c", type: "input-text", lookup: "primarycontactid", table: "contact", column: "emailaddress1", readOnly: false, direction: DIR.BIDIR },
    { external: "product.name", externalId: "custom_field_d", type: "input-text", lookup: "productid", table: "product", column: "name", readOnly: true, direction: DIR.PREFILL },
    { external: "Sign.Date", externalId: "custom_field_e", type: "input-date", lookup: "", table: "", column: "", readOnly: false, direction: null },
    { external: "AcademicYear", externalId: "custom_field_f", type: "input-text", lookup: "", table: "", column: "", readOnly: false, direction: null }
  ].map(r => ({ visibleToUser: r.direction === DIR.PREFILL || r.direction === DIR.BIDIR, editableBeforeSend: r.direction === DIR.BIDIR, ...r, id: "", dirty: false }));
}

/* ===================================================================== */
export class TemplateFieldMapping implements ComponentFramework.StandardControl<IInputs, IOutputs> {
  private context!: ComponentFramework.Context<IInputs>;
  private root!: HTMLDivElement;
  private hostValue = "";

  private lang: Lang = "en";
  private showLogical = false;
  private demo = false;
  private templateId = "";
  private templateName = "";
  private allowSendFromObject = false; // alex_allowsendfromobject (template-level)
  private allowPrefillEdit = false;    // alex_allowprefilledit (template-level)
  private recipientLocked = false;     // alex_recipientlocked (template-level)
  private hasExpiry = false;           // alex_hasexpiry (template-level)
  private expiryDays: number | null = null; // alex_expirydays (template-level)
  private allowExpiryOverride = false; // alex_allowexpiryoverride (template-level)
  private authMethod: number | null = null;   // alex_authmethod (template-level)
  private pinMode: number | null = null;       // alex_pinmode (template-level)
  private pinValue = "";                        // alex_pinvalue (template-level)
  private pinSourceField = "";                  // alex_pinsourcefield (template-level)
  private pinAllowSendOverride = false;         // alex_pinallowsendoverride (template-level)
  private otpPhoneSource = "";                  // alex_otpphonesource (template-level)
  private otpAllowSendOverride = false;         // alex_otpallowsendoverride (template-level)
  private copyLinkMode: number | null = null;   // alex_copylinkmode (template-level, Inherit/Allow/Block)

  private tables: TableMeta[] = [];
  private colCache: Record<string, ColMeta[]> = {};
  private rows: MappingRow[] = [];
  private filter = "";
  private showSignatures = false;   // signature fields are hidden by default
  private showUnmappedOnly = false; // when on, only rows without table+column

  private primaryTable = "";
  private contactPath = "";
  private lookups: LookupMeta[] = [];

  /* ---- lifecycle -------------------------------------------------- */
  public init(
    context: ComponentFramework.Context<IInputs>,
    _notify: () => void,
    _state: ComponentFramework.Dictionary,
    container: HTMLDivElement
  ): void {
    this.context = context;
    this.root = document.createElement("div");
    this.root.className = "edo-root hide-logic";
    container.appendChild(this.root);

    this.lang = this.resolveLang(context);
    this.templateId = this.getTemplateId();
    this.templateName = this.getTemplateName();

    this.renderLoading(I18N[this.lang].loadingMeta);
    void this.bootstrap();
  }

  public updateView(context: ComponentFramework.Context<IInputs>): void {
    this.context = context;
    this.hostValue = context.parameters.hostField?.raw ?? "";

    // Reload when the host record changes (navigating between template records
    // without the control being destroyed/re-created).
    const newId = this.getTemplateId();
    if (newId && newId !== this.templateId) {
      this.templateId = newId;
      this.templateName = this.getTemplateName();
      this.colCache = {};
      this.rows = [];
      this.primaryTable = "";
      this.contactPath = "";
      this.allowSendFromObject = false;
      this.allowPrefillEdit = false;
      this.recipientLocked = false;
      this.copyLinkMode = null;
      this.lookups = [];
      this.renderLoading(I18N[this.lang].loadingMeta);
      void this.bootstrap();
      return;
    }

    const newLang = this.resolveLang(context);
    if (newLang !== this.lang) { this.lang = newLang; if (this.demo) this.enterDemo(); else this.render(); }
  }

  public getOutputs(): IOutputs {
    return { hostField: this.hostValue };
  }

  public destroy(): void { /* no listeners to detach */ }

  /* ---- context helpers ------------------------------------------- */
  private resolveLang(context: ComponentFramework.Context<IInputs>): Lang {
    const raw = (context.parameters.language?.raw ?? "auto") as string;
    if (raw === "en" || raw === "he") return raw;
    const id = context.userSettings?.languageId;
    return id === 1037 ? "he" : "en";
  }

  private getTemplateId(): string {
    const c = this.context as unknown as {
      mode?: { contextInfo?: { entityId?: string; entityTypeName?: string } };
      page?: { entityId?: string; entityTypeName?: string };
    };
    const info = c.mode?.contextInfo;
    const type = (info?.entityTypeName ?? c.page?.entityTypeName ?? "").toLowerCase();
    if (type && type !== TEMPLATE_ENTITY) return "";
    const id = info?.entityId ?? c.page?.entityId ?? "";
    return id.replace(/[{}]/g, "").toLowerCase();
  }

  private getTemplateName(): string {
    const x = window as unknown as { Xrm?: { Page?: { getAttribute?: (n: string) => { getValue?: () => unknown } | null } } };
    try {
      const a = x.Xrm?.Page?.getAttribute?.("alex_name");
      const v = a?.getValue?.();
      if (typeof v === "string" && v) return v;
    } catch { /* ignore */ }
    return "";
  }

  private getClientUrl(): string {
    const x = window as unknown as {
      Xrm?: { Utility?: { getGlobalContext?: () => { getClientUrl?: () => string } } };
    };
    try {
      const u = x.Xrm?.Utility?.getGlobalContext?.().getClientUrl?.();
      if (u) return u;
    } catch { /* ignore */ }
    const c = this.context as unknown as { page?: { getClientUrl?: () => string } };
    try { return c.page?.getClientUrl?.() ?? ""; } catch { return ""; }
  }

  /* ---- data load -------------------------------------------------- */
  private async bootstrap(): Promise<void> {
    // No record context, no webAPI, or no real client URL (e.g. PCF harness) -> demo.
    if (!this.templateId || !this.context.webAPI || !this.getClientUrl()) {
      this.enterDemo();
      return;
    }
    try {
      this.tables = await this.fetchTables();
      await this.fetchTemplateConfig();
      if (this.primaryTable) {
        try { this.lookups = await this.fetchLookups(this.primaryTable); }
        catch (e) { console.warn("[easydo mapping] lookups load failed", e); }
        try { await this.fetchColumns(this.primaryTable); }
        catch (e) { console.warn("[easydo mapping] primary columns load failed", e); }
      }
      this.renderLoading(I18N[this.lang].loadingRows);
      this.rows = await this.fetchRows();
      const used = Array.from(new Set(this.rows.map(r => r.table).filter(Boolean)));
      await Promise.all(used.map(t => this.fetchColumns(t)));
      this.demo = false;
      this.render();
    } catch (e) {
      // In a real form (template + webAPI present) do NOT show fake demo data —
      // that hides the real problem. Surface an error state instead.
      console.error("[easydo mapping] live load failed:", e);
      this.renderError(e instanceof Error ? e.message : String(e));
    }
  }

  private enterDemo(): void {
    this.demo = true;
    this.tables = DEMO_TABLES[this.lang];
    this.colCache = {};
    this.rows = demoRows();
    this.primaryTable = "incident";
    this.contactPath = "";
    this.lookups = [
      { logical: "primarycontactid", display: this.lang === "he" ? "איש קשר ראשי" : "Primary Contact", targets: ["contact"] },
      { logical: "customerid", display: this.lang === "he" ? "לקוח" : "Customer", targets: ["account"] },
      { logical: "productid", display: this.lang === "he" ? "מוצר" : "Product", targets: ["product"] }
    ];
    if (!this.templateName) this.templateName = this.lang === "he" ? "חוזה לדוגמה" : "Sample template";
    this.render();
  }

  private async metaFetch(path: string): Promise<{ value: unknown[] }> {
    const url = `${this.getClientUrl()}/api/data/v9.2/${path}`;
    const res = await fetch(url, {
      method: "GET",
      headers: {
        "Accept": "application/json",
        "OData-MaxVersion": "4.0",
        "OData-Version": "4.0",
        "Prefer": "odata.include-annotations=\"*\""
      },
      credentials: "same-origin"
    });
    if (!res.ok) throw new Error(`metadata ${res.status}`);
    return res.json() as Promise<{ value: unknown[] }>;
  }

  private label(o: unknown): string {
    const d = o as { DisplayName?: { UserLocalizedLabel?: { Label?: string } } };
    return d.DisplayName?.UserLocalizedLabel?.Label ?? "";
  }

  private async fetchTables(): Promise<TableMeta[]> {
    const data = await this.metaFetch(
      "EntityDefinitions?$select=LogicalName,DisplayName&$filter=IsValidForAdvancedFind eq true and IsIntersect eq false"
    );
    const out: TableMeta[] = [];
    for (const e of data.value) {
      const row = e as { LogicalName: string };
      const display = this.label(e) || row.LogicalName;
      out.push({ logical: row.LogicalName, display });
    }
    out.sort((a, b) => a.display.localeCompare(b.display, this.lang));
    return out;
  }

  private async fetchColumns(table: string): Promise<ColMeta[]> {
    if (!table) return [];
    if (this.colCache[table]) return this.colCache[table];
    if (this.demo) { return DEMO_COLS[this.lang][table] ?? []; }
    const data = await this.metaFetch(
      `EntityDefinitions(LogicalName='${encodeURIComponent(table)}')/Attributes` +
      `?$select=LogicalName,DisplayName,AttributeType&$filter=IsValidForRead eq true and AttributeOf eq null`
    );
    const out: ColMeta[] = [];
    for (const a of data.value) {
      const row = a as { LogicalName: string; AttributeType?: string };
      const display = this.label(a);
      if (!display) continue;
      out.push({ logical: row.LogicalName, display, type: row.AttributeType ?? "" });
    }
    out.sort((x, y) => x.display.localeCompare(y.display, this.lang));
    this.colCache[table] = out;
    return out;
  }

  private async fetchRows(): Promise<MappingRow[]> {
    const select = "alex_templatefieldmappingid,alex_externalfieldid,alex_externalfieldname," +
      "alex_externalfieldtype,alex_lookupfield,alex_dynamicstable,alex_dynamicsfield,alex_isreadonly," +
      "alex_isvisibletouser,alex_iseditablebeforesend,alex_direction";
    const q = `?$select=${select}&$filter=_alex_templateid_value eq ${this.templateId}&$orderby=alex_externalfieldname`;
    const res = await this.context.webAPI.retrieveMultipleRecords(ENTITY, q);
    return res.entities.map(e => ({
      id: e["alex_templatefieldmappingid"] as string,
      external: (e["alex_externalfieldname"] as string) ?? (e["alex_externalfieldid"] as string) ?? "",
      externalId: (e["alex_externalfieldid"] as string) ?? "",
      type: (e["alex_externalfieldtype"] as string) ?? "",
      lookup: (e["alex_lookupfield"] as string) ?? "",
      table: (e["alex_dynamicstable"] as string) ?? "",
      column: (e["alex_dynamicsfield"] as string) ?? "",
      readOnly: !!e["alex_isreadonly"],
      visibleToUser: !!e["alex_isvisibletouser"],
      editableBeforeSend: !!e["alex_iseditablebeforesend"],
      direction: (e["alex_direction"] as number) ?? null,
      dirty: false
    }));
  }

  private async fetchTemplateConfig(): Promise<void> {
    try {
      const rec = await this.context.webAPI.retrieveRecord(
        TEMPLATE_ENTITY, this.templateId, "?$select=alex_primarytable,alex_contactpath,alex_name,alex_allowsendfromobject,alex_allowprefilledit,alex_recipientlocked,alex_hasexpiry,alex_expirydays,alex_allowexpiryoverride,alex_authmethod,alex_pinmode,alex_pinvalue,alex_pinsourcefield,alex_pinallowsendoverride,alex_otpphonesource,alex_otpallowsendoverride,alex_copylinkmode"
      );
      this.primaryTable = (rec["alex_primarytable"] as string) ?? "";
      this.contactPath = (rec["alex_contactpath"] as string) ?? "";
      this.recipientLocked = rec["alex_recipientlocked"] === true;
      this.allowSendFromObject = rec["alex_allowsendfromobject"] === true;
      this.allowPrefillEdit = rec["alex_allowprefilledit"] === true;
      this.hasExpiry = rec["alex_hasexpiry"] === true;
      this.expiryDays = (rec["alex_expirydays"] as number) ?? null;
      this.allowExpiryOverride = rec["alex_allowexpiryoverride"] === true;
      this.authMethod = (rec["alex_authmethod"] as number) ?? null;
      this.pinMode = (rec["alex_pinmode"] as number) ?? null;
      this.pinValue = (rec["alex_pinvalue"] as string) ?? "";
      this.pinSourceField = (rec["alex_pinsourcefield"] as string) ?? "";
      this.pinAllowSendOverride = rec["alex_pinallowsendoverride"] === true;
      this.otpPhoneSource = (rec["alex_otpphonesource"] as string) ?? "";
      this.otpAllowSendOverride = rec["alex_otpallowsendoverride"] === true;
      this.copyLinkMode = (rec["alex_copylinkmode"] as number) ?? null;
      if (!this.templateName && rec["alex_name"]) this.templateName = rec["alex_name"] as string;
    } catch (e) {
      console.warn("[easydo mapping] config load failed", e);
    }
  }

  private async fetchLookups(base: string): Promise<LookupMeta[]> {
    if (!base) return [];
    if (this.demo) {
      return base === "incident"
        ? [
            { logical: "primarycontactid", display: this.lang === "he" ? "איש קשר ראשי" : "Primary Contact", targets: ["contact"] },
            { logical: "customerid", display: this.lang === "he" ? "לקוח" : "Customer", targets: ["account"] },
            { logical: "productid", display: this.lang === "he" ? "מוצר" : "Product", targets: ["product"] }
          ]
        : [];
    }
    const data = await this.metaFetch(
      `EntityDefinitions(LogicalName='${encodeURIComponent(base)}')/Attributes/Microsoft.Dynamics.CRM.LookupAttributeMetadata` +
      `?$select=LogicalName,DisplayName,Targets&$filter=IsValidForRead eq true`
    );
    const out: LookupMeta[] = [];
    for (const a of data.value) {
      const row = a as { LogicalName: string; Targets?: string[] };
      const targets = (row.Targets ?? []).filter(x => x && x !== "owner" && x !== "systemuser" && x !== "team" && x !== "businessunit");
      if (targets.length === 0) continue;
      const display = this.label(a) || row.LogicalName;
      out.push({ logical: row.LogicalName, display, targets });
    }
    out.sort((x, y) => x.display.localeCompare(y.display, this.lang));
    return out;
  }

  private async saveTemplateConfig(): Promise<void> {
    if (!this.templateId) return;
    await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, {
      alex_primarytable: this.primaryTable || null,
      alex_contactpath: this.contactPath || null
    });
  }

  // Persist a single template-level boolean flag immediately.
  private async saveTemplateFlag(field: string, value: boolean): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !this.templateId) return;
    try {
      const body: Record<string, unknown> = {};
      body[field] = value;
      await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, body);
      this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo mapping] flag save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  // Persist a single template-level number (or null to clear) immediately.
  private async saveTemplateNumber(field: string, value: number | null): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !this.templateId) return;
    try {
      const body: Record<string, unknown> = {};
      body[field] = value;
      await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, body);
      this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo mapping] number save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  // Persist a single template-level string (or null to clear) immediately.
  private async saveTemplateString(field: string, value: string): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !this.templateId) return;
    try {
      const body: Record<string, unknown> = {};
      body[field] = value || null;
      await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, body);
      this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo mapping] string save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  /* ---- auto-save (immediate persistence) ------------------------ */
  // Each field change is persisted directly to Dataverse right away. This is
  // far more reliable than hooking the form OnSave (which races with Save&Close
  // and is not always reachable from the control iframe).
  private async persistRow(r: MappingRow, silent = false): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !r.id) return;
    try {
      await this.context.webAPI.updateRecord(ENTITY, r.id, {
        alex_lookupfield: r.lookup || null,
        alex_dynamicstable: r.table || null,
        alex_dynamicsfield: r.column || null,
        alex_isreadonly: r.readOnly,
        alex_isvisibletouser: r.visibleToUser,
        alex_iseditablebeforesend: r.editableBeforeSend,
        alex_direction: r.direction
      });
      r.dirty = false;
      if (!silent) this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo mapping] row save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  private async persistConfig(silent = false): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !this.templateId) return;
    try {
      await this.saveTemplateConfig();
      if (!silent) this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo mapping] config save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  /* ---- actions --------------------------------------------------- */
  private async refresh(): Promise<void> {
    this.colCache = {};
    this.renderLoading(I18N[this.lang].loadingMeta);
    await this.bootstrap();
    if (!this.demo) this.toast(I18N[this.lang].refreshed, "ok");
  }

  private dirOptions(): { v: number; label: string }[] {
    const t = I18N[this.lang];
    return [
      { v: DIR.PREFILL, label: t.dirPrefill },
      { v: DIR.READBACK, label: t.dirReadback },
      { v: DIR.BIDIR, label: t.dirBidir }
    ];
  }

  /* ================================================================ */
  /*  RENDER                                                          */
  /* ================================================================ */
  private el(tag: string, cls?: string, text?: string): HTMLElement {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  private renderLoading(msg: string): void {
    this.root.dir = I18N[this.lang].dir;
    this.root.innerHTML = "";
    const state = this.el("div", "edo-state");
    state.appendChild(this.el("div", "edo-spinner"));
    state.appendChild(this.el("div", "t", msg));
    this.root.appendChild(state);
  }

  private renderError(detail: string): void {
    const t = I18N[this.lang];
    this.root.dir = t.dir;
    this.root.innerHTML = "";
    const state = this.el("div", "edo-state");
    state.appendChild(this.el("div", "t", t.loadFailed));
    state.appendChild(this.el("div", "d", detail));
    const retry = this.btn("↻", t.refresh);
    retry.onclick = () => void this.refresh();
    state.appendChild(retry);
    this.root.appendChild(state);
  }

  private render(): void {
    const t = I18N[this.lang];
    this.root.dir = t.dir;
    this.root.classList.toggle("hide-logic", !this.showLogical);
    this.root.innerHTML = "";

    const shell = this.el("div", "edo-shell");
    shell.appendChild(this.buildHero());
    shell.appendChild(this.buildCmdBar());
    shell.appendChild(this.buildConfigStrip());
    shell.appendChild(this.buildGrid());

    this.root.appendChild(shell);
  }

  private buildHero(): HTMLElement {
    const t = I18N[this.lang];
    const hero = this.el("section", "edo-hero");

    const top = this.el("div", "edo-hero-top");
    const logo = this.el("div", "edo-logo");
    for (let i = 0; i < 9; i++) logo.appendChild(this.el("i"));
    top.appendChild(logo);
    top.appendChild(this.el("span", undefined, t.brand));
    if (this.demo) {
      const tag = this.el("span", "edo-hero-demo");
      tag.appendChild(this.el("span", undefined, "● " + t.metadataDemo));
      top.appendChild(tag);
    }
    hero.appendChild(top);

    const main = this.el("div", "edo-hero-main");
    const left = this.el("div");
    left.appendChild(this.el("h1", undefined, t.title));
    left.appendChild(this.el("div", "edo-sub", t.subtitle));
    main.appendChild(left);

    const total = this.rows.length;
    const mapped = this.rows.filter(r => r.table && r.column).length;
    const locked = this.rows.filter(r => r.readOnly).length;
    const bound = this.rows.filter(r => /\./.test(r.external)).length;
    const tiles = this.el("div", "edo-hero-stats");
    tiles.appendChild(this.heroStat(String(total), t.total));
    tiles.appendChild(this.heroStat(String(mapped), t.mappedN));
    tiles.appendChild(this.heroStat(String(locked), t.lockedN));
    tiles.appendChild(this.heroStat(String(bound), t.bindings));
    main.appendChild(tiles);

    hero.appendChild(main);
    return hero;
  }

  private heroStat(n: string, label: string): HTMLElement {
    const s = this.el("div", "edo-hstat");
    s.appendChild(this.el("div", "n", n));
    s.appendChild(this.el("div", "l", label));
    return s;
  }

  private buildCmdBar(): HTMLElement {
    const t = I18N[this.lang];
    const bar = this.el("div", "edo-card edo-cmdbar");

    if (this.templateName) {
      const doc = this.el("div", "edo-doctitle");
      doc.appendChild(this.el("span", "edo-doctitle-ico", "\u2637"));
      const dtext = this.el("div", "edo-doctitle-text");
      dtext.appendChild(this.el("span", "edo-doctitle-kicker", t.docLabel));
      dtext.appendChild(this.el("span", "edo-doctitle-name", this.templateName));
      doc.appendChild(dtext);
      bar.appendChild(doc);
    }

    bar.appendChild(this.el("div", "edo-spacer"));

    const hint = this.el("span", "edo-savehint");
    hint.appendChild(this.el("span", "edo-ico", "✓"));
    hint.appendChild(this.el("span", undefined, t.formSaveHint));
    bar.appendChild(hint);

    const logic = this.btn("⌥", this.showLogical ? t.hideLogical : t.showLogical, "ghost");
    logic.onclick = () => { this.showLogical = !this.showLogical; this.render(); };
    bar.appendChild(logic);

    return bar;
  }

  private btn(ico: string, label: string, extra = ""): HTMLButtonElement {
    const b = this.el("button", `edo-btn ${extra}`.trim()) as HTMLButtonElement;
    b.appendChild(this.el("span", "edo-ico", ico));
    b.appendChild(this.el("span", undefined, label));
    return b;
  }

  private buildConfigStrip(): HTMLElement {
    const t = I18N[this.lang];
    const strip = this.el("div", "edo-card edo-config");
    // Two columns so the short primary-table / contact-path fields share a
    // narrow column with document expiry (filling the white space), while the
    // taller auth + template-settings blocks take the wider column.
    const colA = this.el("div", "edo-config-col");
    const colB = this.el("div", "edo-config-col");

    const g1 = this.el("div", "edo-cfield");
    g1.appendChild(this.el("label", "edo-clabel", t.primaryTableLabel));
    const tableSel = this.buildCombo(
      this.tables.map(tb => ({ value: tb.logical, label: tb.display })),
      this.primaryTable, t.choosePrimary,
      (v) => void this.onPrimaryChanged(v)
    );
    g1.appendChild(tableSel);
    g1.appendChild(this.el("div", "edo-chint", t.primaryHint));
    colA.appendChild(g1);

    // Path to the signer contact: which lookup on the primary record points to
    // the contact. Only lookups that target the contact table are offered.
    const gc = this.el("div", "edo-cfield");
    gc.appendChild(this.el("label", "edo-clabel", t.contactPathLabel));
    const contactOpts = this.lookups
      .filter(l => l.targets.includes("contact"))
      .map(l => ({ value: l.logical, label: l.display }));
    const contactSel = this.buildCombo(
      contactOpts, this.contactPath, t.contactPathNone,
      (v) => { this.contactPath = v; void this.saveTemplateConfig(); }
    );
    gc.appendChild(contactSel);
    gc.appendChild(this.el("div", "edo-chint", t.contactPathHint));
    colA.appendChild(gc);

    // Identification & authentication (recipient PIN + auth method). Admin
    // defaults stored on the template; injected into the easydo send later.
    colB.appendChild(this.buildAuthSection());

    // Template-level flags (moved here from the hidden "General" form tab so the
    // admin can configure everything from the one visible control).
    const g2 = this.el("div", "edo-cfield edo-tplflags");
    g2.appendChild(this.el("label", "edo-clabel", t.tplSettings));
    g2.appendChild(this.buildFlagToggle(
      this.allowSendFromObject, t.sendFromObject, t.sendFromObjectHint,
      (v) => { this.allowSendFromObject = v; void this.saveTemplateFlag("alex_allowsendfromobject", v); }
    ));
    g2.appendChild(this.buildFlagToggle(
      this.allowPrefillEdit, t.prefillEdit, t.prefillEditHint,
      (v) => { this.allowPrefillEdit = v; void this.saveTemplateFlag("alex_allowprefilledit", v); this.render(); }
    ));
    g2.appendChild(this.buildFlagToggle(
      this.recipientLocked, t.recipientLocked, t.recipientLockedHint,
      (v) => { this.recipientLocked = v; void this.saveTemplateFlag("alex_recipientlocked", v); }
    ));

    // Copy-link governance (Inherit / Allow / Block). Inherit follows the global
    // admin default (alex_easydosettings.alex_allowcopylink); Allow/Block are a
    // per-template override read by the results viewer when it renders the
    // "copy signing link" action. Inherit is an explicit selectable option so
    // the admin can always revert to the global default.
    const copyOpts = [
      { value: String(COPYLINK.INHERIT), label: t.copyLinkInherit },
      { value: String(COPYLINK.ALLOW), label: t.copyLinkAllow },
      { value: String(COPYLINK.BLOCK), label: t.copyLinkBlock }
    ];
    const copyRow = this.el("div", "edo-flagrow");
    const copyText = this.el("div", "edo-flagtext");
    copyText.appendChild(this.el("div", "edo-flaglabel", t.copyLinkLabel));
    copyText.appendChild(this.el("div", "edo-chint", t.copyLinkHint));
    copyRow.appendChild(copyText);
    const copySel = String(this.copyLinkMode != null ? this.copyLinkMode : COPYLINK.INHERIT);
    copyRow.appendChild(this.buildCombo(
      copyOpts, copySel, t.copyLinkInherit,
      (v) => {
        this.copyLinkMode = v ? parseInt(v, 10) : COPYLINK.INHERIT;
        void this.saveTemplateNumber("alex_copylinkmode", this.copyLinkMode);
      }
    ));
    g2.appendChild(copyRow);
    colB.appendChild(g2);

    // Document expiry policy. Managed on the Dynamics side (easydo has no API
    // knob for it). The days input and the override toggle are disabled unless
    // "Document has expiry" is on.
    const g3 = this.el("div", "edo-cfield edo-tplflags");
    g3.appendChild(this.el("label", "edo-clabel", t.expirySettings));
    g3.appendChild(this.buildFlagToggle(
      this.hasExpiry, t.hasExpiry, t.hasExpiryHint,
      (v) => { this.hasExpiry = v; void this.saveTemplateFlag("alex_hasexpiry", v); this.render(); }
    ));

    const daysRow = this.el("div", "edo-flagrow");
    const daysText = this.el("div", "edo-flagtext");
    daysText.appendChild(this.el("div", "edo-flaglabel", t.expiryDays));
    daysText.appendChild(this.el("div", "edo-chint", t.expiryDaysHint));
    const daysInput = this.el("input", "edo-numinput") as HTMLInputElement;
    daysInput.type = "number";
    daysInput.min = "1";
    daysInput.max = "3650";
    daysInput.value = this.expiryDays != null ? String(this.expiryDays) : "";
    daysInput.disabled = !this.hasExpiry;
    daysInput.onchange = () => {
      const n = parseInt(daysInput.value, 10);
      this.expiryDays = isNaN(n) ? null : Math.min(3650, Math.max(1, n));
      daysInput.value = this.expiryDays != null ? String(this.expiryDays) : "";
      void this.saveTemplateNumber("alex_expirydays", this.expiryDays);
    };
    daysRow.appendChild(daysText);
    daysRow.appendChild(daysInput);
    g3.appendChild(daysRow);

    g3.appendChild(this.buildFlagToggle(
      this.allowExpiryOverride, t.expiryOverride, t.expiryOverrideHint,
      (v) => { this.allowExpiryOverride = v; void this.saveTemplateFlag("alex_allowexpiryoverride", v); },
      !this.hasExpiry
    ));
    colA.appendChild(g3);

    strip.appendChild(colA);
    strip.appendChild(colB);
    return strip;
  }

  // Identification & authentication section: recipient PIN + auth method.
  // These are admin DEFAULTS on the template/envelope, PUT-updatable in easydo
  // and injected by the send flow (with an optional per-send override).
  private buildAuthSection(): HTMLElement {
    const t = I18N[this.lang];
    const g = this.el("div", "edo-cfield edo-tplflags");
    g.appendChild(this.el("label", "edo-clabel", t.authSection));

    // Authentication method (None / PIN / OTP-SMS). Selecting a method reveals
    // only the settings relevant to it; switching away clears the other method's
    // configuration so no stale PIN/OTP values linger.
    const authOpts = [
      { value: "1", label: t.authNone },
      { value: "2", label: t.authPin },
      { value: "3", label: t.authOtp }
    ];
    const authRow = this.el("div", "edo-flagrow");
    const authText = this.el("div", "edo-flagtext");
    authText.appendChild(this.el("div", "edo-flaglabel", t.authMethodLabel));
    authText.appendChild(this.el("div", "edo-chint", t.authMethodHint));
    authRow.appendChild(authText);
    authRow.appendChild(this.buildCombo(
      authOpts, this.authMethod != null ? String(this.authMethod) : "", t.authNone,
      (v) => { this.onAuthMethodChanged(v ? parseInt(v, 10) : null); }
    ));
    g.appendChild(authRow);

    // PIN settings — shown ONLY when the method is PIN.
    if (this.authMethod === 2) this.buildPinSettings(g);

    // OTP settings — shown ONLY when the method is OTP.
    if (this.authMethod === 3) this.buildOtpSettings(g);

    return g;
  }

  // Apply an authentication-method change and clear the other method's config.
  private onAuthMethodChanged(n: number | null): void {
    this.authMethod = n;
    void this.saveTemplateNumber("alex_authmethod", n);
    if (n !== 2) {
      // Leaving PIN — clear all PIN configuration.
      if (this.pinMode != null) { this.pinMode = null; void this.saveTemplateNumber("alex_pinmode", null); }
      if (this.pinValue) { this.pinValue = ""; void this.saveTemplateString("alex_pinvalue", ""); }
      if (this.pinSourceField) { this.pinSourceField = ""; void this.saveTemplateString("alex_pinsourcefield", ""); }
      if (this.pinAllowSendOverride) { this.pinAllowSendOverride = false; void this.saveTemplateFlag("alex_pinallowsendoverride", false); }
    } else if (this.pinMode !== 2 && this.pinMode !== 3) {
      // Entering PIN — default to Fixed PIN.
      this.pinMode = 2; void this.saveTemplateNumber("alex_pinmode", 2);
    }
    if (n !== 3) {
      // Leaving OTP — clear all OTP configuration.
      if (this.otpPhoneSource) { this.otpPhoneSource = ""; void this.saveTemplateString("alex_otpphonesource", ""); }
      if (this.otpAllowSendOverride) { this.otpAllowSendOverride = false; void this.saveTemplateFlag("alex_otpallowsendoverride", false); }
    }
    this.render();
  }

  // PIN configuration block (mode = Fixed / Variable, value or source, override).
  private buildPinSettings(g: HTMLElement): void {
    const t = I18N[this.lang];
    const mode = (this.pinMode === 2 || this.pinMode === 3) ? this.pinMode : 2;

    // PIN mode (Fixed / Variable-from-field). There is no "No PIN" here — the
    // method itself is PIN, so a PIN is always required.
    const pinOpts = [
      { value: "2", label: t.pinFixed },
      { value: "3", label: t.pinVariable }
    ];
    const pinRow = this.el("div", "edo-flagrow");
    const pinText = this.el("div", "edo-flagtext");
    pinText.appendChild(this.el("div", "edo-flaglabel", t.pinModeLabel));
    pinText.appendChild(this.el("div", "edo-chint", t.pinModeHint));
    pinRow.appendChild(pinText);
    pinRow.appendChild(this.buildCombo(
      pinOpts, String(mode), t.pinFixed,
      (v) => { this.pinMode = v ? parseInt(v, 10) : 2; void this.saveTemplateNumber("alex_pinmode", this.pinMode); this.render(); }
    ));
    g.appendChild(pinRow);

    // Fixed PIN value (only when mode = Fixed).
    if (mode === 2) {
      const valRow = this.el("div", "edo-flagrow");
      const valText = this.el("div", "edo-flagtext");
      valText.appendChild(this.el("div", "edo-flaglabel", t.pinValueLabel));
      valText.appendChild(this.el("div", "edo-chint", t.pinValueHint));
      const valInput = this.el("input", "edo-numinput") as HTMLInputElement;
      valInput.type = "text";
      valInput.style.width = "120px";
      valInput.value = this.pinValue;
      valInput.placeholder = t.pinValuePlaceholder;
      valInput.onchange = () => { this.pinValue = valInput.value.trim(); void this.saveTemplateString("alex_pinvalue", this.pinValue); };
      valRow.appendChild(valText);
      valRow.appendChild(valInput);
      g.appendChild(valRow);
    }

    // Variable PIN source field (only when mode = Variable) - pick a column of
    // the PRIMARY TABLE (a field of the main record, not an easydo form field).
    if (mode === 3) {
      const cols = this.demo
        ? (DEMO_COLS[this.lang][this.primaryTable] ?? [])
        : (this.colCache[this.primaryTable] ?? []);
      const srcOpts = cols.map(c => ({ value: c.logical, label: c.display }));
      const srcRow = this.el("div", "edo-flagrow");
      const srcText = this.el("div", "edo-flagtext");
      srcText.appendChild(this.el("div", "edo-flaglabel", t.pinSourceLabel));
      srcText.appendChild(this.el("div", "edo-chint", t.pinSourceHint));
      srcRow.appendChild(srcText);
      srcRow.appendChild(this.buildCombo(
        srcOpts, this.pinSourceField, t.pinSourceNone,
        (v) => { this.pinSourceField = v; void this.saveTemplateString("alex_pinsourcefield", this.pinSourceField); }
      ));
      g.appendChild(srcRow);
    }

    // Allow the sender to change/enter the PIN at send time.
    g.appendChild(this.buildFlagToggle(
      this.pinAllowSendOverride, t.pinOverride, t.pinOverrideHint,
      (v) => { this.pinAllowSendOverride = v; void this.saveTemplateFlag("alex_pinallowsendoverride", v); }
    ));
  }

  // OTP (SMS) configuration block — phone source column + send-time override.
  private buildOtpSettings(g: HTMLElement): void {
    const t = I18N[this.lang];

    // OTP phone source field - a column of the PRIMARY TABLE holding the phone.
    const cols = this.demo
      ? (DEMO_COLS[this.lang][this.primaryTable] ?? [])
      : (this.colCache[this.primaryTable] ?? []);
    const srcOpts = cols.map(c => ({ value: c.logical, label: c.display }));
    const srcRow = this.el("div", "edo-flagrow");
    const srcText = this.el("div", "edo-flagtext");
    srcText.appendChild(this.el("div", "edo-flaglabel", t.otpPhoneLabel));
    srcText.appendChild(this.el("div", "edo-chint", t.otpPhoneHint));
    srcRow.appendChild(srcText);
    srcRow.appendChild(this.buildCombo(
      srcOpts, this.otpPhoneSource, t.otpPhoneNone,
      (v) => { this.otpPhoneSource = v; void this.saveTemplateString("alex_otpphonesource", this.otpPhoneSource); }
    ));
    g.appendChild(srcRow);

    // Allow the sender to change/enter the OTP phone at send time.
    g.appendChild(this.buildFlagToggle(
      this.otpAllowSendOverride, t.otpOverride, t.otpOverrideHint,
      (v) => { this.otpAllowSendOverride = v; void this.saveTemplateFlag("alex_otpallowsendoverride", v); }
    ));
  }

  // A labeled on/off switch for a template-level flag, with a description line.
  private buildFlagToggle(checked: boolean, label: string, hint: string, onChange: (v: boolean) => void, disabled = false): HTMLElement {
    const t = I18N[this.lang];
    const row = this.el("div", "edo-flagrow");
    const text = this.el("div", "edo-flagtext");
    text.appendChild(this.el("div", "edo-flaglabel", label));
    text.appendChild(this.el("div", "edo-chint", hint));
    const toggle = this.buildBoolToggle(checked, t.onLbl, t.offLbl, onChange, disabled);
    row.appendChild(text);
    row.appendChild(toggle);
    return row;
  }

  private async onPrimaryChanged(table: string): Promise<void> {
    this.primaryTable = table;
    this.contactPath = "";
    this.lookups = [];
    // A new base table invalidates the variable-PIN and OTP source columns too.
    if (this.pinSourceField) { this.pinSourceField = ""; void this.saveTemplateString("alex_pinsourcefield", ""); }
    if (this.otpPhoneSource) { this.otpPhoneSource = ""; void this.saveTemplateString("alex_otpphonesource", ""); }
    // Picking a new base table invalidates per-field mappings to old sources.
    const cleared: MappingRow[] = [];
    this.rows.forEach(r => {
      if (r.table || r.lookup) { r.table = ""; r.column = ""; r.lookup = ""; cleared.push(r); }
    });
    if (table) {
      try { this.lookups = await this.fetchLookups(table); }
      catch (e) { console.warn("[easydo mapping] lookups load failed", e); }
      try { await this.fetchColumns(table); }
      catch (e) { console.warn("[easydo mapping] primary columns load failed", e); }
    }
    await this.persistConfig(true);
    for (const r of cleared) await this.persistRow(r, true);
    this.toast(I18N[this.lang].saved, "ok");
    this.render();
  }

  // Per-field source options: the primary table directly, plus one option for
  // each single lookup hop on the primary table (case -> product, case ->
  // account, ...). The value encodes "<lookupLogical>|<targetTable>" so a row
  // captures both the path and the target table; "" + primaryTable = direct.
  private sourceOptions(): { value: string; label: string }[] {
    const t = I18N[this.lang];
    const out: { value: string; label: string }[] = [];
    if (!this.primaryTable) return out;
    const base = this.tables.find(x => x.logical === this.primaryTable);
    out.push({ value: `|${this.primaryTable}`, label: base?.display ?? this.primaryTable });
    for (const lk of this.lookups) {
      for (const target of lk.targets) {
        const td = this.tables.find(x => x.logical === target);
        const tableDisplay = td?.display ?? target;
        out.push({ value: `${lk.logical}|${target}`, label: `${tableDisplay} ${t.viaSep} ${lk.display}` });
      }
    }
    return out;
  }

  private srcKey(r: MappingRow): string {
    if (!r.table) return "";
    return `${r.lookup}|${r.table}`;
  }

  private buildGrid(): HTMLElement {
    const t = I18N[this.lang];
    const grid = this.el("section", "edo-card edo-grid");

    const bar = this.el("div", "edo-gridbar");
    const titleBox = this.el("div");
    titleBox.appendChild(this.el("div", "edo-gridtitle", t.gridTitle));
    bar.appendChild(titleBox);

    // Search box sits right next to the title (item ג).
    const search = this.el("div", "edo-search");
    search.appendChild(this.el("span", "edo-ico", "⌕"));
    const input = this.el("input") as HTMLInputElement;
    input.type = "text";
    input.placeholder = t.search;
    input.value = this.filter;
    search.appendChild(input);
    bar.appendChild(search);

    bar.appendChild(this.el("div", "edo-spacer"));
    const filters = this.el("div", "edo-gridfilters");
    bar.appendChild(filters);
    grid.appendChild(bar);

    if (!this.primaryTable) {
      const state = this.el("div", "edo-state");
      state.appendChild(this.el("div", "t", t.choosePrimary));
      state.appendChild(this.el("div", "d", t.configHint));
      grid.appendChild(state);
      return grid;
    }

    if (this.rows.length === 0) {
      const state = this.el("div", "edo-state");
      state.appendChild(this.el("div", "t", t.noRows));
      state.appendChild(this.el("div", "d", t.noRowsDesc));
      grid.appendChild(state);
      return grid;
    }

    const wrap = this.el("div", "edo-tablewrap");
    const table = this.el("table", "edo-table");
    const thead = this.el("thead");
    const htr = this.el("tr");
    ([
      [t.thEasydo, t.tipEasydo], [t.thTable, t.tipTable], [t.thColumn, t.tipColumn],
      [t.thType, t.tipType], [t.thReadOnly, t.tipReadOnly], [t.thDirection, t.tipDirection],
      [t.thVisible, t.tipVisible], [t.thEditable, t.tipEditable], [t.thStatus, t.tipStatus]
    ] as [string, string][]).forEach(([h, tip]) => htr.appendChild(this.buildTh(h, tip)));
    thead.appendChild(htr);
    table.appendChild(thead);
    const tbody = this.el("tbody");
    table.appendChild(tbody);
    wrap.appendChild(table);
    grid.appendChild(wrap);

    input.oninput = () => { this.filter = input.value; this.refreshTableBody(tbody); };

    // Filters, styled as yes/no switches (items ד).
    filters.appendChild(this.buildFilterSwitch(
      t.showSignatures, this.showSignatures,
      (v) => { this.showSignatures = v; this.refreshTableBody(tbody); }
    ));
    filters.appendChild(this.buildFilterSwitch(
      t.showUnmapped, this.showUnmappedOnly,
      (v) => { this.showUnmappedOnly = v; this.refreshTableBody(tbody); }
    ));

    this.refreshTableBody(tbody);
    return grid;
  }

  // A column header with its centered label plus a small info icon that opens
  // an explanatory bubble on click (item ג).
  private buildTh(label: string, tip: string): HTMLElement {
    const th = this.el("th");
    const inner = this.el("div", "edo-th-inner");
    inner.appendChild(this.el("span", "edo-th-label", label));
    if (tip) {
      const info = this.el("span", "edo-th-info", "i");
      info.setAttribute("role", "button");
      info.setAttribute("tabindex", "0");
      info.setAttribute("aria-label", tip);
      info.title = tip;
      info.onclick = (e) => { e.stopPropagation(); this.showTip(info, tip); };
      info.onkeydown = (e) => {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); this.showTip(info, tip); }
      };
      inner.appendChild(info);
    }
    th.appendChild(inner);
    return th;
  }

  private tipEl: HTMLElement | null = null;
  private tipAnchor: HTMLElement | null = null;
  private tipDismiss: ((ev: Event) => void) | null = null;

  private hideTip(): void {
    if (this.tipDismiss) {
      window.removeEventListener("mousedown", this.tipDismiss, true);
      window.removeEventListener("scroll", this.tipDismiss, true);
      window.removeEventListener("resize", this.tipDismiss, true);
      this.tipDismiss = null;
    }
    if (this.tipEl) { this.tipEl.remove(); this.tipEl = null; }
    this.tipAnchor = null;
  }

  private showTip(anchor: HTMLElement, text: string): void {
    const reopen = this.tipAnchor === anchor;
    this.hideTip();
    if (reopen) return; // clicking the same icon again closes the bubble

    const tip = this.el("div", "edo-tip");
    tip.dir = I18N[this.lang].dir;
    tip.textContent = text;
    document.body.appendChild(tip);

    const r = anchor.getBoundingClientRect();
    const rtl = this.lang === "he";
    const w = tip.offsetWidth;
    tip.style.top = `${Math.round(r.bottom + 8)}px`;
    let left = rtl ? r.right - w : r.left;
    left = Math.max(8, Math.min(left, window.innerWidth - w - 8));
    tip.style.left = `${Math.round(left)}px`;

    this.tipEl = tip;
    this.tipAnchor = anchor;
    const dismiss = (ev: Event) => {
      if (ev.type === "mousedown" && anchor.contains(ev.target as Node)) return;
      this.hideTip();
    };
    this.tipDismiss = dismiss;
    setTimeout(() => {
      window.addEventListener("mousedown", dismiss, true);
      window.addEventListener("scroll", dismiss, true);
      window.addEventListener("resize", dismiss, true);
    }, 0);
  }

  // A compact yes/no switch with a fixed label, used for the grid filters.
  private buildFilterSwitch(label: string, checked: boolean, onChange: (v: boolean) => void): HTMLElement {
    const wrap = this.el("label", "edo-toggle edo-filtertoggle");
    const sw = this.el("span", "edo-switch");
    const cb = this.el("input") as HTMLInputElement;
    cb.type = "checkbox";
    cb.checked = checked;
    cb.onchange = () => onChange(cb.checked);
    sw.appendChild(cb);
    sw.appendChild(this.el("span", "edo-slider"));
    wrap.appendChild(sw);
    wrap.appendChild(this.el("span", "edo-toggle-label", label));
    return wrap;
  }

  private isSignatureRow(r: MappingRow): boolean {
    return (r.type || "").toLowerCase().indexOf("signature") >= 0;
  }

  private isUnmappedRow(r: MappingRow): boolean {
    return !(r.table && r.column);
  }

  private refreshTableBody(tbody: HTMLElement): void {
    const t = I18N[this.lang];
    const q = this.filter.trim().toLowerCase();
    tbody.innerHTML = "";
    const list = this.rows.filter(r =>
      (this.showSignatures || !this.isSignatureRow(r)) &&
      (!this.showUnmappedOnly || this.isUnmappedRow(r)) &&
      (!q || r.external.toLowerCase().includes(q) || r.externalId.toLowerCase().includes(q)));
    list.forEach((r, i) => tbody.appendChild(this.buildRow(r, i + 1, t)));
  }

  private buildRow(r: MappingRow, n: number, t: Record<string, string>): HTMLElement {
    const tr = this.el("tr", "row");

    const tdField = this.el("td");
    const ef = this.el("div", "edo-efield");
    ef.appendChild(this.el("span", "edo-num", String(n)));
    const fb = this.el("div");
    fb.appendChild(this.el("div", "edo-ename", r.external));
    fb.appendChild(this.el("div", "edo-ecode", r.externalId || "alex_externalfieldname"));
    ef.appendChild(fb);
    tdField.appendChild(ef);
    tr.appendChild(tdField);

    const tdTable = this.el("td");
    const tableSel = this.buildCombo(
      this.sourceOptions(),
      this.srcKey(r), t.choose,
      (v) => {
        const [lookup, table] = v.split("|");
        r.lookup = lookup || "";
        r.table = table || "";
        r.column = "";
        void this.onTableChanged(r, tr);
      }
    );
    tdTable.appendChild(tableSel);
    tdTable.appendChild(this.el("div", "edo-logic", r.lookup ? `${r.lookup} → ${r.table}` : r.table));
    tr.appendChild(tdTable);

    const tdCol = this.el("td");
    const cols = this.demo ? (DEMO_COLS[this.lang][r.table] ?? []) : (this.colCache[r.table] ?? []);
    const colSel = this.buildCombo(
      cols.map(c => ({ value: c.logical, label: c.display })),
      r.column, t.choose,
      (v) => { r.column = v; this.updateStatusCell(tr, r, t); void this.persistRow(r); },
      !r.table
    );
    tdCol.appendChild(colSel);
    tdCol.appendChild(this.el("div", "edo-logic", r.column));
    tr.appendChild(tdCol);

    const tdType = this.el("td");
    tdType.appendChild(this.el("span", "edo-chip", r.type || "—"));
    tr.appendChild(tdType);

    const tdLock = this.el("td");
    tdLock.appendChild(this.buildToggle(r, t));
    tr.appendChild(tdLock);

    const tdDir = this.el("td");
    const dirSel = this.buildCombo(
      this.dirOptions().map(o => ({ value: String(o.v), label: o.label })),
      r.direction != null ? String(r.direction) : "", t.choose,
      (v) => { r.direction = v ? Number(v) : null; void this.persistRow(r); }
    );
    tdDir.appendChild(dirSel);
    tr.appendChild(tdDir);

    const tdVis = this.el("td");
    tdVis.appendChild(this.buildBoolToggle(r.visibleToUser, t.shown, t.hidden,
      (v) => { r.visibleToUser = v; void this.persistRow(r); }));
    tr.appendChild(tdVis);

    const tdEdit = this.el("td");
    // The per-field "editable on send" toggle has no effect unless the
    // template-level master switch (allowPrefillEdit) is on, so disable it
    // visually and explain why when the master switch is off.
    const editToggle = this.buildBoolToggle(r.editableBeforeSend, t.editOn, t.editOff,
      (v) => { r.editableBeforeSend = v; void this.persistRow(r); }, !this.allowPrefillEdit);
    if (!this.allowPrefillEdit) { editToggle.title = t.editLockedByTemplate; }
    tdEdit.appendChild(editToggle);
    tr.appendChild(tdEdit);

    const tdStatus = this.el("td", "edo-status-cell");
    tr.appendChild(tdStatus);
    this.updateStatusCell(tr, r, t);

    return tr;
  }

  private async onTableChanged(r: MappingRow, tr: HTMLElement): Promise<void> {
    if (!this.demo && r.table && !this.colCache[r.table]) {
      try { await this.fetchColumns(r.table); } catch (e) { console.warn("columns load failed", e); }
    }
    const tds = tr.querySelectorAll("td");
    const colTd = tds[2];
    const t = I18N[this.lang];
    if (colTd) {
      colTd.innerHTML = "";
      const cols = this.demo ? (DEMO_COLS[this.lang][r.table] ?? []) : (this.colCache[r.table] ?? []);
      const colSel = this.buildCombo(
        cols.map(c => ({ value: c.logical, label: c.display })),
        r.column, t.choose,
        (v) => { r.column = v; this.updateStatusCell(tr, r, t); void this.persistRow(r); },
        !r.table
      );
      colTd.appendChild(colSel);
      colTd.appendChild(this.el("div", "edo-logic", r.column));
    }
    const tableTd = tds[1];
    const cap = tableTd?.querySelector(".edo-logic");
    if (cap) cap.textContent = r.lookup ? `${r.lookup} → ${r.table}` : r.table;
    this.updateStatusCell(tr, r, t);
    void this.persistRow(r);
  }

  private updateStatusCell(tr: HTMLElement, r: MappingRow, t: Record<string, string>): void {
    const cell = tr.querySelector(".edo-status-cell");
    if (!cell) return;
    cell.innerHTML = "";
    const mapped = !!(r.table && r.column);
    const s = this.el("span", `edo-status ${mapped ? "ok" : "warn"}`);
    s.appendChild(this.el("span", "edo-ico", mapped ? "✓" : "○"));
    s.appendChild(this.el("span", undefined, mapped ? t.stMapped : t.stUnmapped));
    cell.appendChild(s);
  }

  // Searchable combobox: a text input with a filterable popup list. The popup is
  // appended to <body> with fixed positioning so it is never clipped by the
  // scrolling table. onChange fires only when a real option is picked.
  private buildCombo(
    options: { value: string; label: string }[],
    selected: string,
    placeholder: string,
    onChange: (value: string) => void,
    disabled = false
  ): HTMLElement {
    const wrap = this.el("div", "edo-combo");
    if (disabled) wrap.classList.add("disabled");
    const input = this.el("input", "edo-combo-input") as HTMLInputElement;
    input.type = "text";
    input.placeholder = placeholder;
    input.autocomplete = "off";
    input.spellcheck = false;
    input.disabled = disabled;

    let current = selected;
    const labelFor = (v: string) => options.find(o => o.value === v)?.label ?? "";
    input.value = labelFor(current);
    if (!current) input.classList.add("empty");

    const pop = this.el("div", "edo-combo-pop");
    pop.style.display = "none";
    let open = false;

    const place = (): void => {
      const rect = input.getBoundingClientRect();
      pop.style.position = "fixed";
      pop.style.top = `${rect.bottom + 2}px`;
      pop.style.left = `${rect.left}px`;
      pop.style.width = `${Math.max(rect.width, 180)}px`;
    };
    const renderList = (filter: string): void => {
      pop.innerHTML = "";
      const q = filter.trim().toLowerCase();
      const matches = options.filter(o => !q || o.label.toLowerCase().includes(q) || o.value.toLowerCase().includes(q));
      if (matches.length === 0) { pop.appendChild(this.el("div", "edo-combo-empty", "—")); return; }
      matches.slice(0, 200).forEach(o => {
        const item = this.el("div", "edo-combo-item");
        item.appendChild(this.el("span", "edo-combo-lbl", o.label));
        if (this.showLogical) item.appendChild(this.el("span", "edo-combo-code", o.value));
        if (o.value === current) item.classList.add("sel");
        item.onmousedown = (e: MouseEvent) => {
          e.preventDefault();
          current = o.value;
          input.value = o.label;
          input.classList.remove("empty");
          close();
          onChange(o.value);
        };
        pop.appendChild(item);
      });
    };
    const openPop = (): void => {
      if (disabled) return;
      if (!pop.parentElement) document.body.appendChild(pop);
      open = true; place(); pop.style.display = "block"; renderList(""); input.select();
    };
    const close = (): void => {
      open = false; pop.style.display = "none";
      if (pop.parentElement) pop.parentElement.removeChild(pop);
    };

    input.onfocus = () => { if (!open) openPop(); };
    input.oninput = () => {
      if (!open) openPop();
      input.classList.toggle("empty", !input.value);
      renderList(input.value);
    };
    input.onblur = () => { setTimeout(() => { input.value = labelFor(current); input.classList.toggle("empty", !current); close(); }, 160); };

    wrap.appendChild(input);
    const caret = this.el("span", "edo-combo-caret");
    caret.setAttribute("aria-hidden", "true");
    caret.onmousedown = (e: MouseEvent) => { e.preventDefault(); if (disabled) return; if (open) { close(); } else { input.focus(); openPop(); } };
    wrap.appendChild(caret);
    return wrap;
  }

  private buildToggle(r: MappingRow, t: Record<string, string>): HTMLElement {
    const wrap = this.el("label", "edo-toggle");
    const sw = this.el("span", "edo-switch");
    const cb = this.el("input") as HTMLInputElement;
    cb.type = "checkbox";
    cb.checked = r.readOnly;
    const label = this.el("span", "edo-toggle-label", r.readOnly ? t.locked : t.editable);
    cb.onchange = () => { r.readOnly = cb.checked; label.textContent = cb.checked ? t.locked : t.editable; void this.persistRow(r); };
    sw.appendChild(cb);
    sw.appendChild(this.el("span", "edo-slider"));
    wrap.appendChild(sw);
    wrap.appendChild(label);
    return wrap;
  }

  // Generic on/off switch used by the wizard-visibility and editable columns.
  private buildBoolToggle(checked: boolean, onLabel: string, offLabel: string, onChange: (v: boolean) => void, disabled = false): HTMLElement {
    const wrap = this.el("label", disabled ? "edo-toggle edo-toggle-disabled" : "edo-toggle");
    const sw = this.el("span", "edo-switch");
    const cb = this.el("input") as HTMLInputElement;
    cb.type = "checkbox";
    cb.checked = checked;
    cb.disabled = disabled;
    const label = this.el("span", "edo-toggle-label", checked ? onLabel : offLabel);
    cb.onchange = () => { label.textContent = cb.checked ? onLabel : offLabel; onChange(cb.checked); };
    sw.appendChild(cb);
    sw.appendChild(this.el("span", "edo-slider"));
    wrap.appendChild(sw);
    wrap.appendChild(label);
    if (disabled) { wrap.style.opacity = "0.45"; wrap.style.pointerEvents = "none"; }
    return wrap;
  }

  private toast(msg: string, kind: "ok" | "err" | "" = ""): void {
    this.root.querySelectorAll(".edo-toast").forEach(e => e.remove());
    const tx = this.el("div", `edo-toast ${kind}`.trim());
    tx.appendChild(this.el("span", "edo-ico", kind === "err" ? "✕" : "✓"));
    tx.appendChild(this.el("span", undefined, msg));
    this.root.appendChild(tx);
    setTimeout(() => tx.remove(), 1900);
  }
}
