/*
 * easydo - Form Send launcher + EnableRule
 *
 * One global "Send easydo document" button is installed on every table's form
 * via the APPLICATION RIBBON (table template, location
 * Mscrm.Form.{!EntityLogicalName}.MainTab.Save.Controls._children). It is NOT
 * created per entity and NOT deployed by a plugin at runtime.
 *
 * Visibility is controlled at runtime:
 *   - EasyDo.FormSend.isEnabled  -> ribbon CustomRule (EnableRule). Returns a
 *     Promise<boolean>; shows the button only for tables that have an
 *     alex_easydoentityconfig row with alex_sendenabled = true. Cached per table.
 *   - EasyDo.FormSend.launch     -> command handler; opens the send wizard.
 *
 * Both receive the primary control (form context) via the CrmParameter
 * "PrimaryControl" configured on the ribbon button/rule, from which we read the
 * current record's table + id.
 */
"use strict";

var EasyDo = window.EasyDo || {};

EasyDo.FormSend = EasyDo.FormSend || {};

(function () {
    var ERROR_PREFIX = "אירעה שגיאה בפתיחת אשף השליחה: ";

    // Name of the HTML web resource that hosts the send wizard UI. It is opened
    // as a model-driven SIDE PANE (Xrm.App.sidePanes), so it is same-origin with
    // the app and has native Xrm.WebApi. A canvas custom page could not read or
    // write Dataverse in this environment (premium connector blocked) and could
    // not receive custom navigation parameters, so the wizard now lives entirely
    // in this web resource.
    var WIZARD_WEBRESOURCE = "alex_/html/sendWizard.html";

    // Stable side-pane id so re-launching reuses/replaces the same pane.
    var WIZARD_PANE_ID = "easydoSendWizard";

    // Side-pane width (px). Matches the Microsoft "open in side pane" feel.
    var DIALOG_WIDTH = 600;

    // Map the model-driven user's UI language id to the wizard's "he"/"en".
    // Read in the model-driven context (where the real UI language is known)
    // and passed to the web resource so its UI matches the app language.
    function getUiLang() {
        try {
            var lcid = Xrm.Utility.getGlobalContext().userSettings.languageId;
            return lcid === 1037 ? "he" : "en";
        } catch (e) {
            return "he";
        }
    }

    function getEntityContext(primaryControl) {
        // primaryControl is the form context passed by the ribbon (PrimaryControl).
        if (!primaryControl || !primaryControl.data || !primaryControl.data.entity) {
            return null;
        }
        var entity = primaryControl.data.entity;
        var id = entity.getId ? entity.getId() : null;
        var name = entity.getEntityName ? entity.getEntityName() : null;
        if (!id || !name) {
            return null;
        }
        var primaryName = "";
        try {
            if (entity.getPrimaryAttributeValue) {
                primaryName = entity.getPrimaryAttributeValue() || "";
            }
        } catch (e) {
            primaryName = "";
        }
        return {
            entityName: name,
            // Strip the surrounding braces Dynamics adds to GUIDs.
            recordId: id.replace(/[{}]/g, ""),
            recordName: primaryName
        };
    }

    // Client-side cache of "is easydo send enabled for this table", keyed by
    // entity logical name. The EnableRule runs on every form load for every
    // table, so we must never hit Dataverse more than once per table per session.
    EasyDo.FormSend._enableCache = EasyDo.FormSend._enableCache || {};

    function queryEnabled(entityName) {
        // The button shows on a form only when the table is configured with send
        // enabled AND form placement enabled.
        var query = "?$select=alex_easydoentityconfigid&$top=1&$filter=" +
            "alex_entitylogicalname eq '" + entityName + "'" +
            " and alex_sendenabled eq true" +
            " and alex_enableonform eq true";
        return Xrm.WebApi.online.retrieveMultipleRecords("alex_easydoentityconfig", query)
            .then(function (result) {
                return !!(result && result.entities && result.entities.length > 0);
            });
    }

    /**
     * Ribbon EnableRule (CustomRule) for the global "Send easydo document" button.
     * Returns a Promise<boolean> (Unified Interface). The button is installed once
     * on every table via the application ribbon; this rule decides per-table
     * whether it is shown, based on the alex_easydoentityconfig configuration.
     * Result is cached per table for the session to protect form-load performance.
     * @param {object} primaryControl form context supplied via PrimaryControl.
     * @returns {Promise<boolean>}
     */
    EasyDo.FormSend.isEnabled = function (primaryControl) {
        return new Promise(function (resolve) {
            try {
                var ctx = getEntityContext(primaryControl);
                if (!ctx) { resolve(false); return; }

                var entityName = ctx.entityName;
                var cache = EasyDo.FormSend._enableCache;
                if (Object.prototype.hasOwnProperty.call(cache, entityName)) {
                    resolve(cache[entityName]);
                    return;
                }

                queryEnabled(entityName).then(
                    function (enabled) {
                        cache[entityName] = enabled;
                        resolve(enabled);
                    },
                    function () {
                        // On any error fail closed (button hidden) but do not cache,
                        // so a transient failure can recover on the next evaluation.
                        resolve(false);
                    }
                );
            } catch (e) {
                resolve(false);
            }
        });
    };

    /**
     * Command bar handler for the "Send easydo document" form button.
     * Opens the wizard web resource in a right-side pane. The web resource is
     * served from the org domain, so it has native Xrm.WebApi: it reads the
     * templates and creates the alex_signaturerequest itself. The launch context
     * (table, record, language) is passed through the pane's data parameter.
     * @param {object} primaryControl form context supplied via PrimaryControl.
     */
    EasyDo.FormSend.launch = function (primaryControl) {
        try {
            var ctx = getEntityContext(primaryControl);
            if (!ctx) {
                Xrm.Navigation.openAlertDialog({ text: ERROR_PREFIX + "לא ניתן לזהות את הרשומה הנוכחית." });
                return;
            }

            if (!Xrm.App || !Xrm.App.sidePanes || !Xrm.App.sidePanes.createPane) {
                Xrm.Navigation.openErrorDialog({ message: ERROR_PREFIX + "חלונית צד אינה נתמכת באפליקציה זו." });
                return;
            }

            // Pass the launch context to the web resource through the pane's data
            // string (surfaces as ?data=<urlencoded> inside the web resource).
            var data = "entityName=" + encodeURIComponent(ctx.entityName) +
                "&recordId=" + encodeURIComponent(ctx.recordId) +
                "&recordName=" + encodeURIComponent(ctx.recordName || "") +
                "&uilang=" + encodeURIComponent(getUiLang()) +
                "&paneId=" + encodeURIComponent(WIZARD_PANE_ID);

            var title = getUiLang() === "he" ? "שליחת מסמך easydo" : "Send easydo document";

            // Reuse the pane if it is already open, otherwise create it.
            var existing = Xrm.App.sidePanes.getPane(WIZARD_PANE_ID);
            var panePromise = existing
                ? Promise.resolve(existing)
                : Xrm.App.sidePanes.createPane({
                    paneId: WIZARD_PANE_ID,
                    title: title,
                    canClose: true,
                    width: DIALOG_WIDTH
                });

            panePromise.then(function (pane) {
                pane.navigate({
                    pageType: "webresource",
                    webresourceName: WIZARD_WEBRESOURCE,
                    data: data
                });
                if (pane.select) { try { pane.select(); } catch (e) { /* ignore */ } }
            }, function (err) {
                Xrm.Navigation.openErrorDialog({
                    message: ERROR_PREFIX + (err && err.message ? err.message : "לא ניתן לפתוח את חלונית האשף.")
                });
            });
        } catch (e) {
            Xrm.Navigation.openErrorDialog({
                message: ERROR_PREFIX + (e && e.message ? e.message : "")
            });
        }
    };
})();
