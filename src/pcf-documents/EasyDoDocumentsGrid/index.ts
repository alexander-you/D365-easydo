import { IInputs, IOutputs } from "./generated/ManifestTypes";

/* =====================================================================
   easydo  -  Documents grid  (PCF dataset control / sub-grid)

   Binds to a sub-grid of alex_signaturerequest (signature requests) on any
   host form. The relationship sub-grid already filters to the related
   records, so the control just renders them as elegant, chip-filtered
   cards: name, template, status badge, sent / last-checked / completed
   dates. No command buttons - records are added through the form sub-grid
   itself, the control is read-only and just navigates on click.
   ===================================================================== */

type Lang = "en" | "he";
type DataSet = ComponentFramework.PropertyTypes.DataSet;
type EntityRecord = ComponentFramework.PropertyHelper.DataSetApi.EntityRecord;

/* ---- field logical names ------------------------------------------ */
const F = {
  name: "alex_name",
  status: "alex_status",
  template: "alex_templateid",
  sentOn: "alex_senton",
  lastCheck: "alex_laststatuscheckon",
  completed: "alex_completedon"
};

/* ---- status metadata (alex_signaturestatus) -> badge css class ---- */
const ST: Record<number, string> = {
  626210000: "muted", // Draft
  626210001: "info",  // Ready to Send
  626210002: "info",  // Sent
  626210003: "info",  // Delivered
  626210004: "info",  // Viewed
  626210005: "info",  // In Progress
  626210006: "ok",    // Completed / Signed
  626210007: "bad",   // Declined
  626210008: "bad",   // Failed
  626210009: "muted", // Cancelled
  626210010: "warn",  // Expired
  626210011: "warn"   // Pending Retry
};

/* ---- chip definitions --------------------------------------------- */
interface ChipDef { key: string; he: string; en: string; vals: number[] | null; tone: string; }
const CHIPS: ChipDef[] = [
  { key: "all", he: "כל המסמכים", en: "All documents", vals: null, tone: "brand" },
  { key: "pending", he: "ממתין לחתימה", en: "Pending", vals: [626210000, 626210001, 626210002, 626210003, 626210004, 626210005, 626210011], tone: "info" },
  { key: "signed", he: "נחתם", en: "Signed", vals: [626210006], tone: "ok" },
  { key: "rejected", he: "נדחה", en: "Declined", vals: [626210007], tone: "bad" },
  { key: "expired", he: "פג תוקף", en: "Expired", vals: [626210010], tone: "warn" },
  { key: "failed", he: "נכשל", en: "Failed", vals: [626210008], tone: "bad" }
];

/* ---- i18n --------------------------------------------------------- */
const I18N: Record<Lang, Record<string, string>> = {
  en: {
    dir: "ltr",
    title: "easydo Documents",
    subtitle: "Signature requests linked to this record",
    count1: "document", countN: "documents",
    colSent: "Sent on", colChecked: "Last checked", colCompleted: "Completed",
    empty: "No documents yet", emptyDesc: "Signature requests sent from this record will appear here.",
    emptyChip: "No documents in this view", noDate: "—", noTemplate: "—"
  },
  he: {
    dir: "rtl",
    title: "מסמכי easydo",
    subtitle: "בקשות לחתימה המקושרות לרשומה זו",
    count1: "מסמך", countN: "מסמכים",
    colSent: "תאריך שליחה", colChecked: "נבדק לאחרונה", colCompleted: "תאריך השלמה",
    empty: "אין עדיין מסמכים", emptyDesc: "בקשות לחתימה שיישלחו מרשומה זו יופיעו כאן.",
    emptyChip: "אין מסמכים בתצוגה זו", noDate: "—", noTemplate: "—"
  }
};

export class EasyDoDocumentsGrid implements ComponentFramework.StandardControl<IInputs, IOutputs> {
  private root!: HTMLDivElement;
  private context!: ComponentFramework.Context<IInputs>;
  private lang: Lang = "he";
  private activeChip = "all";
  private pageSizeSet = false;

  public init(
    context: ComponentFramework.Context<IInputs>,
    _notifyOutputChanged: () => void,
    _state: ComponentFramework.Dictionary,
    container: HTMLDivElement
  ): void {
    this.context = context;
    context.mode.trackContainerResize(true);
    this.root = document.createElement("div");
    this.root.className = "edg-root";
    container.appendChild(this.root);
  }

  public updateView(context: ComponentFramework.Context<IInputs>): void {
    this.context = context;
    this.lang = this.resolveLang(context);
    const ds = context.parameters.records;

    // Pull a generous page size once so all related requests render together.
    if (!this.pageSizeSet && ds.paging && typeof ds.paging.setPageSize === "function") {
      this.pageSizeSet = true;
      ds.paging.setPageSize(250);
    }

    if (ds.loading) { this.renderLoading(); return; }

    // Load remaining pages before rendering (related sets are small).
    if (ds.paging && ds.paging.hasNextPage) { ds.paging.loadNextPage(); return; }

    this.render(ds);
  }

  public getOutputs(): IOutputs { return {}; }
  public destroy(): void { /* no-op */ }

  /* ---- language ---------------------------------------------------- */
  private resolveLang(context: ComponentFramework.Context<IInputs>): Lang {
    const raw = context.parameters.language && context.parameters.language.raw;
    if (raw === "he" || raw === "en") return raw;
    const id = context.userSettings ? context.userSettings.languageId : 1033;
    return id === 1037 ? "he" : "en";
  }

  private t(key: string): string { return I18N[this.lang][key]; }

  /* ---- helpers ----------------------------------------------------- */
  private categoryOf(statusVal: number | null): string {
    if (statusVal == null) return "pending";
    for (const c of CHIPS) {
      if (c.vals && c.vals.indexOf(statusVal) >= 0) return c.key;
    }
    return "other";
  }

  private statusVal(rec: EntityRecord): number | null {
    const v = rec.getValue(F.status) as unknown;
    if (v == null || v === "") return null;
    const n = typeof v === "number" ? v : parseInt(String(v), 10);
    return isNaN(n) ? null : n;
  }

  private fmt(rec: EntityRecord, col: string): string {
    const f = rec.getFormattedValue(col);
    return f ? f : "";
  }

  // Raw epoch (ms) for a datetime column, 0 when missing - used for sorting.
  private dateVal(rec: EntityRecord, col: string): number {
    const v = rec.getValue(col) as unknown;
    if (v == null || v === "") return 0;
    if (typeof v === "number") return v;
    if (v instanceof Date) return v.getTime();
    const t = new Date(String(v)).getTime();
    return isNaN(t) ? 0 : t;
  }

  /* ---- render ------------------------------------------------------ */
  private renderLoading(): void {
    this.root.setAttribute("dir", this.t("dir"));
    this.root.innerHTML =
      '<div class="edg-shell"><div class="edg-loading">' +
      '<span class="edg-spin"></span></div></div>';
  }

  private render(ds: DataSet): void {
    const ids = ds.sortedRecordIds || [];
    const lang = this.lang;
    this.root.setAttribute("dir", this.t("dir"));
    this.root.setAttribute("data-lang", lang);

    // counts per chip
    const counts: Record<string, number> = {};
    for (const c of CHIPS) counts[c.key] = 0;
    for (const id of ids) {
      const cat = this.categoryOf(this.statusVal(ds.records[id]));
      counts.all++;
      if (counts[cat] != null) counts[cat]++;
    }

    // filtered ids
    const shown: string[] = [];
    for (const id of ids) {
      if (this.activeChip === "all") { shown.push(id); continue; }
      if (this.categoryOf(this.statusVal(ds.records[id])) === this.activeChip) shown.push(id);
    }

    // Newest send first; ties broken by most recently checked. Records with no
    // send date (e.g. failed/draft) fall to the bottom.
    shown.sort((a, b) => {
      const s = this.dateVal(ds.records[b], F.sentOn) - this.dateVal(ds.records[a], F.sentOn);
      if (s !== 0) return s;
      return this.dateVal(ds.records[b], F.lastCheck) - this.dateVal(ds.records[a], F.lastCheck);
    });

    let html = '<div class="edg-shell">';

    // header
    html += '<div class="edg-head">';
    html += '<div class="edg-head-main">';
    html += '<div class="edg-title">' + this.esc(this.t("title")) + '</div>';
    html += '<div class="edg-sub">' + this.esc(this.t("subtitle")) + '</div>';
    html += '</div>';
    html += '<div class="edg-total">' + counts.all + ' ' +
      this.esc(counts.all === 1 ? this.t("count1") : this.t("countN")) + '</div>';
    html += '</div>';

    // chips
    html += '<div class="edg-chips">';
    for (const c of CHIPS) {
      const active = this.activeChip === c.key ? " is-active" : "";
      html += '<button type="button" class="edg-chip t-' + c.tone + active + '" data-chip="' + c.key + '">' +
        '<span class="edg-chip-dot"></span>' +
        '<span class="edg-chip-label">' + this.esc(lang === "he" ? c.he : c.en) + '</span>' +
        '<span class="edg-chip-count">' + (counts[c.key] || 0) + '</span>' +
        '</button>';
    }
    html += '</div>';

    // body
    if (ids.length === 0) {
      html += this.emptyState(this.t("empty"), this.t("emptyDesc"));
    } else if (shown.length === 0) {
      html += this.emptyState(this.t("emptyChip"), "");
    } else {
      html += '<div class="edg-list">';
      for (const id of shown) html += this.rowHtml(ds.records[id]);
      html += '</div>';
    }

    html += '</div>';
    this.root.innerHTML = html;
    this.wire(ds);
  }

  private rowHtml(rec: EntityRecord): string {
    const sv = this.statusVal(rec);
    const cls = sv != null && ST[sv] ? ST[sv] : "muted";
    const name = this.fmt(rec, F.name) || rec.getNamedReference().name || "—";
    const template = this.fmt(rec, F.template) || this.t("noTemplate");
    const statusLbl = this.fmt(rec, F.status) || "—";
    const sent = this.fmt(rec, F.sentOn) || this.t("noDate");
    const checked = this.fmt(rec, F.lastCheck) || this.t("noDate");
    const completed = this.fmt(rec, F.completed) || this.t("noDate");
    const id = rec.getRecordId();

    let h = '<div class="edg-row edg-row-click" data-id="' + this.esc(id) + '" tabindex="0" role="button">';
    h += '<div class="edg-row-main">';
    h += '<div class="edg-row-name">' + this.esc(name) + '</div>';
    h += '<div class="edg-row-tpl">' + this.esc(template) + '</div>';
    h += '</div>';
    h += this.metaCell(this.t("colSent"), sent);
    h += this.metaCell(this.t("colChecked"), checked);
    h += this.metaCell(this.t("colCompleted"), completed);
    h += '<div class="edg-row-status"><span class="edg-badge ' + cls + '">' +
      this.esc(statusLbl) + '</span></div>';
    h += '<div class="edg-row-chev"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg></div>';
    h += '</div>';
    return h;
  }

  private metaCell(label: string, value: string): string {
    return '<div class="edg-meta-cell"><span class="edg-meta-lbl">' + this.esc(label) +
      '</span><span class="edg-meta-val">' + this.esc(value) + '</span></div>';
  }

  private emptyState(title: string, desc: string): string {
    let h = '<div class="edg-empty"><div class="edg-empty-icon"></div>';
    h += '<div class="edg-empty-title">' + this.esc(title) + '</div>';
    if (desc) h += '<div class="edg-empty-desc">' + this.esc(desc) + '</div>';
    h += '</div>';
    return h;
  }

  /* ---- events ------------------------------------------------------ */
  private wire(ds: DataSet): void {
    const chips = this.root.querySelectorAll<HTMLElement>(".edg-chip");
    chips.forEach((chip) => {
      chip.addEventListener("click", () => {
        const key = chip.getAttribute("data-chip");
        if (key) { this.activeChip = key; this.render(ds); }
      });
    });

    const rows = this.root.querySelectorAll<HTMLElement>(".edg-row-click");
    rows.forEach((row) => {
      row.addEventListener("click", () => {
        const id = row.getAttribute("data-id");
        if (id) this.openViewer(id);
      });
      row.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          const id = row.getAttribute("data-id");
          if (id) this.openViewer(id);
        }
      });
    });
  }

  private openViewer(recordId: string): void {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const xrm = (window as any).Xrm as { App?: { sidePanes?: any } } | undefined;
    if (!xrm?.App?.sidePanes) {
      // Fallback: open record form
      this.context.navigation.openForm({
        entityName: "alex_signaturerequest",
        entityId: recordId
      });
      return;
    }
    const cleanId = recordId.replace(/[{}]/g, "");
    // Single reusable pane: clicking any row reuses the same pane and just re-navigates.
    const paneId = "easydo_doc_viewer";
    const wr = "alex_/html/documentViewer.html?id=" + encodeURIComponent(cleanId);
    const sidePanes = xrm.App.sidePanes;

    // If the pane already exists, just navigate it to the new record and focus it.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const existing: any = sidePanes.getPane ? sidePanes.getPane(paneId) : undefined;
    if (existing) {
      existing.navigate({ pageType: "webresource", webresourceName: wr });
      if (existing.select) existing.select();
      return;
    }

    sidePanes.createPane({
      title: this.t("title"),
      paneId: paneId,
      canClose: true,
      width: 420,
      imageSrc: "WebResources/alex_/icons/docViewer.svg"
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    }).then((pane: any) => {
      pane.navigate({
        pageType: "webresource",
        webresourceName: wr
      });
      return;
    }).catch(() => {
      this.context.navigation.openForm({
        entityName: "alex_signaturerequest",
        entityId: recordId
      });
    });
  }

  private esc(s: string): string {
    if (s == null) return "";
    return String(s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
}
