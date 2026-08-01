import { IInputs, IOutputs } from "./generated/ManifestTypes";

/* =====================================================================
   easydo  -  Signature Template gallery  (PCF dataset control)

   Binds to a view / home-grid of alex_signaturetemplate and replaces the flat
   list with an Apple-style gallery of cards. Each card makes the essentials
   obvious at a glance:
     - Envelope vs single-document template (distinct glyph + tint)
     - Status: Active / Inactive / Removed from easydo ("deleted")
     - Last sync as a friendly relative time (amber when stale)
     - Language, primary table, signer roles, authentication, expiry, members

   The dataset owns which records are shown and their order (so the D365 view
   filter/sort is honored); the control enriches each record over the Web API
   to render the rich card + an in-place details drill-in. Clicking a card
   drills in; the card's button opens the record form.
   ===================================================================== */

type Lang = "en" | "he";
type DataSet = ComponentFramework.PropertyTypes.DataSet;

const TEMPLATE_ENTITY = "alex_signaturetemplate";
const ITEM_ENTITY = "alex_envelopetemplateitem";
const FV = "@OData.Community.Display.V1.FormattedValue";

/* A template that exists in Dataverse but no longer returns from easydo is
   deactivated by the sync with this custom status reason ("removed / deleted"). */
const DELETED_STATUS = 626210000;

type StatusKey = "active" | "inactive" | "deleted";

interface Role { name: string; sequence: number; }

interface TplData {
  id: string;
  name: string;
  isEnvelope: boolean;
  statusKey: StatusKey;
  statusLabel: string;
  syncedMs: number;      // 0 when never synced
  syncedExact: string;   // formatted date/time, "" when never
  language: string;
  primaryTable: string;
  relatedTable: string;
  contactPath: string;
  authMethod: number | null;
  authLabel: string;
  pinLabel: string;
  otpSource: string;
  hasExpiry: boolean;
  expiryDays: number | null;
  allowExpiryOverride: boolean;
  copyLinkLabel: string;
  allowSendFromObject: boolean;
  allowPrefillEdit: boolean;
  recipientLocked: boolean;
  supportsPreview: boolean;
  supportsMulti: boolean;
  roles: Role[];
  externalId: string;
  summary: string;
  memberCount: number | null; // envelopes only
}

/* ---- filter segments ---------------------------------------------- */
interface Seg { key: string; he: string; en: string; }
const SEGS: Seg[] = [
  { key: "all", he: "הכל", en: "All" },
  { key: "documents", he: "מסמכים", en: "Documents" },
  { key: "envelopes", he: "מעטפות", en: "Envelopes" },
  { key: "active", he: "פעילות", en: "Active" },
  { key: "deleted", he: "נמחקו", en: "Removed" }
];

/* ---- inline icons ------------------------------------------------- */
const SVG_DOC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="14" y2="17"/></svg>';
const SVG_ENV = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="7" width="18" height="14" rx="2"/><path d="m3 9 9 6 9-6"/><path d="M7 7V4a1 1 0 0 1 1-1h8a1 1 0 0 1 1 1v3"/></svg>';
const SVG_SYNC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>';
const SVG_SEARCH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>';
const SVG_OPEN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>';
const SVG_X = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';

/* ---- i18n --------------------------------------------------------- */
const I18N: Record<Lang, Record<string, string>> = {
  en: {
    dir: "ltr",
    title: "Signature Templates",
    subtitle: "Every easydo template and envelope, synced into Dynamics",
    kTemplates: "Templates", kEnvelopes: "Envelopes", kDeleted: "Removed", kStale: "Out of sync",
    searchPh: "Search templates…",
    sortView: "View order", sortSynced: "Recently synced", sortName: "Name",
    stActive: "Active", stInactive: "Inactive", stDeleted: "Removed from easydo",
    envelope: "Envelope", document: "Document",
    mRoles: "roles", mRole: "role", mMembers: "documents", mMember: "document",
    mNoAuth: "No auth", mNoTable: "No table", mNoExpiry: "No expiry", mExpiry: "{0}d expiry",
    syncNever: "Never synced", syncNow: "Synced just now",
    syncMin: "{0} min ago", syncHour: "{0} h ago", syncDay: "{0} d ago", syncedOn: "Synced {0}",
    open: "Open", back: "Back", close: "Close",
    empty: "No templates yet", emptyDesc: "Run the easydo template sync and they will appear here.",
    emptySeg: "No templates in this filter",
    dSync: "Sync", dBinding: "Binding & identity", dAuth: "Authentication", dPolicy: "Policy",
    dRoles: "Signer roles", dMembers: "Envelope documents",
    fExternalId: "easydo id", fSynced: "Last synced",
    fPrimaryTable: "Primary table", fContactPath: "Path to contact", fSendFromObject: "Send from record",
    fAuthMethod: "Authentication", fPinMode: "PIN", fOtpSource: "OTP phone source",
    fExpiry: "Document expiry", fExpiryOverride: "Expiry override at send", fCopyLink: "Signing link",
    fPrefillEdit: "Edit data at send", fRecipientLocked: "Recipient locked",
    fPreview: "Preview", fMulti: "Multiple signers",
    yes: "Yes", no: "No", none: "—", days: "{0} days",
    membersLoading: "Loading documents…", noMembers: "No documents in this envelope yet",
    notEnvelope: "Single-document template"
  },
  he: {
    dir: "rtl",
    title: "תבניות חתימה",
    subtitle: "כל תבניות ומעטפות easydo, מסונכרנות לתוך Dynamics",
    kTemplates: "תבניות", kEnvelopes: "מעטפות", kDeleted: "נמחקו", kStale: "לא מסונכרנות",
    searchPh: "חיפוש תבניות…",
    sortView: "סדר התצוגה", sortSynced: "סונכרנו לאחרונה", sortName: "שם",
    stActive: "פעיל", stInactive: "לא פעיל", stDeleted: "הוסר מ‑easydo",
    envelope: "מעטפה", document: "מסמך",
    mRoles: "בעלי תפקידים", mRole: "בעל תפקיד", mMembers: "מסמכים", mMember: "מסמך",
    mNoAuth: "ללא אימות", mNoTable: "ללא טבלה", mNoExpiry: "ללא תוקף", mExpiry: "תוקף {0} ימים",
    syncNever: "לא סונכרן מעולם", syncNow: "סונכרן ממש עכשיו",
    syncMin: "לפני {0} דק׳", syncHour: "לפני {0} שע׳", syncDay: "לפני {0} ימים", syncedOn: "סונכרן {0}",
    open: "פתיחה", back: "חזרה", close: "סגירה",
    empty: "אין עדיין תבניות", emptyDesc: "הריצו את סנכרון תבניות easydo והן יופיעו כאן.",
    emptySeg: "אין תבניות בסינון זה",
    dSync: "סנכרון", dBinding: "קישור וזיהוי", dAuth: "אימות", dPolicy: "מדיניות",
    dRoles: "בעלי תפקידים", dMembers: "מסמכי המעטפה",
    fExternalId: "מזהה easydo", fSynced: "סונכרן לאחרונה",
    fPrimaryTable: "טבלה ראשית", fContactPath: "נתיב לאיש קשר", fSendFromObject: "שליחה מתוך רשומה",
    fAuthMethod: "שיטת אימות", fPinMode: "PIN", fOtpSource: "מקור טלפון OTP",
    fExpiry: "תוקף מסמך", fExpiryOverride: "שינוי תוקף בעת שליחה", fCopyLink: "קישור חתימה",
    fPrefillEdit: "עריכת נתונים בעת שליחה", fRecipientLocked: "נעילת נמען",
    fPreview: "תצוגה מקדימה", fMulti: "מספר חותמים",
    yes: "כן", no: "לא", none: "—", days: "{0} ימים",
    membersLoading: "טוען מסמכים…", noMembers: "למעטפה זו אין עדיין מסמכים",
    notEnvelope: "תבנית מסמך בודד"
  }
};

export class EasyDoTemplateGallery implements ComponentFramework.StandardControl<IInputs, IOutputs> {
  private root!: HTMLDivElement;
  private context!: ComponentFramework.Context<IInputs>;
  private lang: Lang = "he";
  private activeSeg = "all";
  private sortMode = "view";      // view | synced | name
  private query = "";
  private pageSizeSet = false;

  private data: Record<string, TplData> = {};
  private orderedIds: string[] = [];
  private loadedKey = "";
  private loading = false;

  private drillId: string | null = null;
  private members: Record<string, { name: string; sequence: number }[]> = {};
  private membersLoading: Record<string, boolean> = {};
  private tableLabels: Record<string, string> = {};

  public init(
    context: ComponentFramework.Context<IInputs>,
    _notifyOutputChanged: () => void,
    _state: ComponentFramework.Dictionary,
    container: HTMLDivElement
  ): void {
    this.context = context;
    context.mode.trackContainerResize(true);
    this.root = document.createElement("div");
    this.root.className = "tg-root";
    container.appendChild(this.root);
  }

  public updateView(context: ComponentFramework.Context<IInputs>): void {
    this.context = context;
    this.lang = this.resolveLang(context);
    const ds = context.parameters.records;

    if (!this.pageSizeSet && ds.paging && typeof ds.paging.setPageSize === "function") {
      this.pageSizeSet = true;
      ds.paging.setPageSize(250);
    }

    if (ds.loading) { this.renderLoading(); return; }
    if (ds.paging && ds.paging.hasNextPage) { ds.paging.loadNextPage(); return; }

    const ids = (ds.sortedRecordIds || []).map((i) => i.replace(/[{}]/g, "").toLowerCase());
    const key = ids.join(",");
    if (key !== this.loadedKey && !this.loading) {
      this.loading = true;
      this.renderLoading();
      this.enrich(ids).then(() => {
        this.loading = false;
        this.loadedKey = key;
        this.orderedIds = ids;
        this.render();
        return;
      }).catch(() => {
        this.loading = false;
        this.loadedKey = key;
        this.orderedIds = ids;
        this.render();
      });
      return;
    }

    this.orderedIds = ids;
    this.render();
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
  private fmt(key: string, v: string | number): string { return this.t(key).replace("{0}", String(v)); }

  /* ---- data enrichment -------------------------------------------- */
  private async enrich(ids: string[]): Promise<void> {
    this.data = {};
    if (!ids.length) return;

    const select = [
      "alex_signaturetemplateid", "alex_name", "alex_isenvelope", "statecode", "statuscode",
      "alex_lastsyncedon", "alex_language", "alex_primarytable", "alex_relateddynamicstable",
      "alex_contactpath", "alex_authmethod", "alex_pinmode", "alex_otpphonesource",
      "alex_hasexpiry", "alex_expirydays", "alex_allowexpiryoverride", "alex_copylinkmode",
      "alex_allowsendfromobject", "alex_allowprefilledit", "alex_recipientlocked",
      "alex_supportspreview", "alex_supportsmultiplesigners", "alex_rolesjson",
      "alex_externaltemplateid", "alex_templatesummary"
    ].join(",");

    const chunk = 20;
    const envIds: string[] = [];
    for (let i = 0; i < ids.length; i += chunk) {
      const part = ids.slice(i, i + chunk);
      const orClause = part.map((id) => "alex_signaturetemplateid eq " + id).join(" or ");
      const q = "?$select=" + select + "&$filter=(" + orClause + ")";
      try {
        const res = await this.context.webAPI.retrieveMultipleRecords(TEMPLATE_ENTITY, q);
        for (const rec of res.entities) {
          const d = this.toTpl(rec);
          this.data[d.id] = d;
          if (d.isEnvelope) envIds.push(d.id);
        }
      } catch { /* leave those records un-enriched */ }
    }

    if (envIds.length) await this.fetchMemberCounts(envIds);

    const tables: string[] = [];
    for (const id in this.data) {
      const p = this.data[id].primaryTable;
      if (p && tables.indexOf(p) < 0) tables.push(p);
    }
    if (tables.length) await this.fetchTableLabels(tables);
  }

  private toTpl(rec: ComponentFramework.WebApi.Entity): TplData {
    const id = String(rec["alex_signaturetemplateid"] || "").replace(/[{}]/g, "").toLowerCase();
    const state = typeof rec["statecode"] === "number" ? (rec["statecode"] as number) : 0;
    const status = typeof rec["statuscode"] === "number" ? (rec["statuscode"] as number) : 0;
    let statusKey: StatusKey = "active";
    let statusLabel = this.t("stActive");
    if (status === DELETED_STATUS) { statusKey = "deleted"; statusLabel = this.t("stDeleted"); }
    else if (state !== 0) { statusKey = "inactive"; statusLabel = this.t("stInactive"); }

    const syncedRaw = rec["alex_lastsyncedon"];
    const syncedMs = syncedRaw ? new Date(String(syncedRaw)).getTime() : 0;

    let roles: Role[] = [];
    const rolesRaw = rec["alex_rolesjson"];
    if (rolesRaw) {
      try {
        const arr = JSON.parse(String(rolesRaw)) as { name?: string; sequence?: number }[];
        if (Array.isArray(arr)) {
          roles = arr
            .map((r) => ({ name: (r && r.name) || "", sequence: (r && r.sequence) || 0 }))
            .filter((r) => !!r.name)
            .sort((a, b) => a.sequence - b.sequence);
        }
      } catch { /* ignore malformed json */ }
    }

    return {
      id,
      name: (rec["alex_name"] as string) || "—",
      isEnvelope: rec["alex_isenvelope"] === true,
      statusKey, statusLabel,
      syncedMs,
      syncedExact: (rec["alex_lastsyncedon" + FV] as string) || "",
      language: (rec["alex_language" + FV] as string) || "",
      primaryTable: (rec["alex_primarytable"] as string) || "",
      relatedTable: (rec["alex_relateddynamicstable"] as string) || "",
      contactPath: (rec["alex_contactpath"] as string) || "",
      authMethod: typeof rec["alex_authmethod"] === "number" ? (rec["alex_authmethod"] as number) : null,
      authLabel: (rec["alex_authmethod" + FV] as string) || "",
      pinLabel: (rec["alex_pinmode" + FV] as string) || "",
      otpSource: (rec["alex_otpphonesource"] as string) || "",
      hasExpiry: rec["alex_hasexpiry"] === true,
      expiryDays: typeof rec["alex_expirydays"] === "number" ? (rec["alex_expirydays"] as number) : null,
      allowExpiryOverride: rec["alex_allowexpiryoverride"] === true,
      copyLinkLabel: (rec["alex_copylinkmode" + FV] as string) || "",
      allowSendFromObject: rec["alex_allowsendfromobject"] === true,
      allowPrefillEdit: rec["alex_allowprefilledit"] === true,
      recipientLocked: rec["alex_recipientlocked"] === true,
      supportsPreview: rec["alex_supportspreview"] === true,
      supportsMulti: rec["alex_supportsmultiplesigners"] === true,
      roles,
      externalId: (rec["alex_externaltemplateid"] as string) || "",
      summary: (rec["alex_templatesummary"] as string) || "",
      memberCount: null
    };
  }

  private async fetchMemberCounts(envIds: string[]): Promise<void> {
    const chunk = 20;
    for (let i = 0; i < envIds.length; i += chunk) {
      const part = envIds.slice(i, i + chunk);
      const orClause = part.map((id) => "_alex_envelopeid_value eq " + id).join(" or ");
      const q = "?$select=_alex_envelopeid_value&$filter=(" + orClause + ")";
      try {
        const res = await this.context.webAPI.retrieveMultipleRecords(ITEM_ENTITY, q);
        for (const id of part) if (this.data[id]) this.data[id].memberCount = 0;
        for (const rec of res.entities) {
          const eid = String(rec["_alex_envelopeid_value"] || "").replace(/[{}]/g, "").toLowerCase();
          if (this.data[eid]) this.data[eid].memberCount = (this.data[eid].memberCount || 0) + 1;
        }
      } catch { /* leave counts null */ }
    }
  }

  private async fetchMembers(envId: string): Promise<void> {
    this.membersLoading[envId] = true;
    const q = "?$select=alex_name,alex_sequence&$filter=_alex_envelopeid_value eq " + envId + "&$orderby=alex_sequence";
    try {
      const res = await this.context.webAPI.retrieveMultipleRecords(ITEM_ENTITY, q);
      this.members[envId] = res.entities.map((e) => ({
        name: (e["alex_name"] as string) || "—",
        sequence: (e["alex_sequence"] as number) || 0
      }));
    } catch {
      this.members[envId] = [];
    }
    this.membersLoading[envId] = false;
  }

  /* ---- table display names (metadata) ----------------------------- */
  private async fetchTableLabels(logicals: string[]): Promise<void> {
    const base = this.getClientUrl();
    if (!base) return;
    for (const l of logicals) {
      if (this.tableLabels[l] !== undefined) continue;
      try {
        const res = await fetch(
          base + "/api/data/v9.2/EntityDefinitions(LogicalName='" + encodeURIComponent(l) + "')?$select=DisplayName",
          { headers: { "Accept": "application/json", "OData-MaxVersion": "4.0", "OData-Version": "4.0" } }
        );
        if (res.ok) {
          const j = await res.json() as { DisplayName?: { UserLocalizedLabel?: { Label?: string } } };
          const label = j && j.DisplayName && j.DisplayName.UserLocalizedLabel && j.DisplayName.UserLocalizedLabel.Label;
          this.tableLabels[l] = label || l;
        } else {
          this.tableLabels[l] = l;
        }
      } catch {
        this.tableLabels[l] = l;
      }
    }
  }
  private getClientUrl(): string {
    const x = window as unknown as { Xrm?: { Utility?: { getGlobalContext?: () => { getClientUrl?: () => string } } } };
    try { const u = x.Xrm?.Utility?.getGlobalContext?.().getClientUrl?.(); if (u) return u; } catch { /* ignore */ }
    return "";
  }
  private tableLabel(logical: string): string {
    if (!logical) return "";
    return this.tableLabels[logical] || logical;
  }

  /* ---- relative sync time ----------------------------------------- */
  private relSync(d: TplData): string {
    if (!d.syncedMs) return this.t("syncNever");
    const diff = Date.now() - d.syncedMs;
    const min = Math.floor(diff / 60000);
    if (min < 1) return this.t("syncNow");
    if (min < 60) return this.fmt("syncMin", min);
    const hr = Math.floor(min / 60);
    if (hr < 24) return this.fmt("syncHour", hr);
    const day = Math.floor(hr / 24);
    return this.fmt("syncDay", day);
  }

  /* ---- filtering / sorting ---------------------------------------- */
  private matchSeg(d: TplData): boolean {
    switch (this.activeSeg) {
      case "documents": return !d.isEnvelope;
      case "envelopes": return d.isEnvelope;
      case "active": return d.statusKey === "active";
      case "deleted": return d.statusKey === "deleted";
      default: return true;
    }
  }
  private matchQuery(d: TplData): boolean {
    const q = this.query.trim().toLowerCase();
    if (!q) return true;
    return (d.name + " " + d.externalId + " " + d.primaryTable + " " + d.relatedTable).toLowerCase().indexOf(q) >= 0;
  }
  private visibleIds(): string[] {
    let ids = this.orderedIds.filter((id) => {
      const d = this.data[id];
      return d && this.matchSeg(d) && this.matchQuery(d);
    });
    if (this.sortMode === "name") {
      ids = ids.slice().sort((a, b) => this.data[a].name.localeCompare(this.data[b].name, this.lang === "he" ? "he" : "en"));
    } else if (this.sortMode === "synced") {
      ids = ids.slice().sort((a, b) => this.data[b].syncedMs - this.data[a].syncedMs);
    }
    return ids;
  }

  /* ---- render ------------------------------------------------------ */
  private renderLoading(): void {
    this.root.setAttribute("dir", this.t("dir"));
    this.root.innerHTML = '<div class="tg-shell"><div class="tg-loading"><span class="tg-spin"></span></div></div>';
    this.applyViewport();
  }

  // The model-driven grid hands the control a fixed-height region. Constrain the
  // root to that height and scroll internally so tall content (the drill-in) is
  // never clipped. When the host leaves height unmanaged (allocatedHeight <= 0),
  // fall back to natural flow and let the page scroll.
  private applyViewport(): void {
    const h = this.context && this.context.mode ? this.context.mode.allocatedHeight : -1;
    if (typeof h === "number" && h > 0) {
      this.root.style.height = h + "px";
      this.root.style.overflowY = "auto";
      this.root.style.setProperty("--tg-vh", (h - 12) + "px");
    } else {
      this.root.style.height = "";
      this.root.style.overflowY = "";
      this.root.style.setProperty("--tg-vh", "80vh");
    }
  }

  private render(): void {
    this.root.setAttribute("dir", this.t("dir"));
    this.root.setAttribute("data-lang", this.lang);

    const all = this.orderedIds.map((id) => this.data[id]).filter(Boolean) as TplData[];
    const kTemplates = all.length;
    const kEnvelopes = all.filter((d) => d.isEnvelope).length;
    const kDeleted = all.filter((d) => d.statusKey === "deleted").length;

    const segCounts: Record<string, number> = { all: 0, documents: 0, envelopes: 0, active: 0, deleted: 0 };
    for (const d of all) {
      segCounts.all++;
      if (d.isEnvelope) segCounts.envelopes++; else segCounts.documents++;
      if (d.statusKey === "active") segCounts.active++;
      if (d.statusKey === "deleted") segCounts.deleted++;
    }

    const shown = this.visibleIds();

    let html = '<div class="tg-shell">';

    // hero
    html += '<div class="tg-hero">';
    html += '<div class="tg-hero-main">';
    html += '<div class="tg-title">' + this.esc(this.t("title")) + '</div>';
    html += '<div class="tg-sub">' + this.esc(this.t("subtitle")) + '</div>';
    html += '</div>';
    html += '<div class="tg-kpis">';
    html += this.kpi(kTemplates, this.t("kTemplates"), "brand");
    html += this.kpi(kEnvelopes, this.t("kEnvelopes"), "info");
    html += this.kpi(kDeleted, this.t("kDeleted"), "bad");
    html += '</div>';
    html += '</div>';

    // toolbar: segments + search + sort
    html += '<div class="tg-toolbar">';
    html += '<div class="tg-segs">';
    for (const s of SEGS) {
      const active = this.activeSeg === s.key ? " is-active" : "";
      html += '<button type="button" class="tg-seg' + active + '" data-seg="' + s.key + '">' +
        '<span>' + this.esc(this.lang === "he" ? s.he : s.en) + '</span>' +
        '<span class="tg-seg-count">' + (segCounts[s.key] || 0) + '</span></button>';
    }
    html += '</div>';
    html += '<div class="tg-tools">';
    html += '<div class="tg-search">' + SVG_SEARCH +
      '<input type="text" class="tg-search-input" placeholder="' + this.esc(this.t("searchPh")) +
      '" value="' + this.esc(this.query) + '" /></div>';
    html += '<div class="tg-sort">';
    html += this.sortBtn("view", this.t("sortView"));
    html += this.sortBtn("synced", this.t("sortSynced"));
    html += this.sortBtn("name", this.t("sortName"));
    html += '</div>';
    html += '</div>';
    html += '</div>';

    // body: grid + sliding side panel
    html += '<div class="tg-body' + (this.drillId ? ' is-open' : '') + '">';
    html += '<div class="tg-gridwrap">' + this.gridInnerHtml(all.length, shown) + '</div>';
    html += '<div class="tg-panel">' +
      (this.drillId && this.data[this.drillId] ? this.panelHtml(this.data[this.drillId]) : '') +
      '</div>';
    html += '</div>';

    html += '</div>';
    this.root.innerHTML = html;
    this.applyViewport();
    this.wire();
  }

  private gridInnerHtml(total: number, shown: string[]): string {
    if (total === 0) return this.emptyState(this.t("empty"), this.t("emptyDesc"));
    if (shown.length === 0) return this.emptyState(this.t("emptySeg"), "");
    let g = '<div class="tg-grid">';
    for (const id of shown) g += this.cardHtml(this.data[id]);
    g += '</div>';
    return g;
  }

  private kpi(n: number, label: string, tone: string): string {
    return '<div class="tg-kpi t-' + tone + '"><div class="tg-kpi-n">' + n +
      '</div><div class="tg-kpi-l">' + this.esc(label) + '</div></div>';
  }
  private sortBtn(key: string, label: string): string {
    const active = this.sortMode === key ? " is-active" : "";
    return '<button type="button" class="tg-sortbtn' + active + '" data-sort="' + key + '">' + this.esc(label) + '</button>';
  }

  private cardHtml(d: TplData): string {
    const kind = d.isEnvelope ? "envelope" : "document";
    const glyph = d.isEnvelope ? SVG_ENV : SVG_DOC;
    const selected = this.drillId === d.id ? " is-selected" : "";

    let h = '<div class="tg-card k-' + kind + ' s-' + d.statusKey + selected + '" data-id="' + this.esc(d.id) + '" tabindex="0" role="button">';

    // top: icon + name + status
    h += '<div class="tg-card-top">';
    h += '<div class="tg-icon">' + glyph + '</div>';
    h += '<div class="tg-card-head">';
    h += '<div class="tg-card-name">' + this.esc(d.name) + '</div>';
    h += '<div class="tg-card-kind">' + this.esc(d.isEnvelope ? this.t("envelope") : this.t("document")) + '</div>';
    h += '</div>';
    h += '<span class="tg-status s-' + d.statusKey + '"><span class="tg-dot"></span>' + this.esc(d.statusLabel) + '</span>';
    h += '</div>';

    // meta: primary table display name only
    const tbl = this.tableLabel(d.primaryTable);
    if (tbl) {
      h += '<div class="tg-meta">' + this.chip(tbl) + '</div>';
    }

    // foot: sync + open
    h += '<div class="tg-card-foot">';
    h += '<span class="tg-sync" title="' + this.esc(d.syncedExact) + '">' +
      SVG_SYNC + '<span>' + this.esc(this.relSync(d)) + '</span></span>';
    h += '<button type="button" class="tg-open" data-open="' + this.esc(d.id) + '">' +
      SVG_OPEN + '<span>' + this.esc(this.t("open")) + '</span></button>';
    h += '</div>';

    h += '</div>';
    return h;
  }

  private chip(text: string, icon?: string): string {
    return '<span class="tg-chip">' + (icon || '') + '<span>' + this.esc(text) + '</span></span>';
  }

  /* ---- side-panel details ----------------------------------------- */
  private panelHtml(d: TplData): string {
    const glyph = d.isEnvelope ? SVG_ENV : SVG_DOC;
    let h = '<div class="tg-panel-inner">';

    // panel header
    h += '<div class="tg-panel-head">';
    h += '<button type="button" class="tg-closebtn" data-close="1" aria-label="' + this.esc(this.t("close")) + '">' + SVG_X + '</button>';
    h += '<button type="button" class="tg-open tg-open-lg" data-open="' + this.esc(d.id) + '">' +
      SVG_OPEN + '<span>' + this.esc(this.t("open")) + '</span></button>';
    h += '</div>';

    // hero of the record
    h += '<div class="tg-phero k-' + (d.isEnvelope ? 'envelope' : 'document') + '">';
    h += '<div class="tg-phero-icon">' + glyph + '</div>';
    h += '<div class="tg-phero-main">';
    h += '<div class="tg-phero-name">' + this.esc(d.name) + '</div>';
    h += '<div class="tg-phero-kind">' + this.esc(d.isEnvelope ? this.t("envelope") : this.t("notEnvelope")) + '</div>';
    h += '<span class="tg-status s-' + d.statusKey + '"><span class="tg-dot"></span>' + this.esc(d.statusLabel) + '</span>';
    h += '</div>';
    h += '</div>';

    if (d.summary) h += '<div class="tg-drill-summary">' + this.esc(d.summary) + '</div>';

    // sync section
    h += this.section(this.t("dSync"), [
      this.row(this.t("fSynced"), d.syncedMs ? this.relSync(d) + (d.syncedExact ? ' · ' + d.syncedExact : '') : this.t("syncNever")),
      this.row(this.t("fExternalId"), d.externalId || this.t("none"))
    ]);

    // binding section
    h += this.section(this.t("dBinding"), [
      this.row(this.t("fPrimaryTable"), this.tableLabel(d.primaryTable) || d.relatedTable || this.t("none")),
      this.row(this.t("fContactPath"), d.contactPath || this.t("none")),
      this.rowBool(this.t("fSendFromObject"), d.allowSendFromObject)
    ]);

    // auth section
    h += this.section(this.t("dAuth"), [
      this.row(this.t("fAuthMethod"), d.authLabel || this.t("none")),
      this.row(this.t("fPinMode"), d.pinLabel || this.t("none")),
      this.row(this.t("fOtpSource"), d.otpSource || this.t("none"))
    ]);

    // policy section
    h += this.section(this.t("dPolicy"), [
      this.row(this.t("fExpiry"), d.hasExpiry ? (d.expiryDays ? this.fmt("days", d.expiryDays) : this.t("yes")) : this.t("no")),
      this.rowBool(this.t("fExpiryOverride"), d.allowExpiryOverride),
      this.row(this.t("fCopyLink"), d.copyLinkLabel || this.t("none")),
      this.rowBool(this.t("fPrefillEdit"), d.allowPrefillEdit),
      this.rowBool(this.t("fRecipientLocked"), d.recipientLocked),
      this.rowBool(this.t("fPreview"), d.supportsPreview),
      this.rowBool(this.t("fMulti"), d.supportsMulti)
    ]);

    // roles
    if (d.roles.length) {
      let chips = '<div class="tg-rolechips">';
      for (const r of d.roles) chips += '<span class="tg-rolechip"><span class="tg-roleseq">' + r.sequence + '</span>' + this.esc(r.name) + '</span>';
      chips += '</div>';
      h += '<div class="tg-section"><div class="tg-section-title">' + this.esc(this.t("dRoles")) + '</div>' + chips + '</div>';
    }

    // envelope members (lazy)
    if (d.isEnvelope) {
      h += '<div class="tg-section"><div class="tg-section-title">' + this.esc(this.t("dMembers")) + '</div>';
      const list = this.members[d.id];
      if (this.membersLoading[d.id]) {
        h += '<div class="tg-members-load"><span class="tg-spin sm"></span>' + this.esc(this.t("membersLoading")) + '</div>';
      } else if (!list) {
        h += '<div class="tg-members-load"><span class="tg-spin sm"></span>' + this.esc(this.t("membersLoading")) + '</div>';
      } else if (list.length === 0) {
        h += '<div class="tg-members-empty">' + this.esc(this.t("noMembers")) + '</div>';
      } else {
        h += '<div class="tg-members">';
        for (const m of list) h += '<div class="tg-member"><span class="tg-member-seq">' + m.sequence + '</span><span>' + this.esc(m.name) + '</span></div>';
        h += '</div>';
      }
      h += '</div>';
    }

    h += '</div>';
    return h;
  }

  private section(title: string, rows: string[]): string {
    return '<div class="tg-section"><div class="tg-section-title">' + this.esc(title) +
      '</div><div class="tg-rows">' + rows.join("") + '</div></div>';
  }
  private row(label: string, value: string): string {
    return '<div class="tg-row"><span class="tg-row-l">' + this.esc(label) +
      '</span><span class="tg-row-v">' + this.esc(value) + '</span></div>';
  }
  private rowBool(label: string, on: boolean): string {
    return '<div class="tg-row"><span class="tg-row-l">' + this.esc(label) +
      '</span><span class="tg-row-v"><span class="tg-bool ' + (on ? 'on' : 'off') + '">' +
      this.esc(on ? this.t("yes") : this.t("no")) + '</span></span></div>';
  }

  private emptyState(title: string, desc: string): string {
    let h = '<div class="tg-empty"><div class="tg-empty-icon">' + SVG_DOC + '</div>';
    h += '<div class="tg-empty-title">' + this.esc(title) + '</div>';
    if (desc) h += '<div class="tg-empty-desc">' + this.esc(desc) + '</div>';
    h += '</div>';
    return h;
  }

  /* ---- events ------------------------------------------------------ */
  private wire(): void {
    this.root.querySelectorAll<HTMLElement>(".tg-seg").forEach((b) => {
      b.addEventListener("click", () => {
        const k = b.getAttribute("data-seg");
        if (k) { this.activeSeg = k; this.render(); }
      });
    });
    this.root.querySelectorAll<HTMLElement>(".tg-sortbtn").forEach((b) => {
      b.addEventListener("click", () => {
        const k = b.getAttribute("data-sort");
        if (k) { this.sortMode = k; this.render(); }
      });
    });

    const search = this.root.querySelector<HTMLInputElement>(".tg-search-input");
    if (search) {
      search.addEventListener("input", () => {
        this.query = search.value;
        const wrap = this.root.querySelector<HTMLElement>(".tg-gridwrap");
        if (!wrap) return;
        const all = this.orderedIds.map((id) => this.data[id]).filter(Boolean) as TplData[];
        wrap.innerHTML = this.gridInnerHtml(all.length, this.visibleIds());
        this.wireCards();
      });
    }

    this.wireCards();
    if (this.drillId) this.wirePanel();
  }

  private wireCards(): void {
    this.root.querySelectorAll<HTMLElement>(".tg-card .tg-open").forEach((b) => {
      b.addEventListener("click", (e) => {
        e.stopPropagation();
        const id = b.getAttribute("data-open");
        if (id) this.openForm(id);
      });
    });
    this.root.querySelectorAll<HTMLElement>(".tg-card").forEach((c) => {
      c.addEventListener("click", () => {
        const id = c.getAttribute("data-id");
        if (!id) return;
        if (this.drillId === id) this.closePanel(); else this.openPanel(id);
      });
      c.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          const id = c.getAttribute("data-id");
          if (!id) return;
          if (this.drillId === id) this.closePanel(); else this.openPanel(id);
        }
      });
    });
  }

  private wirePanel(): void {
    const close = this.root.querySelector<HTMLElement>("[data-close]");
    if (close) close.addEventListener("click", () => this.closePanel());
    this.root.querySelectorAll<HTMLElement>(".tg-panel .tg-open").forEach((b) => {
      b.addEventListener("click", (e) => {
        e.stopPropagation();
        const id = b.getAttribute("data-open");
        if (id) this.openForm(id);
      });
    });
  }

  private openPanel(id: string): void {
    const d = this.data[id];
    if (!d) return;
    this.drillId = id;
    const body = this.root.querySelector<HTMLElement>(".tg-body");
    const panel = this.root.querySelector<HTMLElement>(".tg-panel");
    if (!body || !panel) { this.render(); return; }
    panel.innerHTML = this.panelHtml(d);
    body.classList.add("is-open");
    this.root.querySelectorAll<HTMLElement>(".tg-card").forEach((c) => {
      c.classList.toggle("is-selected", c.getAttribute("data-id") === id);
    });
    this.wirePanel();
    if (d.isEnvelope && !this.members[id] && !this.membersLoading[id]) {
      this.fetchMembers(id).then(() => {
        if (this.drillId === id) {
          const p = this.root.querySelector<HTMLElement>(".tg-panel");
          if (p) { p.innerHTML = this.panelHtml(d); this.wirePanel(); }
        }
        return;
      }).catch(() => undefined);
    }
  }

  private closePanel(): void {
    this.drillId = null;
    this.root.querySelectorAll<HTMLElement>(".tg-card.is-selected").forEach((c) => c.classList.remove("is-selected"));
    const body = this.root.querySelector<HTMLElement>(".tg-body");
    if (!body) return;
    body.classList.remove("is-open");
    const panel = this.root.querySelector<HTMLElement>(".tg-panel");
    window.setTimeout(() => {
      if (!this.drillId && panel) panel.innerHTML = "";
    }, 340);
  }

  private openForm(id: string): void {
    this.context.navigation.openForm({ entityName: TEMPLATE_ENTITY, entityId: id });
  }

  /* ---- util -------------------------------------------------------- */
  private esc(s: string): string {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
}
