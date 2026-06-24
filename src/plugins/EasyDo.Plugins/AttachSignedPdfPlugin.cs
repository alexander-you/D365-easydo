/*
  EasyDo.Plugins  -  AttachSignedPdfPlugin

  Backs the alex_AttachSignedPdf Custom API. Given a completed signature request
  plus the signed PDF (base64) the read-back flow downloaded from easydo, it
  creates a single annotation (note with attachment) on the request's PRIMARY
  business record - the contact / entitlement / etc. the document was sent for -
  so the signed copy lands on that record's Timeline. Nothing is attached to the
  signature request itself.

  Input parameters:
    SignatureRequestId (String) - the request GUID
    FileName           (String) - attachment file name (e.g. "Form-signed.pdf")
    FileContent        (String) - base64-encoded PDF bytes
  Output:
    AnnotationId       (String) - id of the created note (empty when skipped)

  The primary record is resolved exactly like the prefill / write-back plug-ins:
  alex_primaryrecordid + the template's alex_primarytable, with a contact
  fallback. When no primary record can be resolved nothing is created (the flow
  has already marked the request Completed regardless).
*/
using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class AttachSignedPdfPlugin : PluginBase
    {
        public AttachSignedPdfPlugin(string unsecure, string secure) : base(typeof(AttachSignedPdfPlugin)) { }

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;
            var svc = local.PluginUserService;

            ctx.OutputParameters["AnnotationId"] = string.Empty;

            var requestIdRaw = ctx.InputParameters.Contains("SignatureRequestId")
                ? ctx.InputParameters["SignatureRequestId"] as string : null;
            var fileName = ctx.InputParameters.Contains("FileName")
                ? ctx.InputParameters["FileName"] as string : null;
            var fileContent = ctx.InputParameters.Contains("FileContent")
                ? ctx.InputParameters["FileContent"] as string : null;

            if (string.IsNullOrEmpty(requestIdRaw) || !Guid.TryParse(requestIdRaw, out var requestId))
            {
                trace.Trace("AttachSignedPdf: SignatureRequestId missing or not a GUID; nothing to do.");
                return;
            }
            if (string.IsNullOrEmpty(fileContent))
            {
                trace.Trace("AttachSignedPdf: FileContent empty; nothing to attach.");
                return;
            }

            var request = svc.Retrieve("alex_signaturerequest", requestId, new ColumnSet(
                "alex_templateid", "alex_relatedcontactid", "alex_primaryrecordid", "alex_name"));

            var templateRef = request.GetAttributeValue<EntityReference>("alex_templateid");
            string primaryTable = null;
            if (templateRef != null)
            {
                try
                {
                    var template = svc.Retrieve("alex_signaturetemplate", templateRef.Id, new ColumnSet("alex_primarytable"));
                    primaryTable = template.GetAttributeValue<string>("alex_primarytable");
                }
                catch (Exception ex) { trace.Trace("AttachSignedPdf: template load failed: {0}", ex.Message); }
            }

            var primaryRecordId = request.GetAttributeValue<string>("alex_primaryrecordid");
            var relatedContact = request.GetAttributeValue<EntityReference>("alex_relatedcontactid");

            EntityReference primary = null;
            if (!string.IsNullOrEmpty(primaryTable) && Guid.TryParse(primaryRecordId, out var prid))
                primary = new EntityReference(primaryTable, prid);
            if (primary == null && relatedContact != null
                && string.Equals(primaryTable, "contact", StringComparison.OrdinalIgnoreCase))
                primary = relatedContact;

            if (primary == null)
            {
                trace.Trace("AttachSignedPdf: could not resolve a primary record (table={0}); skipping.", primaryTable);
                return;
            }

            var requestName = request.GetAttributeValue<string>("alex_name");
            if (string.IsNullOrEmpty(fileName))
                fileName = (string.IsNullOrEmpty(requestName) ? "document" : requestName) + "-signed.pdf";

            var note = new Entity("annotation")
            {
                ["subject"] = "Signed document | מסמך חתום - " + (requestName ?? string.Empty),
                ["filename"] = fileName,
                ["mimetype"] = "application/pdf",
                ["isdocument"] = true,
                ["documentbody"] = fileContent,
                ["objectid"] = new EntityReference(primary.LogicalName, primary.Id)
            };

            try
            {
                var id = svc.Create(note);
                ctx.OutputParameters["AnnotationId"] = id.ToString();
                trace.Trace("AttachSignedPdf: created note {0} on {1}:{2}.", id, primary.LogicalName, primary.Id);

                // Write the note ID back to the signature request for easy retrieval
                var requestUpdate = new Entity("alex_signaturerequest", requestId)
                {
                    ["alex_signednoteid"] = id.ToString()
                };
                svc.Update(requestUpdate);
                trace.Trace("AttachSignedPdf: stored note ID {0} on request {1}.", id, requestId);
            }
            catch (Exception ex)
            {
                trace.Trace("AttachSignedPdf: note create on {0}:{1} failed: {2}",
                    primary.LogicalName, primary.Id, ex.Message);
                throw;
            }
        }
    }
}
