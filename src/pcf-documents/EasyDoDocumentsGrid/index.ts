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

/* ---- envelope per-document status (alex_envelopeitemstatus) ------- */
const ITEM_SIGNED = 626220002;
/* request statuses the on-demand check flow acts on (open / in-flight) */
const OPEN_STATUSES = [626210002, 626210003, 626210004, 626210005];

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

/* ---- inline icons ------------------------------------------------- */
const REFRESH_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>';
const CHECK_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>';
const ENV_SVG = '<svg class="edg-env-glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 5L2 7"/></svg>';

/* ---- i18n --------------------------------------------------------- */
const I18N: Record<Lang, Record<string, string>> = {
  en: {
    dir: "ltr",
    title: "easydo Documents",
    subtitle: "Signature requests linked to this record",
    count1: "document", countN: "documents",
    colSent: "Sent on", colChecked: "Last checked", colCompleted: "Completed",
    empty: "No documents yet", emptyDesc: "Signature requests sent from this record will appear here.",
    emptyChip: "No documents in this view",
    refresh: "Refresh", check: "Check status", checking: "Checking\u2026",
    checkDone: "Status check requested", checkNone: "Nothing to check",
    envelope: "Envelope", signedOf: "{0} of {1} signed",
    noDate: "\u2014", noTemplate: "\u2014"
  },
  he: {
    dir: "rtl",
    title: "מסמכי easydo",
    subtitle: "בקשות לחתימה המקושרות לרשומה זו",
    count1: "מסמך", countN: "מסמכים",
    colSent: "תאריך שליחה", colChecked: "נבדק לאחרונה", colCompleted: "תאריך השלמה",
    empty: "אין עדיין מסמכים", emptyDesc: "בקשות לחתימה שיישלחו מרשומה זו יופיעו כאן.",
    emptyChip: "אין מסמכים בתצוגה זו",
    refresh: "רענון", check: "בדוק מצב", checking: "בודק\u2026",
    checkDone: "בקשת בדיקת מצב נשלחה", checkNone: "אין מה לבדוק",
    envelope: "מעטפה", signedOf: "{0} מתוך {1} נחתמו",
    noDate: "\u2014", noTemplate: "\u2014"
  }
};

export class EasyDoDocumentsGrid implements ComponentFramework.StandardControl<IInputs, IOutputs> {
  private root!: HTMLDivElement;
  private context!: ComponentFramework.Context<IInputs>;
  private lang: Lang = "he";
  private activeChip = "all";
  private pageSizeSet = false;
  /* envelope member counts per request id: { total, signed } */
  private envCounts: Record<string, { total: number; signed: number }> = {};
  private envLoadedKey = "";
  private envLoading = false;
  private busy = false;

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

    // Fetch envelope member counts once per record set, then render.
    const ids = ds.sortedRecordIds || [];
    const key = ids.join(",");
    if (key !== this.envLoadedKey && !this.envLoading) {
      this.envLoading = true;
      this.fetchEnvCounts(ids).then(() => {
        this.envLoading = false;
        this.envLoadedKey = key;
        this.render(ds);
        return;
      }).catch(() => {
        this.envLoading = false;
        this.envLoadedKey = key;
        this.render(ds);
      });
    }

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

    // filter bar: chips + elegant divider + action buttons
    html += '<div class="edg-filterbar">';
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
    html += '<div class="edg-actions">';
    html += '<button type="button" class="edg-btn" data-act="refresh" title="' + this.esc(this.t("refresh")) + '">' +
      REFRESH_SVG + '<span>' + this.esc(this.t("refresh")) + '</span></button>';
    html += '<button type="button" class="edg-btn edg-btn-primary" data-act="check" title="' + this.esc(this.t("check")) + '">' +
      CHECK_SVG + '<span class="edg-btn-label">' + this.esc(this.t("check")) + '</span>' +
      '<span class="edg-btn-spin"></span></button>';
    html += '</div>';
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
    const env = this.envCounts[id.replace(/[{}]/g, "")];

    let h = '<div class="edg-row edg-row-click' + (env ? ' is-envelope' : '') +
      '" data-id="' + this.esc(id) + '" tabindex="0" role="button">';
    h += '<div class="edg-row-main">';
    h += '<div class="edg-row-name">' + (env ? ENV_SVG : '') + '<span>' + this.esc(name) + '</span></div>';
    h += '<div class="edg-row-tpl">' + this.esc(template) + '</div>';
    if (env) h += this.envProgress(env);
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

  private envProgress(env: { total: number; signed: number }): string {
    const pct = env.total ? Math.round((env.signed / env.total) * 100) : 0;
    const lbl = this.t("signedOf").replace("{0}", String(env.signed)).replace("{1}", String(env.total));
    const done = env.total > 0 && env.signed >= env.total;
    return '<div class="edg-env' + (done ? ' is-done' : '') + '">' +
      '<div class="edg-env-track"><span class="edg-env-fill" style="width:' + pct + '%"></span></div>' +
      '<span class="edg-env-lbl">' + this.esc(lbl) + '</span></div>';
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
    const refreshBtn = this.root.querySelector<HTMLElement>('[data-act="refresh"]');
    if (refreshBtn) refreshBtn.addEventListener("click", () => this.doRefresh(ds));
    const checkBtn = this.root.querySelector<HTMLElement>('[data-act="check"]');
    if (checkBtn) checkBtn.addEventListener("click", () => this.doCheckStatus(ds, checkBtn));

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

  /* ---- envelope counts + toolbar actions --------------------------- */
  private async fetchEnvCounts(ids: string[]): Promise<void> {
    this.envCounts = {};
    if (!ids.length) return;
    const clean = ids.map((i) => i.replace(/[{}]/g, "")).filter((i) => !!i);
    const chunk = 20;
    for (let i = 0; i < clean.length; i += chunk) {
      const part = clean.slice(i, i + chunk);
      const orClause = part.map((id) => "_alex_signaturerequestid_value eq " + id).join(" or ");
      const q = "?$select=alex_itemstatus,_alex_signaturerequestid_value&$filter=(" + orClause + ")";
      try {
        const res = await this.context.webAPI.retrieveMultipleRecords("alex_signaturerequestitem", q);
        for (const rec of res.entities) {
          const reqId = String(rec["_alex_signaturerequestid_value"] || "").replace(/[{}]/g, "");
          if (!reqId) continue;
          const st = rec["alex_itemstatus"];
          const cur = this.envCounts[reqId] || { total: 0, signed: 0 };
          cur.total++;
          if (typeof st === "number" && st === ITEM_SIGNED) cur.signed++;
          this.envCounts[reqId] = cur;
        }
      } catch { /* leave counts empty for this chunk */ }
    }
  }

  private doRefresh(ds: DataSet): void {
    this.envLoadedKey = "";              // force a recount after the reload
    if (ds.refresh) ds.refresh();
  }

  private doCheckStatus(ds: DataSet, btn: HTMLElement): void {
    if (this.busy) return;
    const ids = ds.sortedRecordIds || [];
    const targets: string[] = [];
    for (const id of ids) {
      const sv = this.statusVal(ds.records[id]);
      if (sv != null && OPEN_STATUSES.indexOf(sv) >= 0) targets.push(id.replace(/[{}]/g, ""));
    }
    if (!targets.length) { this.toast(this.t("checkNone")); return; }
    this.busy = true;
    btn.classList.add("is-busy");
    const stamp = new Date().toISOString();
    const jobs = targets.map((id) =>
      this.context.webAPI
        .updateRecord("alex_signaturerequest", id, { alex_statuscheckrequestedon: stamp })
        .then(() => undefined, () => undefined)
    );
    Promise.all(jobs).then(() => {
      this.toast(this.t("checkDone"));
      window.setTimeout(() => {
        this.busy = false;
        btn.classList.remove("is-busy");
        this.envLoadedKey = "";
        if (ds.refresh) ds.refresh();
      }, 5000);
      return;
    }).catch(() => undefined);
  }

  private toast(msg: string): void {
    let el = this.root.querySelector<HTMLElement>(".edg-toast");
    if (!el) {
      el = document.createElement("div");
      el.className = "edg-toast";
      this.root.appendChild(el);
    }
    el.textContent = msg;
    el.classList.add("is-show");
    window.setTimeout(() => { if (el) el.classList.remove("is-show"); }, 2600);
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
