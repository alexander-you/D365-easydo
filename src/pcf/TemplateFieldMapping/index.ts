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
  table: string;         // alex_dynamicstable
  column: string;        // alex_dynamicsfield
  readOnly: boolean;     // alex_isreadonly
  direction: number | null; // alex_direction (choice)
  dirty: boolean;
}

const ENTITY = "alex_templatefieldmapping";
const TEMPLATE_ENTITY = "alex_signaturetemplate";
const DIR = { PREFILL: 626210000, READBACK: 626210001, BIDIR: 626210002 };

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
    thEasydo: "easydo field", thTable: "Dynamics table", thColumn: "Dynamics column", thType: "Type", thReadOnly: "Locked", thDirection: "Direction", thStatus: "Status",
    choose: "Choose…",
    locked: "Locked", editable: "Editable",
    dirPrefill: "Prefill", dirReadback: "Read back", dirBidir: "Bidirectional",
    stMapped: "Mapped", stUnmapped: "Unmapped",
    recordContext: "Record context", sourceTable: "Source table", mappingTable: "Mapping table", solution: "Solution", prefix: "Prefix", template: "Template",
    summary: "Summary", total: "Fields", mappedN: "Mapped", lockedN: "Locked", bindings: "Bindings",
    saveBehavior: "Save behavior",
    saveNote: "Only the Dynamics table, column, lock and direction are written. The easydo binding (alex_externalfieldname) is never overwritten.",
    saved: "Mapping saved", nothingToSave: "No changes to save", validOk: "All mappings are valid", validFail: "Some fields are missing a table or column", refreshed: "Metadata refreshed", saveErr: "Save failed",
    loadingMeta: "Loading metadata…", loadingRows: "Loading field mappings…",
    demoTitle: "Demo preview", demoDesc: "No template record in context — showing sample data. Open this control on a template form to load live fields.",
    noRows: "This template has no synced fields yet", noRowsDesc: "Run the easydo template sync, then reopen this template."
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
    thEasydo: "שדה easydo", thTable: "טבלת Dynamics", thColumn: "עמודת Dynamics", thType: "סוג", thReadOnly: "נעול", thDirection: "כיוון", thStatus: "סטטוס",
    choose: "בחר…",
    locked: "נעול", editable: "ניתן לעריכה",
    dirPrefill: "מילוי מקדים", dirReadback: "קריאה חזרה", dirBidir: "דו‑כיווני",
    stMapped: "ממופה", stUnmapped: "לא ממופה",
    recordContext: "הקשר רשומה", sourceTable: "טבלת מקור", mappingTable: "טבלת מיפוי", solution: "פתרון", prefix: "תחילית", template: "תבנית",
    summary: "סיכום", total: "שדות", mappedN: "ממופים", lockedN: "נעולים", bindings: "קישורים",
    saveBehavior: "התנהגות שמירה",
    saveNote: "נשמרים רק הטבלה, העמודה, הנעילה והכיוון. קישור ה‑easydo ‏(alex_externalfieldname) לעולם אינו נדרס.",
    saved: "המיפוי נשמר", nothingToSave: "אין שינויים לשמירה", validOk: "כל המיפויים תקינים", validFail: "בחלק מהשדות חסרה טבלה או עמודה", refreshed: "המטא‑דאטה רוענן", saveErr: "השמירה נכשלה",
    loadingMeta: "טוען מטא‑דאטה…", loadingRows: "טוען מיפויי שדות…",
    demoTitle: "תצוגת דמו", demoDesc: "אין רשומת תבנית בהקשר — מוצגים נתוני דוגמה. פתחו את הפקד על טופס תבנית כדי לטעון שדות חיים.",
    noRows: "לתבנית זו אין עדיין שדות מסונכרנים", noRowsDesc: "הריצו את סנכרון תבניות easydo ופתחו מחדש את התבנית."
  }
};

/* ---- demo fallback ------------------------------------------------ */
const DEMO_TABLES: Record<Lang, TableMeta[]> = {
  en: [{ logical: "contact", display: "Contact" }, { logical: "account", display: "Account" }, { logical: "incident", display: "Case" }],
  he: [{ logical: "contact", display: "איש קשר" }, { logical: "account", display: "לקוח" }, { logical: "incident", display: "פנייה" }]
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
    incident: [{ logical: "title", display: "Case Title", type: "Text" }, { logical: "createdon", display: "Created On", type: "DateTime" }]
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
    incident: [{ logical: "title", display: "כותרת פנייה", type: "טקסט" }, { logical: "createdon", display: "נוצר בתאריך", type: "תאריך ושעה" }]
  }
};
function demoRows(): MappingRow[] {
  return [
    { external: "contact.fullname", externalId: "custom_field_a", type: "input-text", table: "contact", column: "fullname", readOnly: true, direction: DIR.PREFILL },
    { external: "contact.alex_governmentid", externalId: "custom_field_b", type: "input-text", table: "contact", column: "alex_governmentid", readOnly: true, direction: DIR.PREFILL },
    { external: "contact.emailaddress1", externalId: "custom_field_c", type: "input-text", table: "contact", column: "emailaddress1", readOnly: false, direction: DIR.BIDIR },
    { external: "contact.mobilephone", externalId: "custom_field_d", type: "input-text", table: "contact", column: "mobilephone", readOnly: false, direction: DIR.BIDIR },
    { external: "Sign.Date", externalId: "custom_field_e", type: "input-date", table: "", column: "", readOnly: false, direction: null },
    { external: "AcademicYear", externalId: "custom_field_f", type: "input-text", table: "", column: "", readOnly: false, direction: null }
  ].map(r => ({ ...r, id: "", dirty: false }));
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
  private saving = false;

  private tables: TableMeta[] = [];
  private colCache: Record<string, ColMeta[]> = {};
  private rows: MappingRow[] = [];
  private filter = "";

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
    if (!this.templateId || !this.context.webAPI) {
      this.enterDemo();
      return;
    }
    try {
      this.tables = await this.fetchTables();
      this.renderLoading(I18N[this.lang].loadingRows);
      this.rows = await this.fetchRows();
      const used = Array.from(new Set(this.rows.map(r => r.table).filter(Boolean)));
      await Promise.all(used.map(t => this.fetchColumns(t)));
      this.demo = false;
      this.render();
    } catch (e) {
      console.warn("[easydo mapping] live load failed, falling back to demo:", e);
      this.enterDemo();
    }
  }

  private enterDemo(): void {
    this.demo = true;
    this.tables = DEMO_TABLES[this.lang];
    this.colCache = {};
    this.rows = demoRows();
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
      "EntityDefinitions?$select=LogicalName,DisplayName&$filter=IsValidForAdvancedFind/Value eq true and IsIntersect eq false"
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
      `?$select=LogicalName,DisplayName,AttributeType&$filter=IsValidForRead/Value eq true and AttributeOf eq null`
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
      "alex_externalfieldtype,alex_dynamicstable,alex_dynamicsfield,alex_isreadonly,alex_direction";
    const q = `?$select=${select}&$filter=_alex_templateid_value eq ${this.templateId}&$orderby=alex_externalfieldname`;
    const res = await this.context.webAPI.retrieveMultipleRecords(ENTITY, q);
    return res.entities.map(e => ({
      id: e["alex_templatefieldmappingid"] as string,
      external: (e["alex_externalfieldname"] as string) ?? (e["alex_externalfieldid"] as string) ?? "",
      externalId: (e["alex_externalfieldid"] as string) ?? "",
      type: (e["alex_externalfieldtype"] as string) ?? "",
      table: (e["alex_dynamicstable"] as string) ?? "",
      column: (e["alex_dynamicsfield"] as string) ?? "",
      readOnly: !!e["alex_isreadonly"],
      direction: (e["alex_direction"] as number) ?? null,
      dirty: false
    }));
  }

  /* ---- save / actions -------------------------------------------- */
  private async save(): Promise<void> {
    const t = I18N[this.lang];
    const dirty = this.rows.filter(r => r.dirty && r.id);
    if (this.demo || dirty.length === 0) { this.toast(t.nothingToSave); return; }
    this.saving = true; this.render();
    try {
      for (const r of dirty) {
        await this.context.webAPI.updateRecord(ENTITY, r.id, {
          alex_dynamicstable: r.table || null,
          alex_dynamicsfield: r.column || null,
          alex_isreadonly: r.readOnly,
          alex_direction: r.direction
        });
        r.dirty = false;
      }
      this.toast(t.saved, "ok");
    } catch (e) {
      console.error("[easydo mapping] save failed", e);
      this.toast(t.saveErr, "err");
    } finally {
      this.saving = false; this.render();
    }
  }

  private validate(): void {
    const t = I18N[this.lang];
    const bad = this.rows.some(r => (r.table && !r.column) || (!r.table && r.column));
    this.toast(bad ? t.validFail : t.validOk, bad ? "err" : "ok");
  }

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

  private render(): void {
    const t = I18N[this.lang];
    this.root.dir = t.dir;
    this.root.classList.toggle("hide-logic", !this.showLogical);
    this.root.innerHTML = "";

    const shell = this.el("div", "edo-shell");
    shell.appendChild(this.buildHero());
    shell.appendChild(this.buildCmdBar());

    const body = this.el("div", "edo-body");
    body.appendChild(this.buildGrid());
    body.appendChild(this.buildSide());
    shell.appendChild(body);

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
    hero.appendChild(top);

    const main = this.el("div", "edo-hero-main");
    const left = this.el("div");
    left.appendChild(this.el("h1", undefined, t.title));
    left.appendChild(this.el("div", "edo-sub", t.subtitle));
    main.appendChild(left);

    const pills = this.el("div", "edo-pills");
    const meta = this.el("span", "edo-pill ok");
    meta.appendChild(this.el("span", "edo-dot"));
    meta.appendChild(this.el("span", undefined, this.demo ? t.metadataDemo : t.metadataLoaded));
    pills.appendChild(meta);
    const mappedN = this.rows.filter(r => r.table && r.column).length;
    const cnt = this.el("span", "edo-pill");
    cnt.appendChild(this.el("span", undefined, `${mappedN}/${this.rows.length} ${t.mapped}`));
    pills.appendChild(cnt);
    pills.appendChild(this.el("span", "edo-pill", t.directOnly));
    main.appendChild(pills);

    hero.appendChild(main);
    return hero;
  }

  private buildCmdBar(): HTMLElement {
    const t = I18N[this.lang];
    const bar = this.el("div", "edo-card edo-cmdbar");

    const save = this.el("button", "edo-btn primary") as HTMLButtonElement;
    save.appendChild(this.el("span", "edo-ico", "✓"));
    save.appendChild(this.el("span", undefined, this.saving ? t.saving : t.save));
    save.disabled = this.saving || this.demo;
    save.onclick = () => void this.save();
    bar.appendChild(save);

    const validate = this.btn("◇", t.validate);
    validate.onclick = () => this.validate();
    bar.appendChild(validate);

    const refresh = this.btn("↻", t.refresh);
    refresh.onclick = () => void this.refresh();
    bar.appendChild(refresh);

    bar.appendChild(this.el("div", "edo-spacer"));

    const logic = this.btn("⌥", this.showLogical ? t.hideLogical : t.showLogical, "ghost");
    logic.onclick = () => { this.showLogical = !this.showLogical; this.render(); };
    bar.appendChild(logic);

    const lang = this.btn("🌐", t.langBtn, "ghost");
    lang.onclick = () => { this.lang = this.lang === "en" ? "he" : "en"; if (this.demo) this.enterDemo(); else this.render(); };
    bar.appendChild(lang);

    return bar;
  }

  private btn(ico: string, label: string, extra = ""): HTMLButtonElement {
    const b = this.el("button", `edo-btn ${extra}`.trim()) as HTMLButtonElement;
    b.appendChild(this.el("span", "edo-ico", ico));
    b.appendChild(this.el("span", undefined, label));
    return b;
  }

  private buildGrid(): HTMLElement {
    const t = I18N[this.lang];
    const grid = this.el("section", "edo-card edo-grid");

    const bar = this.el("div", "edo-gridbar");
    const titleBox = this.el("div");
    titleBox.appendChild(this.el("div", "edo-gridtitle", t.gridTitle));
    const meta = this.el("div", "edo-gridmeta");
    meta.appendChild(document.createTextNode(t.gridMeta + " "));
    meta.appendChild(this.el("code", undefined, ENTITY));
    titleBox.appendChild(meta);
    bar.appendChild(titleBox);

    const search = this.el("div", "edo-search");
    search.appendChild(this.el("span", "edo-ico", "⌕"));
    const input = this.el("input") as HTMLInputElement;
    input.type = "text";
    input.placeholder = t.search;
    input.value = this.filter;
    bar.appendChild(search);
    grid.appendChild(bar);

    if (this.rows.length === 0) {
      const state = this.el("div", "edo-state");
      state.appendChild(this.el("div", "t", t.noRows));
      state.appendChild(this.el("div", "d", t.noRowsDesc));
      grid.appendChild(state);
      search.appendChild(input);
      return grid;
    }

    const wrap = this.el("div", "edo-tablewrap");
    const table = this.el("table", "edo-table");
    const thead = this.el("thead");
    const htr = this.el("tr");
    [t.thEasydo, t.thTable, t.thColumn, t.thType, t.thReadOnly, t.thDirection, t.thStatus]
      .forEach(h => htr.appendChild(this.el("th", undefined, h)));
    thead.appendChild(htr);
    table.appendChild(thead);
    const tbody = this.el("tbody");
    table.appendChild(tbody);
    wrap.appendChild(table);
    grid.appendChild(wrap);

    input.oninput = () => { this.filter = input.value; this.refreshTableBody(tbody); };
    search.appendChild(input);

    this.refreshTableBody(tbody);
    return grid;
  }

  private refreshTableBody(tbody: HTMLElement): void {
    const t = I18N[this.lang];
    const q = this.filter.trim().toLowerCase();
    tbody.innerHTML = "";
    const list = this.rows.filter(r => !q || r.external.toLowerCase().includes(q) || r.externalId.toLowerCase().includes(q));
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
    const tableSel = this.buildSelect(
      this.tables.map(tb => ({ value: tb.logical, label: tb.display })),
      r.table, t.choose
    );
    tableSel.onchange = () => {
      r.table = tableSel.value;
      r.column = "";
      r.dirty = true;
      void this.onTableChanged(r, tr);
    };
    tdTable.appendChild(tableSel);
    tdTable.appendChild(this.el("div", "edo-logic", r.table));
    tr.appendChild(tdTable);

    const tdCol = this.el("td");
    const cols = this.demo ? (DEMO_COLS[this.lang][r.table] ?? []) : (this.colCache[r.table] ?? []);
    const colSel = this.buildSelect(
      cols.map(c => ({ value: c.logical, label: c.display })),
      r.column, t.choose
    );
    colSel.disabled = !r.table;
    colSel.onchange = () => { r.column = colSel.value; r.dirty = true; this.updateStatusCell(tr, r, t); };
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
    const dirSel = this.buildSelect(
      this.dirOptions().map(o => ({ value: String(o.v), label: o.label })),
      r.direction != null ? String(r.direction) : "", t.choose
    );
    dirSel.onchange = () => { r.direction = dirSel.value ? Number(dirSel.value) : null; r.dirty = true; };
    tdDir.appendChild(dirSel);
    tr.appendChild(tdDir);

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
      const colSel = this.buildSelect(cols.map(c => ({ value: c.logical, label: c.display })), r.column, t.choose);
      colSel.disabled = !r.table;
      colSel.onchange = () => { r.column = colSel.value; r.dirty = true; this.updateStatusCell(tr, r, t); };
      colTd.appendChild(colSel);
      colTd.appendChild(this.el("div", "edo-logic", r.column));
    }
    const tableTd = tds[1];
    const cap = tableTd?.querySelector(".edo-logic");
    if (cap) cap.textContent = r.table;
    this.updateStatusCell(tr, r, t);
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

  private buildSelect(options: { value: string; label: string }[], selected: string, placeholder: string): HTMLSelectElement {
    const sel = this.el("select", "edo-sel") as HTMLSelectElement;
    const ph = this.el("option", undefined, placeholder) as HTMLOptionElement;
    ph.value = "";
    sel.appendChild(ph);
    for (const o of options) {
      const opt = this.el("option", undefined, o.label) as HTMLOptionElement;
      opt.value = o.value;
      if (o.value === selected) opt.selected = true;
      sel.appendChild(opt);
    }
    if (!selected) sel.classList.add("empty");
    sel.addEventListener("change", () => sel.classList.toggle("empty", !sel.value));
    return sel;
  }

  private buildToggle(r: MappingRow, t: Record<string, string>): HTMLElement {
    const wrap = this.el("label", "edo-toggle");
    const sw = this.el("span", "edo-switch");
    const cb = this.el("input") as HTMLInputElement;
    cb.type = "checkbox";
    cb.checked = r.readOnly;
    const label = this.el("span", "edo-toggle-label", r.readOnly ? t.locked : t.editable);
    cb.onchange = () => { r.readOnly = cb.checked; r.dirty = true; label.textContent = cb.checked ? t.locked : t.editable; };
    sw.appendChild(cb);
    sw.appendChild(this.el("span", "edo-slider"));
    wrap.appendChild(sw);
    wrap.appendChild(label);
    return wrap;
  }

  private buildSide(): HTMLElement {
    const t = I18N[this.lang];
    const side = this.el("aside", "edo-side");

    const ctx = this.el("section", "edo-card edo-psec");
    const ct = this.el("div", "edo-ptitle");
    ct.appendChild(this.el("span", "edo-ico", "▦"));
    ct.appendChild(this.el("span", undefined, t.recordContext));
    ctx.appendChild(ct);
    const box = this.el("div", "edo-ctx");
    if (this.templateName) box.appendChild(this.kv(t.template, this.templateName, false));
    box.appendChild(this.kv(t.sourceTable, TEMPLATE_ENTITY, true));
    box.appendChild(this.kv(t.mappingTable, ENTITY, true));
    box.appendChild(this.kv(t.solution, "alex_d365_easydo", true));
    box.appendChild(this.kv(t.prefix, "alex_", true));
    ctx.appendChild(box);
    side.appendChild(ctx);

    const sum = this.el("section", "edo-card edo-psec");
    const st = this.el("div", "edo-ptitle");
    st.appendChild(this.el("span", "edo-ico", "◴"));
    st.appendChild(this.el("span", undefined, t.summary));
    sum.appendChild(st);
    const stats = this.el("div", "edo-stats");
    const total = this.rows.length;
    const mapped = this.rows.filter(r => r.table && r.column).length;
    const locked = this.rows.filter(r => r.readOnly).length;
    const bound = this.rows.filter(r => /\./.test(r.external)).length;
    stats.appendChild(this.stat(String(total), t.total));
    stats.appendChild(this.stat(String(mapped), t.mappedN, "accent"));
    stats.appendChild(this.stat(String(locked), t.lockedN, "lock"));
    stats.appendChild(this.stat(String(bound), t.bindings));
    sum.appendChild(stats);
    side.appendChild(sum);

    const note = this.el("section", "edo-card edo-psec");
    const nt = this.el("div", "edo-ptitle");
    nt.appendChild(this.el("span", "edo-ico", "♦"));
    nt.appendChild(this.el("span", undefined, t.saveBehavior));
    note.appendChild(nt);
    const n = this.el("div", "edo-note");
    n.appendChild(this.el("span", "edo-ico", "ℹ"));
    n.appendChild(this.el("span", undefined, t.saveNote));
    note.appendChild(n);
    if (this.demo) {
      const tag = this.el("div", "edo-demo-tag");
      tag.style.marginTop = "12px";
      tag.appendChild(this.el("span", undefined, "● " + t.demoTitle));
      note.appendChild(tag);
    }
    side.appendChild(note);

    return side;
  }

  private kv(k: string, v: string, mono: boolean): HTMLElement {
    const line = this.el("div", "edo-rline");
    line.appendChild(this.el("span", "k", k));
    line.appendChild(this.el(mono ? "code" : "span", undefined, v));
    return line;
  }

  private stat(n: string, label: string, mod = ""): HTMLElement {
    const s = this.el("div", `edo-stat ${mod}`.trim());
    s.appendChild(this.el("div", "n", n));
    s.appendChild(this.el("div", "l", label));
    return s;
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
