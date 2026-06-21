/*
  EasyDo.Plugins  -  WizardIntakePlugin

  Server-side intake for the send wizard (PCF on a custom page).

  The custom page cannot safely write a full signature request with Power Fx,
  because canvas formulas address Dataverse columns and choices by their
  LOCALIZED display names, which break when the UI language changes. So the page
  does the absolute minimum: it creates one alex_signaturerequest row and dumps
  the wizard's raw JSON into alex_wizardpayload. This plug-in (logical names,
  language independent) turns that JSON into a real request:

      PreValidation (Create):  resolve the template from its external id and set
                               the template lookup, related table/record, draft
                               flag, document language and related contact on the
                               Target, so the rest of the pipeline (e.g.
                               PopulateAnchorPlugin at PreOperation) sees them.

      PostOperation (Create):  create the alex_signaturerecipient rows from the
                               payload and flip the status to "Ready to Send",
                               which fires the existing send flow.

  The JSON shape (produced by SendWizard index.ts emit()):
      { "action":"submit", "nonce":..., "payload": {
          "templateExternalId":"68729", "isDraft":false, "language":"he",
          "recipients":[ {"name":"..","email":"..","sequence":1}, ... ],
          "launchEntityName":"contact", "launchRecordId":"<guid>",
          "relatedContactId":"<guid>" } }
*/
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;
using System.Runtime.Serialization.Json;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class WizardIntakePlugin : PluginBase
    {
        private const int StagePreValidation = 10;
        private const int StagePostOperation = 40;

        private const int StatusReadyToSend = 626210001;
        private const int LanguageHebrew = 626210000;
        private const int LanguageEnglish = 626210001;
        private const int DirectionPrefill = 626210000;

        public WizardIntakePlugin(string unsecure, string secure) : base(typeof(WizardIntakePlugin)) { }

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;
            var svc = local.PluginUserService;

            if (!ctx.InputParameters.Contains("Target") || !(ctx.InputParameters["Target"] is Entity target))
                return;

            var payloadJson = target.GetAttributeValue<string>("alex_wizardpayload");
            if (string.IsNullOrWhiteSpace(payloadJson))
                return;

            WizardPayload payload;
            try
            {
                payload = Parse(payloadJson);
            }
            catch (Exception ex)
            {
                trace.Trace("WizardIntake: payload parse failed: {0}", ex.Message);
                return;
            }
            if (payload == null)
            {
                trace.Trace("WizardIntake: empty payload.");
                return;
            }

            if (ctx.Stage == StagePreValidation)
                ApplyToTarget(target, payload, svc, trace);
            else if (ctx.Stage == StagePostOperation)
                CreateRecipientsAndSend(ctx.PrimaryEntityId, payload, svc, trace);
        }

        // ---- PreValidation: shape the request row before it is written ----
        private static void ApplyToTarget(Entity target, WizardPayload p, IOrganizationService svc, ITracingService trace)
        {
            if (!string.IsNullOrEmpty(p.TemplateExternalId))
            {
                var templateId = ResolveTemplateId(svc, p.TemplateExternalId, trace);
                if (templateId != Guid.Empty)
                    target["alex_templateid"] = new EntityReference("alex_signaturetemplate", templateId);
            }

            if (!string.IsNullOrEmpty(p.LaunchEntityName))
                target["alex_relatedtablename"] = p.LaunchEntityName;

            if (!string.IsNullOrEmpty(p.LaunchRecordId))
                target["alex_relatedrecordid"] = p.LaunchRecordId;

            target["alex_isdraft"] = p.IsDraft;

            target["alex_language"] = new OptionSetValue(
                string.Equals(p.Language, "he", StringComparison.OrdinalIgnoreCase) ? LanguageHebrew : LanguageEnglish);

            if (!string.IsNullOrEmpty(p.RelatedContactId) && Guid.TryParse(p.RelatedContactId, out var contactId))
                target["alex_relatedcontactid"] = new EntityReference("contact", contactId);

            // Chosen notification channels (multi-channel send). When the org has not
            // enabled multi-channel the wizard sends email-only, which matches the
            // default below.
            target["alex_channelemail"] = p.ChannelEmail;
            target["alex_channelsms"] = p.ChannelSms;
            target["alex_channelwhatsapp"] = p.ChannelWhatsApp;

            if (string.IsNullOrEmpty(target.GetAttributeValue<string>("alex_name")))
                target["alex_name"] = "easydo - " + (p.TemplateExternalId ?? "");

            trace.Trace("WizardIntake: target shaped (template={0}, table={1}, draft={2}, lang={3}).",
                p.TemplateExternalId, p.LaunchEntityName, p.IsDraft, p.Language);
        }

        // ---- PostOperation: add recipients and trigger sending ----
        private static void CreateRecipientsAndSend(Guid requestId, WizardPayload p, IOrganizationService svc, ITracingService trace)
        {
            if (requestId == Guid.Empty) return;
            var requestRef = new EntityReference("alex_signaturerequest", requestId);

            if (p.Recipients != null)
            {
                foreach (var r in p.Recipients)
                {
                    if (string.IsNullOrWhiteSpace(r.Email)) continue;
                    var rec = new Entity("alex_signaturerecipient");
                    rec["alex_name"] = string.IsNullOrEmpty(r.Name) ? r.Email : r.Name;
                    rec["alex_email"] = r.Email;
                    if (!string.IsNullOrWhiteSpace(r.Phone)) rec["alex_phone"] = r.Phone;
                    if (r.Sequence > 0) rec["alex_signingorder"] = r.Sequence;
                    if (!string.IsNullOrEmpty(r.RoleName)) rec["alex_externalrecipientname"] = r.RoleName;
                    rec["alex_signaturerequestid"] = requestRef;
                    try { svc.Create(rec); }
                    catch (Exception ex) { trace.Trace("WizardIntake: recipient '{0}' create failed: {1}", r.Email, ex.Message); }
                }
            }

            // Edited prefill values become Prefill override rows; the send flow reads
            // these (direction 626210000) and the ResolvePrefill API skips any field
            // that has an override, so the user's edit wins without duplicates.
            if (p.FieldValues != null)
            {
                foreach (var f in p.FieldValues)
                {
                    if (string.IsNullOrWhiteSpace(f.Name)) continue;
                    var fv = new Entity("alex_signaturefieldvalue");
                    fv["alex_name"] = string.IsNullOrEmpty(f.Label) ? f.Name : f.Label;
                    fv["alex_fieldname"] = f.Name;
                    fv["alex_fieldlabel"] = f.Label;
                    fv["alex_value"] = f.Value;
                    fv["alex_isreadonly"] = f.ReadOnly;
                    fv["alex_direction"] = new OptionSetValue(DirectionPrefill);
                    fv["alex_signaturerequestid"] = requestRef;
                    try { svc.Create(fv); }
                    catch (Exception ex) { trace.Trace("WizardIntake: field value '{0}' create failed: {1}", f.Name, ex.Message); }
                }
            }

            // Flip to Ready to Send -> fires the send flow (recipients already exist).
            try
            {
                svc.Update(new Entity("alex_signaturerequest", requestId)
                {
                    Attributes = { { "alex_status", new OptionSetValue(StatusReadyToSend) } }
                });
                trace.Trace("WizardIntake: request {0} set to Ready to Send.", requestId);
            }
            catch (Exception ex)
            {
                trace.Trace("WizardIntake: could not set status on {0}: {1}", requestId, ex.Message);
            }
        }

        private static Guid ResolveTemplateId(IOrganizationService svc, string externalId, ITracingService trace)
        {
            try
            {
                var q = new QueryExpression("alex_signaturetemplate")
                {
                    ColumnSet = new ColumnSet(false),
                    TopCount = 1,
                    Criteria = new FilterExpression()
                };
                q.Criteria.AddCondition("alex_externaltemplateid", ConditionOperator.Equal, externalId);
                var res = svc.RetrieveMultiple(q);
                if (res.Entities.Count > 0) return res.Entities[0].Id;
                trace.Trace("WizardIntake: no template with external id {0}.", externalId);
            }
            catch (Exception ex)
            {
                trace.Trace("WizardIntake: template lookup failed for {0}: {1}", externalId, ex.Message);
            }
            return Guid.Empty;
        }

        // ---- minimal, order-insensitive JSON reader (sandbox-safe) ----
        private static WizardPayload Parse(string json)
        {
            var doc = new XmlDocument();
            using (var ms = new MemoryStream(Encoding.UTF8.GetBytes(json)))
            using (var reader = JsonReaderWriterFactory.CreateJsonReader(ms, new XmlDictionaryReaderQuotas()))
            {
                doc.Load(reader);
            }

            var payloadNode = doc.SelectSingleNode("/root/payload");
            if (payloadNode == null) return null;

            var p = new WizardPayload
            {
                TemplateExternalId = Text(payloadNode, "templateExternalId"),
                Language = Text(payloadNode, "language"),
                LaunchEntityName = Text(payloadNode, "launchEntityName"),
                LaunchRecordId = Text(payloadNode, "launchRecordId"),
                RelatedContactId = Text(payloadNode, "relatedContactId"),
                IsDraft = string.Equals(Text(payloadNode, "isDraft"), "true", StringComparison.OrdinalIgnoreCase),
                Recipients = new List<WizardRecipient>(),
                FieldValues = new List<WizardFieldValue>()
            };

            // Channels block: { email, sms, whatsapp }. Absent => email only.
            var channelsNode = payloadNode.SelectSingleNode("channels");
            if (channelsNode != null)
            {
                p.ChannelEmail = !string.Equals(Text(channelsNode, "email"), "false", StringComparison.OrdinalIgnoreCase);
                p.ChannelSms = string.Equals(Text(channelsNode, "sms"), "true", StringComparison.OrdinalIgnoreCase);
                p.ChannelWhatsApp = string.Equals(Text(channelsNode, "whatsapp"), "true", StringComparison.OrdinalIgnoreCase);
            }
            else
            {
                p.ChannelEmail = true;
            }

            var recipients = payloadNode.SelectNodes("recipients/item");
            if (recipients != null)
            {
                foreach (XmlNode item in recipients)
                {
                    var email = Text(item, "email");
                    if (string.IsNullOrWhiteSpace(email)) continue;
                    int seq;
                    int.TryParse(Text(item, "sequence"), out seq);
                    p.Recipients.Add(new WizardRecipient { Name = Text(item, "name"), Email = email, Phone = Text(item, "phone"), Sequence = seq, RoleName = Text(item, "roleName") });
                }
            }

            var fieldValues = payloadNode.SelectNodes("fieldValues/item");
            if (fieldValues != null)
            {
                foreach (XmlNode item in fieldValues)
                {
                    var name = Text(item, "name");
                    if (string.IsNullOrWhiteSpace(name)) continue;
                    p.FieldValues.Add(new WizardFieldValue
                    {
                        Name = name,
                        Value = Text(item, "value"),
                        Label = Text(item, "label"),
                        ReadOnly = string.Equals(Text(item, "readOnly"), "true", StringComparison.OrdinalIgnoreCase)
                    });
                }
            }
            return p;
        }

        private static string Text(XmlNode parent, string child)
        {
            var n = parent.SelectSingleNode(child);
            return n == null ? null : n.InnerText;
        }

        private sealed class WizardPayload
        {
            public string TemplateExternalId;
            public bool IsDraft;
            public string Language;
            public string LaunchEntityName;
            public string LaunchRecordId;
            public string RelatedContactId;
            public bool ChannelEmail;
            public bool ChannelSms;
            public bool ChannelWhatsApp;
            public List<WizardRecipient> Recipients;
            public List<WizardFieldValue> FieldValues;
        }

        private sealed class WizardRecipient
        {
            public string Name;
            public string Email;
            public string Phone;
            public int Sequence;
            public string RoleName;
        }

        private sealed class WizardFieldValue
        {
            public string Name;
            public string Value;
            public string Label;
            public bool ReadOnly;
        }
    }
}
