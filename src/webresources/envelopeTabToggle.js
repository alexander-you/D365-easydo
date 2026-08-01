"use strict";
// envelopeTabToggle.js
// Form onLoad handler for the alex_signaturetemplate main form.
//
// Shows exactly one of the two document tabs depending on whether the open
// template is an envelope:
//   alex_isenvelope = true   -> show "Envelope" tab (tab_envelope),
//                               hide "Document Template" tab (tab_documenttemplate)
//   alex_isenvelope = false  -> the opposite
//
// It also re-applies the toggle whenever alex_isenvelope changes on the form,
// so flipping the flag updates the layout without a reload.
//
// ES5 only (web resource): var/function, string concatenation, no arrow/const/let.
var EasyDo = window.EasyDo || (window.EasyDo = {});
EasyDo.EnvelopeTabs = EasyDo.EnvelopeTabs || {};

(function () {
    var DOC_TAB = "tab_documenttemplate";
    var ENV_TAB = "tab_envelope";
    var FLAG = "alex_isenvelope";
    var ENTITY = "alex_signaturetemplate";

    function setTab(formCtx, name, visible) {
        try {
            var tab = formCtx.ui && formCtx.ui.tabs ? formCtx.ui.tabs.get(name) : null;
            if (tab) { tab.setVisible(visible); }
        } catch (e) { /* tab may not exist on every form */ }
    }

    function applyValue(formCtx, isEnvelope) {
        setTab(formCtx, ENV_TAB, isEnvelope);
        setTab(formCtx, DOC_TAB, !isEnvelope);
    }

    // Resolve the envelope flag. Prefer the on-form attribute (instant); when the
    // alex_isenvelope column is NOT on the form, getAttribute() returns null, so
    // fall back to a Web API read of the open record.
    function resolveAndApply(formCtx) {
        var attr = formCtx.getAttribute(FLAG);
        if (attr) { applyValue(formCtx, !!attr.getValue()); return; }

        var id = "";
        try { id = formCtx.data.entity.getId(); } catch (e) { id = ""; }
        if (!id) { applyValue(formCtx, false); return; }
        id = id.replace(/[{}]/g, "");
        Xrm.WebApi.retrieveRecord(ENTITY, id, "?$select=" + FLAG).then(
            function (rec) { applyValue(formCtx, !!(rec && rec[FLAG])); },
            function () { applyValue(formCtx, false); }
        );
    }

    // Registered as the form OnLoad handler (passExecutionContext = true).
    EasyDo.EnvelopeTabs.onLoad = function (executionContext) {
        var formCtx = executionContext.getFormContext();
        if (!formCtx) { return; }
        resolveAndApply(formCtx);
        var attr = formCtx.getAttribute(FLAG);
        if (attr) {
            attr.addOnChange(function () { applyValue(formCtx, !!attr.getValue()); });
        }
    };
})();
