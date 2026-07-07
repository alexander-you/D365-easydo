"use strict";
// templateAutoMap.js
// Ribbon command for the "Auto-map fields" button on the alex_signaturetemplate
// form. Calls the alex_AutoMapTemplateFields Custom API for the current template,
// which resolves each field mapping's export name into a Dynamics table.column
// binding (overwriting every row it can resolve), then refreshes the form.
// ES5 only (web resource): var/function, string concatenation, no arrow/const/let.
var EasyDo = window.EasyDo || (window.EasyDo = {});
EasyDo.AutoMap = EasyDo.AutoMap || {};

(function () {
    var TITLE = "התאמה אוטומטית של שדות";

    // Enable rule: the button is a global form command, but it is only shown on
    // the signature-template form (a disabled command is hidden in the Unified
    // Interface command bar).
    EasyDo.AutoMap.isEnabled = function (primaryControl) {
        try {
            return !!primaryControl && !!primaryControl.data && !!primaryControl.data.entity
                && primaryControl.data.entity.getEntityName() === "alex_signaturetemplate";
        } catch (e) {
            return false;
        }
    };

    // Invoked by the ribbon button with the form's PrimaryControl.
    EasyDo.AutoMap.run = function (primaryControl) {
        var formCtx = primaryControl;
        if (!formCtx || !formCtx.data || !formCtx.data.entity) { return; }

        var id = formCtx.data.entity.getId();
        if (!id) { return; }
        id = id.replace(/[{}]/g, "");

        var confirmStrings = {
            title: TITLE,
            text: "פעולה זו תתאים אוטומטית את שדות התבנית לשדות Dynamics לפי שם הייצוא, "
                + "ותדרוס מיפויים קיימים שניתן לפתור. להמשיך?",
            confirmButtonLabel: "התאם",
            cancelButtonLabel: "ביטול"
        };

        Xrm.Navigation.openConfirmDialog(confirmStrings).then(function (res) {
            if (!res || !res.confirmed) { return; }
            execute(formCtx, id);
        });
    };

    function execute(formCtx, templateId) {
        var request = {
            TemplateId: templateId,
            getMetadata: function () {
                return {
                    boundParameter: null,
                    operationType: 0, // Action
                    operationName: "alex_AutoMapTemplateFields",
                    parameterTypes: {
                        TemplateId: { typeName: "Edm.String", structuralProperty: 1 }
                    }
                };
            }
        };

        Xrm.WebApi.online.execute(request).then(function (response) {
            return response.json();
        }).then(function (result) {
            var matched = (result && typeof result.Matched === "number") ? result.Matched : 0;
            var skipped = (result && typeof result.Skipped === "number") ? result.Skipped : 0;
            var detail = (result && result.Message) ? result.Message : "";

            var text = "הותאמו " + matched + " שדות, דולגו " + skipped + ".";
            if (detail) { text = text + "\n\n" + detail; }

            Xrm.Navigation.openAlertDialog({ title: TITLE, text: text }).then(function () {
                formCtx.data.refresh(false);
            });
        }, function (error) {
            var msg = (error && error.message) ? error.message : "אירעה שגיאה בהתאמה האוטומטית.";
            Xrm.Navigation.openErrorDialog({ message: msg });
        });
    }
})();
