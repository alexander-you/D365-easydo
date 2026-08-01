import { IInputs, IOutputs } from "./generated/ManifestTypes";

/* =====================================================================
   easydo  -  Envelope Composition  (PCF, model-driven form control)

   Sits on the "Envelope" tab of the alex_signaturetemplate form and is only
   meaningful when alex_isenvelope = true. It reuses the exact look & feel of
   the single-document control (Template Field Mapping): same shell, hero,
   searchable comboboxes, toggles and card layout, so the admin experience is
   identical across the two controls.

   What it manages (all stored on the envelope-template record):
     - Binding: primary table + path to the signer contact + "send from record"
     - Identification & authentication: auth method + recipient PIN policy
   And it shows the envelope composition (the ordered member documents) as a
   READ-ONLY list — the composition itself is owned by the easydo sync.

   There is intentionally NO custom-message capability here.
   ===================================================================== */

type Lang = "en" | "he";

interface TableMeta { logical: string; display: string; }
interface ColMeta { logical: string; display: string; type: string; }
interface LookupMeta { logical: string; display: string; targets: string[]; }

interface EnvMember {
  id: string;
  name: string;
  sequence: number;
  externalId: string;
  role: number | null;
  syncedOn: string; // formatted value ("" when never)
}

const TEMPLATE_ENTITY = "alex_signaturetemplate";
const ITEM_ENTITY = "alex_envelopetemplateitem";
const FV = "@OData.Community.Display.V1.FormattedValue";

// Copy-link governance choice (alex_copylinkmode). Inherit follows the global
// admin default; Allow/Block are a per-envelope override read by the viewer.
const COPYLINK = { INHERIT: 626250000, ALLOW: 626250001, BLOCK: 626250002 };

/* ---- i18n --------------------------------------------------------- */
const I18N: Record<Lang, Record<string, string>> = {
  en: {
    dir: "ltr",
    brand: "Dynamics 365  ·  easydo Integration",
    title: "Envelope Composition",
    subtitle: "Configure how this multi-document envelope is sent — its base record, signer contact and authentication. The document list is kept in sync from easydo.",
    metadataDemo: "Demo data",
    docLabel: "Envelope",
    formSaveHint: "Changes are saved with the record",
    showLogical: "Show logical names", hideLogical: "Hide logical names",
    refresh: "Refresh",
    loadFailed: "Could not load data from Dynamics",
    loadingMeta: "Loading metadata…", loadingDocs: "Loading envelope documents…",
    saved: "Saved", saveErr: "Save failed",
    onLbl: "On", offLbl: "Off",
    // hero stats
    stDocs: "Documents", stLinked: "Standalone", stRoles: "Roles",
    // config
    primaryTableLabel: "Primary table", primaryHint: "The record this envelope is built on",
    choosePrimary: "Choose a base table…",
    contactPathLabel: "Path to contact", contactPathNone: "No contact link",
    contactPathHint: "Which lookup on the primary record points to the signer contact",
    tplSettings: "Envelope settings",
    sendFromObject: "Allow send from record", sendFromObjectHint: "Show this envelope in the send wizard launched from a record",
    copyLinkLabel: "Signing link", copyLinkHint: "Whether the signing link for this envelope is shown in the results pane (open and copy)",
    copyLinkInherit: "Follow global setting", copyLinkAllow: "Always show", copyLinkBlock: "Always hide",
    // auth
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
    // composition grid
    compTitle: "Envelope documents",
    thSeq: "#", thDoc: "Document", thRole: "Signing role", thSynced: "Last synced",
    roleInherit: "Inherit", roleSigner: "Signer",
    neverSynced: "Never",
    noDocs: "This envelope has no documents yet", noDocsDesc: "Run the easydo template sync, then reopen this envelope.",
    notEnvelope: "This template is not an envelope", notEnvelopeDesc: "Envelope composition is only available for multi-document envelope templates."
  },
  he: {
    dir: "rtl",
    brand: "Dynamics 365  ·  אינטגרציית easydo",
    title: "הרכב מעטפה",
    subtitle: "הגדירו כיצד נשלחת מעטפת המסמכים — רשומת הבסיס, איש הקשר החותם והאימות. רשימת המסמכים מסונכרנת מ‑easydo.",
    metadataDemo: "נתוני דמו",
    docLabel: "מעטפה",
    formSaveHint: "השינויים נשמרים יחד עם הרשומה",
    showLogical: "הצג שמות לוגיים", hideLogical: "הסתר שמות לוגיים",
    refresh: "רענון",
    loadFailed: "טעינת הנתונים מדינמיקס נכשלה",
    loadingMeta: "טוען מטא‑דאטה…", loadingDocs: "טוען את מסמכי המעטפה…",
    saved: "נשמר", saveErr: "השמירה נכשלה",
    onLbl: "פעיל", offLbl: "כבוי",
    stDocs: "מסמכים", stLinked: "עצמאיים", stRoles: "תפקידים",
    primaryTableLabel: "טבלה ראשית", primaryHint: "הרשומה שעליה בנויה המעטפה",
    choosePrimary: "בחרו טבלת בסיס…",
    contactPathLabel: "נתיב לאיש קשר", contactPathNone: "אין קישור לאיש קשר",
    contactPathHint: "איזה שדה lookup ברשומה הראשית מצביע על איש הקשר החותם",
    tplSettings: "הגדרות מעטפה",
    sendFromObject: "אפשר שליחה מתוך הרשומה", sendFromObjectHint: "הצגת המעטפה באשף השליחה שנפתח מרשומה",
    copyLinkLabel: "קישור חתימה", copyLinkHint: "האם קישור החתימה של מעטפה זו מוצג בחלונית התוצאות (פתיחה והעתקה)",
    copyLinkInherit: "לפי הגדרת ברירת המחדל", copyLinkAllow: "הצג תמיד", copyLinkBlock: "הסתר תמיד",
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
    compTitle: "מסמכי המעטפה",
    thSeq: "#", thDoc: "מסמך", thRole: "תפקיד חתימה", thSynced: "סונכרן לאחרונה",
    roleInherit: "בירושה", roleSigner: "חותם",
    neverSynced: "מעולם לא",
    noDocs: "למעטפה זו אין עדיין מסמכים", noDocsDesc: "הריצו את סנכרון תבניות easydo ופתחו מחדש את המעטפה.",
    notEnvelope: "תבנית זו אינה מעטפה", notEnvelopeDesc: "הרכב מעטפה זמין רק לתבניות מעטפה מרובות‑מסמכים."
  }
};

/* ---- demo fallback ------------------------------------------------ */
const DEMO_TABLES: Record<Lang, TableMeta[]> = {
  en: [{ logical: "contact", display: "Contact" }, { logical: "account", display: "Account" }, { logical: "incident", display: "Case" }],
  he: [{ logical: "contact", display: "איש קשר" }, { logical: "account", display: "לקוח" }, { logical: "incident", display: "פנייה" }]
};
const DEMO_COLS: Record<Lang, Record<string, ColMeta[]>> = {
  en: {
    incident: [{ logical: "title", display: "Case Title", type: "Text" }, { logical: "ticketnumber", display: "Case Number", type: "Text" }],
    contact: [{ logical: "fullname", display: "Full Name", type: "Text" }, { logical: "alex_governmentid", display: "Government ID", type: "Text" }]
  },
  he: {
    incident: [{ logical: "title", display: "כותרת פנייה", type: "טקסט" }, { logical: "ticketnumber", display: "מספר פנייה", type: "טקסט" }],
    contact: [{ logical: "fullname", display: "שם מלא", type: "טקסט" }, { logical: "alex_governmentid", display: "מספר מזהה", type: "טקסט" }]
  }
};
function demoMembers(lang: Lang): EnvMember[] {
  const he = lang === "he";
  return [
    { id: "d1", name: he ? "טופס קליטה" : "Onboarding form", sequence: 1, externalId: "tpl_a1", role: 1, syncedOn: he ? "לפני שעה" : "1h ago" },
    { id: "d2", name: he ? "הצהרת סודיות" : "NDA declaration", sequence: 2, externalId: "tpl_b2", role: 1, syncedOn: he ? "לפני שעה" : "1h ago" },
    { id: "d3", name: he ? "אישור מעביד" : "Employer approval", sequence: 3, externalId: "tpl_c3", role: 2, syncedOn: he ? "לפני שעה" : "1h ago" }
  ];
}

/* ===================================================================== */
export class EnvelopeComposition implements ComponentFramework.StandardControl<IInputs, IOutputs> {
  private context!: ComponentFramework.Context<IInputs>;
  private root!: HTMLDivElement;
  private hostValue = "";

  private lang: Lang = "en";
  private showLogical = false;
  private demo = false;
  private templateId = "";
  private templateName = "";
  private isEnvelope = false;

  private allowSendFromObject = false; // alex_allowsendfromobject
  private copyLinkMode: number | null = null;  // alex_copylinkmode (Inherit/Allow/Block)
  private authMethod: number | null = null;   // alex_authmethod
  private pinMode: number | null = null;       // alex_pinmode
  private pinValue = "";                        // alex_pinvalue
  private pinSourceField = "";                  // alex_pinsourcefield
  private pinAllowSendOverride = false;         // alex_pinallowsendoverride
  private otpPhoneSource = "";                  // alex_otpphonesource
  private otpAllowSendOverride = false;         // alex_otpallowsendoverride

  private primaryTable = "";
  private contactPath = "";
  private lookups: LookupMeta[] = [];
  private tables: TableMeta[] = [];
  private colCache: Record<string, ColMeta[]> = {};
  private members: EnvMember[] = [];

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

    const newId = this.getTemplateId();
    if (newId && newId !== this.templateId) {
      this.templateId = newId;
      this.templateName = this.getTemplateName();
      this.colCache = {};
      this.members = [];
      this.primaryTable = "";
      this.contactPath = "";
      this.allowSendFromObject = false;
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
    if (!this.templateId || !this.context.webAPI || !this.getClientUrl()) {
      this.enterDemo();
      return;
    }
    try {
      this.tables = await this.fetchTables();
      await this.fetchTemplateConfig();
      if (this.primaryTable) {
        try { this.lookups = await this.fetchLookups(this.primaryTable); }
        catch (e) { console.warn("[easydo envelope] lookups load failed", e); }
        try { await this.fetchColumns(this.primaryTable); }
        catch (e) { console.warn("[easydo envelope] primary columns load failed", e); }
      }
      if (this.isEnvelope) {
        this.renderLoading(I18N[this.lang].loadingDocs);
        this.members = await this.fetchMembers();
      }
      this.demo = false;
      this.render();
    } catch (e) {
      console.error("[easydo envelope] live load failed:", e);
      this.renderError(e instanceof Error ? e.message : String(e));
    }
  }

  private enterDemo(): void {
    this.demo = true;
    this.isEnvelope = true;
    this.tables = DEMO_TABLES[this.lang];
    this.colCache = {};
    this.members = demoMembers(this.lang);
    this.primaryTable = "incident";
    this.contactPath = "";
    this.allowSendFromObject = true;
    this.copyLinkMode = null;
    this.lookups = [
      { logical: "primarycontactid", display: this.lang === "he" ? "איש קשר ראשי" : "Primary Contact", targets: ["contact"] },
      { logical: "customerid", display: this.lang === "he" ? "לקוח" : "Customer", targets: ["account"] }
    ];
    if (!this.templateName) this.templateName = this.lang === "he" ? "מעטפת קליטת עובד" : "Employee onboarding envelope";
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

  private async fetchLookups(base: string): Promise<LookupMeta[]> {
    if (!base) return [];
    if (this.demo) {
      return base === "incident"
        ? [
            { logical: "primarycontactid", display: this.lang === "he" ? "איש קשר ראשי" : "Primary Contact", targets: ["contact"] },
            { logical: "customerid", display: this.lang === "he" ? "לקוח" : "Customer", targets: ["account"] }
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

  private async fetchTemplateConfig(): Promise<void> {
    try {
      const rec = await this.context.webAPI.retrieveRecord(
        TEMPLATE_ENTITY, this.templateId,
        "?$select=alex_name,alex_isenvelope,alex_primarytable,alex_contactpath,alex_allowsendfromobject,alex_authmethod,alex_pinmode,alex_pinvalue,alex_pinsourcefield,alex_pinallowsendoverride,alex_otpphonesource,alex_otpallowsendoverride,alex_copylinkmode"
      );
      this.isEnvelope = rec["alex_isenvelope"] === true;
      this.primaryTable = (rec["alex_primarytable"] as string) ?? "";
      this.contactPath = (rec["alex_contactpath"] as string) ?? "";
      this.allowSendFromObject = rec["alex_allowsendfromobject"] === true;
      this.copyLinkMode = (rec["alex_copylinkmode"] as number) ?? null;
      this.authMethod = (rec["alex_authmethod"] as number) ?? null;
      this.pinMode = (rec["alex_pinmode"] as number) ?? null;
      this.pinValue = (rec["alex_pinvalue"] as string) ?? "";
      this.pinSourceField = (rec["alex_pinsourcefield"] as string) ?? "";
      this.pinAllowSendOverride = rec["alex_pinallowsendoverride"] === true;
      this.otpPhoneSource = (rec["alex_otpphonesource"] as string) ?? "";
      this.otpAllowSendOverride = rec["alex_otpallowsendoverride"] === true;
      if (!this.templateName && rec["alex_name"]) this.templateName = rec["alex_name"] as string;
    } catch (e) {
      console.warn("[easydo envelope] config load failed", e);
    }
  }

  private async fetchMembers(): Promise<EnvMember[]> {
    const select = "alex_envelopetemplateitemid,alex_name,alex_sequence,alex_externaltemplateid,alex_defaultroleid,alex_lastsyncedon";
    const q = `?$select=${select}&$filter=_alex_envelopeid_value eq ${this.templateId}&$orderby=alex_sequence`;
    const res = await this.context.webAPI.retrieveMultipleRecords(ITEM_ENTITY, q);
    return res.entities.map(e => ({
      id: e["alex_envelopetemplateitemid"] as string,
      name: (e["alex_name"] as string) ?? "",
      sequence: (e["alex_sequence"] as number) ?? 0,
      externalId: (e["alex_externaltemplateid"] as string) ?? "",
      role: (e["alex_defaultroleid"] as number) ?? null,
      syncedOn: (e[`alex_lastsyncedon${FV}`] as string) ?? ""
    }));
  }

  /* ---- persistence (immediate) ----------------------------------- */
  private async saveTemplateConfig(): Promise<void> {
    if (this.demo || !this.templateId) return;
    await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, {
      alex_primarytable: this.primaryTable || null,
      alex_contactpath: this.contactPath || null
    });
  }

  private async saveTemplateFlag(field: string, value: boolean): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !this.templateId) return;
    try {
      const body: Record<string, unknown> = {};
      body[field] = value;
      await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, body);
      this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo envelope] flag save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  private async saveTemplateNumber(field: string, value: number | null): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !this.templateId) return;
    try {
      const body: Record<string, unknown> = {};
      body[field] = value;
      await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, body);
      this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo envelope] number save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  private async saveTemplateString(field: string, value: string): Promise<void> {
    const t = I18N[this.lang];
    if (this.demo || !this.templateId) return;
    try {
      const body: Record<string, unknown> = {};
      body[field] = value || null;
      await this.context.webAPI.updateRecord(TEMPLATE_ENTITY, this.templateId, body);
      this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo envelope] string save failed", e);
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
      console.error("[easydo envelope] config save failed", e);
      this.toast(t.saveErr, "err");
    }
  }

  private async onPrimaryChanged(table: string): Promise<void> {
    this.primaryTable = table;
    this.contactPath = "";
    this.lookups = [];
    if (this.pinSourceField) { this.pinSourceField = ""; void this.saveTemplateString("alex_pinsourcefield", ""); }
    if (this.otpPhoneSource) { this.otpPhoneSource = ""; void this.saveTemplateString("alex_otpphonesource", ""); }
    if (table) {
      try { this.lookups = await this.fetchLookups(table); }
      catch (e) { console.warn("[easydo envelope] lookups load failed", e); }
      try { await this.fetchColumns(table); }
      catch (e) { console.warn("[easydo envelope] primary columns load failed", e); }
    }
    await this.persistConfig(true);
    this.toast(I18N[this.lang].saved, "ok");
    this.render();
  }

  private async refresh(): Promise<void> {
    this.colCache = {};
    this.renderLoading(I18N[this.lang].loadingMeta);
    await this.bootstrap();
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

  private btn(ico: string, label: string, extra = ""): HTMLButtonElement {
    const b = this.el("button", `edo-btn ${extra}`.trim()) as HTMLButtonElement;
    b.appendChild(this.el("span", "edo-ico", ico));
    b.appendChild(this.el("span", undefined, label));
    return b;
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

    if (!this.isEnvelope) {
      const card = this.el("section", "edo-card");
      const state = this.el("div", "edo-state");
      state.appendChild(this.el("div", "t", t.notEnvelope));
      state.appendChild(this.el("div", "d", t.notEnvelopeDesc));
      card.appendChild(state);
      shell.appendChild(card);
      this.root.appendChild(shell);
      return;
    }

    shell.appendChild(this.buildConfigStrip());
    shell.appendChild(this.buildComposition());
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

    const docs = this.members.length;
    const linked = this.members.filter(m => !!m.externalId).length;
    const roles = new Set(this.members.map(m => m.role ?? 0)).size;
    const tiles = this.el("div", "edo-hero-stats");
    tiles.appendChild(this.heroStat(String(docs), t.stDocs));
    tiles.appendChild(this.heroStat(String(linked), t.stLinked));
    tiles.appendChild(this.heroStat(String(roles), t.stRoles));
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
      doc.appendChild(this.el("span", "edo-doctitle-ico", "\u2709"));
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

  private buildConfigStrip(): HTMLElement {
    const t = I18N[this.lang];
    const strip = this.el("div", "edo-card edo-config");
    const colA = this.el("div", "edo-config-col");
    const colB = this.el("div", "edo-config-col");

    // Primary table.
    const g1 = this.el("div", "edo-cfield");
    g1.appendChild(this.el("label", "edo-clabel", t.primaryTableLabel));
    g1.appendChild(this.buildCombo(
      this.tables.map(tb => ({ value: tb.logical, label: tb.display })),
      this.primaryTable, t.choosePrimary,
      (v) => void this.onPrimaryChanged(v)
    ));
    g1.appendChild(this.el("div", "edo-chint", t.primaryHint));
    colA.appendChild(g1);

    // Path to the signer contact.
    const gc = this.el("div", "edo-cfield");
    gc.appendChild(this.el("label", "edo-clabel", t.contactPathLabel));
    const contactOpts = this.lookups
      .filter(l => l.targets.includes("contact"))
      .map(l => ({ value: l.logical, label: l.display }));
    gc.appendChild(this.buildCombo(
      contactOpts, this.contactPath, t.contactPathNone,
      (v) => { this.contactPath = v; void this.saveTemplateConfig(); }
    ));
    gc.appendChild(this.el("div", "edo-chint", t.contactPathHint));
    colA.appendChild(gc);

    // Envelope-level flags.
    const g2 = this.el("div", "edo-cfield edo-tplflags");
    g2.appendChild(this.el("label", "edo-clabel", t.tplSettings));
    g2.appendChild(this.buildFlagToggle(
      this.allowSendFromObject, t.sendFromObject, t.sendFromObjectHint,
      (v) => { this.allowSendFromObject = v; void this.saveTemplateFlag("alex_allowsendfromobject", v); }
    ));

    // Signing-link governance (Inherit / Allow / Block). Inherit follows the
    // global admin default; Allow/Block are a per-envelope override read by the
    // results viewer when it decides whether to show the signing link.
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
    colA.appendChild(g2);

    // Identification & authentication.
    colB.appendChild(this.buildAuthSection());

    strip.appendChild(colA);
    strip.appendChild(colB);
    return strip;
  }

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

  // Read-only list of the envelope member documents (owned by easydo sync).
  private buildComposition(): HTMLElement {
    const t = I18N[this.lang];
    const grid = this.el("section", "edo-card edo-grid");

    const bar = this.el("div", "edo-gridbar");
    const titleBox = this.el("div");
    titleBox.appendChild(this.el("div", "edo-gridtitle", t.compTitle));
    bar.appendChild(titleBox);
    grid.appendChild(bar);

    if (this.members.length === 0) {
      const state = this.el("div", "edo-state");
      state.appendChild(this.el("div", "t", t.noDocs));
      state.appendChild(this.el("div", "d", t.noDocsDesc));
      grid.appendChild(state);
      return grid;
    }

    const wrap = this.el("div", "edo-tablewrap");
    const table = this.el("table", "edo-table");
    const thead = this.el("thead");
    const htr = this.el("tr");
    [t.thSeq, t.thDoc, t.thRole, t.thSynced].forEach(h => {
      const th = this.el("th");
      th.appendChild(this.el("div", "edo-th-inner", h));
      htr.appendChild(th);
    });
    thead.appendChild(htr);
    table.appendChild(thead);

    const tbody = this.el("tbody");
    this.members.forEach((m, i) => {
      const tr = this.el("tr", "row");

      const tdSeq = this.el("td");
      tdSeq.appendChild(this.el("span", "edo-num", String(m.sequence || i + 1)));
      tr.appendChild(tdSeq);

      const tdDoc = this.el("td");
      const ef = this.el("div", "edo-efield");
      const meta = this.el("div");
      meta.appendChild(this.el("div", "edo-ename", m.name || "—"));
      if (m.externalId) meta.appendChild(this.el("div", "edo-ecode", m.externalId));
      ef.appendChild(meta);
      tdDoc.appendChild(ef);
      tr.appendChild(tdDoc);

      const tdRole = this.el("td");
      const roleLabel = m.role && m.role >= 1 ? `${t.roleSigner} ${m.role}` : t.roleInherit;
      tdRole.appendChild(this.el("span", "edo-chip", roleLabel));
      tr.appendChild(tdRole);

      const tdSync = this.el("td");
      tdSync.appendChild(this.el("span", "edo-toggle-label", m.syncedOn || t.neverSynced));
      tr.appendChild(tdSync);

      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    wrap.appendChild(table);
    grid.appendChild(wrap);
    return grid;
  }

  // A labeled on/off switch with a description line.
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

  // Searchable combobox: a text input with a filterable popup list. The popup is
  // appended to <body> with fixed positioning so it is never clipped.
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

  private toast(msg: string, kind: "ok" | "err" | "" = ""): void {
    this.root.querySelectorAll(".edo-toast").forEach(e => e.remove());
    const tx = this.el("div", `edo-toast ${kind}`.trim());
    tx.appendChild(this.el("span", "edo-ico", kind === "err" ? "✕" : "✓"));
    tx.appendChild(this.el("span", undefined, msg));
    this.root.appendChild(tx);
    setTimeout(() => tx.remove(), 1900);
  }
}
