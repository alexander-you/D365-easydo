/*
 * easydo - Sync Signature Templates
 * Grid command handler. Calls the alex_SyncSignatureTemplates custom API (unbound
 * action), which fires the "Sync EasyDoc Templates" cloud flow via the
 * "When an action is performed" trigger.
 * Shows a non-blocking notification that the sync runs in the background.
 */
"use strict";

var EasyDo = window.EasyDo || {};

EasyDo.Templates = EasyDo.Templates || {};

(function () {
    var BACKGROUND_MESSAGE = "סנכרון התבניות מתבצע ברקע";
    var ERROR_PREFIX = "אירעה שגיאה בהפעלת הסנכרון: ";

    function showBackgroundToast() {
        // Prefer the non-blocking global notification bar (model-driven apps).
        if (Xrm.App && typeof Xrm.App.addGlobalNotification === "function") {
            Xrm.App.addGlobalNotification({
                type: 2,        // message bar
                level: 1,       // success
                message: BACKGROUND_MESSAGE,
                showCloseButton: true
            }).then(
                function (notificationId) {
                    // Auto-dismiss after a few seconds.
                    window.setTimeout(function () {
                        Xrm.App.clearGlobalNotification(notificationId);
                    }, 6000);
                },
                function () {
                    Xrm.Navigation.openAlertDialog({ text: BACKGROUND_MESSAGE });
                }
            );
        } else {
            Xrm.Navigation.openAlertDialog({ text: BACKGROUND_MESSAGE });
        }
    }

    /**
     * Command bar handler for the "Sync Templates" button.
     */
    EasyDo.Templates.syncTemplates = function () {
        // Unbound action request for the alex_SyncSignatureTemplates custom API.
        var request = {
            getMetadata: function () {
                return {
                    boundParameter: null,
                    parameterTypes: {},
                    operationType: 0, // Action
                    operationName: "alex_SyncSignatureTemplates"
                };
            }
        };

        Xrm.WebApi.online.execute(request).then(
            function () {
                showBackgroundToast();
            },
            function (error) {
                Xrm.Navigation.openErrorDialog({
                    message: ERROR_PREFIX + (error && error.message ? error.message : "")
                });
            }
        );
    };
})();
