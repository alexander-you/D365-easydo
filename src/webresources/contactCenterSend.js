/*
 * easydo - Contact Center send launcher
 *
 * Runs inside the Customer Service workspace / Dynamics 365 Contact Center agent
 * app. During a LIVE conversation the agent triggers this to send a document for
 * signature to the customer they are talking to. The conversation row
 * (msdyn_ocliveworkitem) cannot host the document, so the launcher resolves a
 * DURABLE host - the linked contact (msdyn_customer) or the linked case
 * (msdyn_issueid -> incident), per the alex_ccdefaultcase setting - and opens the
 * SAME send wizard side pane used by the form button (alex_/html/sendWizard.html),
 * pre-targeted at that host record.
 *
 * Public surface:
 *   - EasyDo.ContactCenter.isEnabled -> Promise<boolean>. True only when the
 *     integration is enabled (alex_contactcenterenabled) AND there is an active
 *     conversation assigned to the agent. Use as a ribbon EnableRule / to gate
 *     a productivity-pane button.
 *   - EasyDo.ContactCenter.launch    -> resolves the host and opens the wizard.
 *
 * The Omnichannel client API (Microsoft.Omnichannel) provides getConversationId().
 * The conversation channel + customer + case are read from the live work item via
 * Xrm.WebApi (same-origin, no token in the browser).
 */
"use strict";

var EasyDo = window.EasyDo || {};

EasyDo.ContactCenter = EasyDo.ContactCenter || {};

(function () {
    var ERROR_PREFIX = "אירעה שגיאה בפתיחת שליחת המסמך: ";

    // Reuse the exact wizard web resource + side pane the form button uses.
    var WIZARD_WEBRESOURCE = "alex_/html/sendWizard.html";
    var WIZARD_PANE_ID = "easydoSendWizard";
    var DIALOG_WIDTH = 600;

    // Walk the frame chain (self -> parent -> ... -> top) and return the first
    // window for which pick(win) yields a truthy value. When this web resource is
    // hosted inside a PCF control inside the productivity pane it can be nested a
    // few frames deep, so we cannot rely on window.parent alone.
    function probeFrames(pick) {
        var win = window;
        for (var i = 0; i < 8 && win; i++) {
            try {
                var v = pick(win);
                if (v) { return v; }
            } catch (e) { /* cross-origin guard */ }
            if (win === win.parent) { break; }
            win = win.parent;
        }
        try { return pick(window.top) || null; } catch (e) { return null; }
    }

    function getXrm() {
        if (typeof Xrm !== "undefined" && Xrm.WebApi) { return Xrm; }
        return probeFrames(function (w) { return (w.Xrm && w.Xrm.WebApi) ? w.Xrm : null; });
    }

    // The Omnichannel client API is injected on the app's top window. In a hosted
    // web resource (possibly nested in a PCF) it lives further up the frame chain.
    function getOmnichannel() {
        return probeFrames(function (w) {
            return (w.Microsoft && w.Microsoft.Omnichannel) ? w.Microsoft.Omnichannel : null;
        });
    }

    function getUiLang() {
        try {
            var xrm = getXrm();
            var lcid = xrm.Utility.getGlobalContext().userSettings.languageId;
            return lcid === 1037 ? "he" : "en";
        } catch (e) {
            return "he";
        }
    }

    // Current live conversation id (= msdyn_ocliveworkitem id), or null. The API
    // returns a Promise; it rejects / returns empty when there is no active,
    // agent-assigned conversation.
    function getConversationId() {
        return new Promise(function (resolve) {
            var oc = getOmnichannel();
            if (!oc || !oc.getConversationId) { resolve(null); return; }
            try {
                Promise.resolve(oc.getConversationId()).then(
                    function (id) { resolve(id || null); },
                    function () { resolve(null); }
                );
            } catch (e) { resolve(null); }
        });
    }

    // Read the master switch + default-host preference from the settings singleton.
    function loadCcSettings() {
        var xrm = getXrm();
        if (!xrm) { return Promise.resolve({ enabled: false, defaultCase: false }); }
        var q = "?$select=alex_contactcenterenabled,alex_ccdefaultcase&$top=1";
        return xrm.WebApi.retrieveMultipleRecords("alex_easydosettings", q).then(function (res) {
            var e = (res && res.entities && res.entities[0]) || {};
            return {
                enabled: e.alex_contactcenterenabled === true,
                defaultCase: e.alex_ccdefaultcase === true
            };
        }, function () {
            return { enabled: false, defaultCase: false };
        });
    }

    // Resolve the durable host record for the conversation. Returns
    // { entityName, recordId, recordName, channel, conversationId } or null.
    function resolveHost(conversationId, defaultCase) {
        var xrm = getXrm();
        if (!xrm || !conversationId) { return Promise.resolve(null); }
        var id = ("" + conversationId).replace(/[{}]/g, "");
        var select = "?$select=msdyn_channel,_msdyn_customer_value,_msdyn_issueid_value";
        return xrm.WebApi.retrieveRecord("msdyn_ocliveworkitem", id, select).then(function (r) {
            var FV = "@OData.Community.Display.V1.FormattedValue";
            var LL = "@Microsoft.Dynamics.CRM.lookuplogicalname";

            var caseId = r._msdyn_issueid_value || null;
            var caseName = r["_msdyn_issueid_value" + FV] || "";
            var custId = r._msdyn_customer_value || null;
            var custType = r["_msdyn_customer_value" + LL] || "contact";
            var custName = r["_msdyn_customer_value" + FV] || "";

            var channel = (r.msdyn_channel || "");
            var channelLabel = r["msdyn_channel" + FV] || "";

            var host = null;
            // The conversation can't host the file; pick a durable record.
            if (defaultCase && caseId) {
                host = { entityName: "incident", recordId: caseId, recordName: caseName };
            } else if (custId) {
                host = { entityName: custType, recordId: custId, recordName: custName };
            } else if (caseId) {
                host = { entityName: "incident", recordId: caseId, recordName: caseName };
            }
            if (!host) { return null; }
            host.channel = channel;
            host.channelLabel = channelLabel;
            host.conversationId = id;
            return host;
        }, function () {
            return null;
        });
    }

    /**
     * Gate for the Contact Center send button. True only when the integration is
     * enabled AND an active conversation exists. Use as a ribbon EnableRule
     * (returns a Promise<boolean>) or to show/hide a productivity-pane button.
     * @returns {Promise<boolean>}
     */
    EasyDo.ContactCenter.isEnabled = function () {
        return loadCcSettings().then(function (cfg) {
            if (!cfg.enabled) { return false; }
            return getConversationId().then(function (cid) { return !!cid; });
        }, function () { return false; });
    };

    /**
     * Snapshot of the current conversation for a hosting UI (e.g. the productivity
     * pane). Resolves the active conversation + its durable host without opening
     * anything. Returns:
     *   { enabled, hasConversation, host } where host (when present) is
     *   { entityName, recordId, recordName, channel, channelLabel, conversationId }.
     * @returns {Promise<object>}
     */
    EasyDo.ContactCenter.getCurrentContext = function () {
        return loadCcSettings().then(function (cfg) {
            if (!cfg.enabled) { return { enabled: false, hasConversation: false, host: null }; }
            return getConversationId().then(function (cid) {
                if (!cid) { return { enabled: true, hasConversation: false, host: null }; }
                return resolveHost(cid, cfg.defaultCase).then(function (host) {
                    return { enabled: true, hasConversation: true, host: host || null };
                });
            });
        }, function () {
            return { enabled: false, hasConversation: false, host: null };
        });
    };

    /**
     * Resolve the conversation's durable host (contact or case) and open the send
     * wizard side pane pre-targeted at it. The conversation id + channel are
     * passed through so a later step can distribute the link over the live channel.
     */
    EasyDo.ContactCenter.launch = function () {
        var xrm = getXrm();
        if (!xrm) { return; }
        try {
            loadCcSettings().then(function (cfg) {
                if (!cfg.enabled) {
                    xrm.Navigation.openAlertDialog({ text: "אינטגרציית Contact Center אינה מופעלת." });
                    return;
                }
                getConversationId().then(function (cid) {
                    if (!cid) {
                        xrm.Navigation.openAlertDialog({ text: ERROR_PREFIX + "לא נמצאה שיחה פעילה." });
                        return;
                    }
                    resolveHost(cid, cfg.defaultCase).then(function (host) {
                        if (!host) {
                            xrm.Navigation.openAlertDialog({ text: ERROR_PREFIX + "לא ניתן לזהות איש קשר או אירוע משויך לשיחה." });
                            return;
                        }
                        openWizard(host);
                    });
                });
            });
        } catch (e) {
            xrm.Navigation.openErrorDialog({ message: ERROR_PREFIX + (e && e.message ? e.message : "") });
        }
    };

    function openWizard(host) {
        var xrm = getXrm();
        if (!xrm.App || !xrm.App.sidePanes || !xrm.App.sidePanes.createPane) {
            xrm.Navigation.openErrorDialog({ message: ERROR_PREFIX + "חלונית צד אינה נתמכת באפליקציה זו." });
            return;
        }
        var data = "entityName=" + encodeURIComponent(host.entityName) +
            "&recordId=" + encodeURIComponent(host.recordId) +
            "&recordName=" + encodeURIComponent(host.recordName || "") +
            "&uilang=" + encodeURIComponent(getUiLang()) +
            "&paneId=" + encodeURIComponent(WIZARD_PANE_ID) +
            // Contact Center context (consumed by a later distribution step).
            "&ccconversationid=" + encodeURIComponent(host.conversationId || "") +
            "&ccchannel=" + encodeURIComponent(host.channel || "");

        var title = getUiLang() === "he" ? "שליחת מסמך easydo" : "Send easydo document";

        var existing = xrm.App.sidePanes.getPane(WIZARD_PANE_ID);
        var panePromise = existing
            ? Promise.resolve(existing)
            : xrm.App.sidePanes.createPane({ paneId: WIZARD_PANE_ID, title: title, canClose: true, width: DIALOG_WIDTH });

        panePromise.then(function (pane) {
            pane.navigate({ pageType: "webresource", webresourceName: WIZARD_WEBRESOURCE, data: data });
            if (pane.select) { try { pane.select(); } catch (e) { /* ignore */ } }
        }, function (err) {
            xrm.Navigation.openErrorDialog({
                message: ERROR_PREFIX + (err && err.message ? err.message : "לא ניתן לפתוח את חלונית האשף.")
            });
        });
    }
})();
