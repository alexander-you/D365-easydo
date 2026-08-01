/*
  EasyDo.Plugins  -  WriteBackPlugin

  Fires on alex_signaturerequest Update (async, post-operation), filtered on
  alex_status. When a request becomes Completed, the recipient's answers (already
  pulled into alex_signaturefieldvalue ReadBack rows by the read-back flow) are
  written back into Dynamics, using the template field mappings to decide which
  table + column each answer goes to.

  Only mappings whose direction allows read-back (ReadBack or Bidirectional) and
  that have a target table + column are written. Each answer is converted to the
  target column's type. Writes are grouped so each target record is updated once.

  Safety: the mapping (which column an answer may land on) is authored inside
  Dynamics by a maker through the Template Field Mapping control, never by the
  external signing party.
*/
using System;
using System.Collections.Generic;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class WriteBackPlugin : PluginBase
    {
        private const int StatusCompleted = 626210006;

        public WriteBackPlugin(string unsecure, string secure) : base(typeof(WriteBackPlugin)) { }

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;

            if (!(ctx.InputParameters.TryGetValue("Target", out var t) && t is Entity target)) return;
            if (target.LogicalName != "alex_signaturerequest") return;

            // Only act when the new status is Completed.
            var status = target.GetAttributeValue<OptionSetValue>("alex_status");
            if (status == null && ctx.PostEntityImages.Contains("PostImage"))
                status = ctx.PostEntityImages["PostImage"].GetAttributeValue<OptionSetValue>("alex_status");
            if (status == null || status.Value != StatusCompleted)
            {
                trace.Trace("Status is not Completed; nothing to write back.");
                return;
            }

            var svc = local.PluginUserService;
            var request = svc.Retrieve("alex_signaturerequest", target.Id, new ColumnSet(
                "alex_templateid", "alex_relatedcontactid", "alex_primaryrecordid", "alex_ismultidocument"));

            var relatedContact = request.GetAttributeValue<EntityReference>("alex_relatedcontactid");
            var primaryRecordId = request.GetAttributeValue<string>("alex_primaryrecordid");
            var converter = new ValueConverter(svc, trace);

            // Envelope: write back each bundle document independently, using its own
            // template's mappings and the read-back rows scoped to that document.
            if (request.GetAttributeValue<bool>("alex_ismultidocument"))
            {
                var items = LoadEnvelopeItems(svc, trace, target.Id);
                if (items.Count == 0) { trace.Trace("Envelope has no document items; nothing to write back."); return; }
                foreach (var memberTemplateRef in items)
                {
                    WriteBackForTemplate(svc, trace, converter, target.Id, memberTemplateRef,
                        memberTemplateRef.Id, primaryRecordId, relatedContact);
                }
                return;
            }

            var templateRef = request.GetAttributeValue<EntityReference>("alex_templateid");
            if (templateRef == null) { trace.Trace("Request has no template; abort."); return; }
            WriteBackForTemplate(svc, trace, converter, target.Id, templateRef,
                Guid.Empty, primaryRecordId, relatedContact);
        }

        // Write back the read-back answers for a single template (a classic request
        // template, or one document of an envelope). When scopedTemplateId is set the
        // read-back rows are filtered to that bundle document.
        private static void WriteBackForTemplate(
            IOrganizationService svc, ITracingService trace, ValueConverter converter,
            Guid requestId, EntityReference templateRef, Guid scopedTemplateId,
            string primaryRecordId, EntityReference relatedContact)
        {
            var template = svc.Retrieve("alex_signaturetemplate", templateRef.Id, new ColumnSet("alex_primarytable"));
            var primaryTable = template.GetAttributeValue<string>("alex_primarytable");

            EntityReference primary = null;
            if (!string.IsNullOrEmpty(primaryTable) && Guid.TryParse(primaryRecordId, out var prid))
                primary = new EntityReference(primaryTable, prid);
            // No explicit anchor: when the document is built directly on contact,
            // fall back to the request's related contact so direct contact
            // mappings (and contact hops) still resolve.
            if (primary == null && relatedContact != null
                && string.Equals(primaryTable, "contact", StringComparison.OrdinalIgnoreCase))
                primary = relatedContact;

            // Map of easydo field name -> recipient answer (ReadBack values).
            var answers = LoadReadBackValues(svc, requestId, scopedTemplateId);
            if (answers.Count == 0) { trace.Trace("No read-back values for template {0}; nothing to write.", templateRef.Id); return; }

            var mappings = MappingReader.ForTemplate(svc, templateRef.Id);
            var primaryCache = new Dictionary<string, Entity>(StringComparer.OrdinalIgnoreCase);
            var pending = new Dictionary<string, Entity>(StringComparer.OrdinalIgnoreCase);

            foreach (var m in mappings)
            {
                if (!Direction.AllowsReadBack(m.DirectionValue)) continue;
                if (string.IsNullOrEmpty(m.Table) || string.IsNullOrEmpty(m.Column)) continue;

                if (!TryGetAnswer(answers, m, out var raw)) continue;

                var targetRef = ResolveWriteTarget(svc, trace, m, primary, relatedContact, primaryCache);
                if (targetRef == null) continue;
                if (!string.Equals(targetRef.LogicalName, m.Table, StringComparison.OrdinalIgnoreCase))
                {
                    trace.Trace("Mapping table '{0}' != resolved target '{1}' for {2}; skipping.",
                        m.Table, targetRef.LogicalName, m.ExternalId);
                    continue;
                }

                if (!converter.TryConvert(m.Table, m.Column, raw, out var value))
                {
                    trace.Trace("Could not convert value for {0}.{1}; skipping.", m.Table, m.Column);
                    continue;
                }

                var key = targetRef.LogicalName + ":" + targetRef.Id;
                if (!pending.TryGetValue(key, out var ent))
                {
                    ent = new Entity(targetRef.LogicalName, targetRef.Id);
                    pending[key] = ent;
                }
                ent[m.Column] = value;
            }

            foreach (var ent in pending.Values)
            {
                try
                {
                    svc.Update(ent);
                    trace.Trace("Updated {0}:{1} ({2} column(s)).", ent.LogicalName, ent.Id, ent.Attributes.Count);
                }
                catch (Exception ex)
                {
                    trace.Trace("Update of {0}:{1} failed: {2}", ent.LogicalName, ent.Id, ex.Message);
                }
            }
        }

        // The member document templates of an envelope request, one per item row.
        private static List<EntityReference> LoadEnvelopeItems(IOrganizationService svc, ITracingService trace, Guid requestId)
        {
            var list = new List<EntityReference>();
            try
            {
                var q = new QueryExpression("alex_signaturerequestitem")
                {
                    ColumnSet = new ColumnSet("alex_templateid"),
                    NoLock = true,
                    Criteria = new FilterExpression()
                };
                q.Criteria.AddCondition("alex_signaturerequestid", ConditionOperator.Equal, requestId);
                q.AddOrder("alex_sequence", OrderType.Ascending);
                foreach (var e in svc.RetrieveMultiple(q).Entities)
                {
                    var t = e.GetAttributeValue<EntityReference>("alex_templateid");
                    if (t != null) list.Add(t);
                }
            }
            catch (Exception ex)
            {
                trace.Trace("LoadEnvelopeItems failed: {0}", ex.Message);
            }
            return list;
        }

        private static Dictionary<string, string> LoadReadBackValues(IOrganizationService svc, Guid requestId, Guid scopedTemplateId)
        {
            var q = new QueryExpression("alex_signaturefieldvalue")
            {
                ColumnSet = new ColumnSet("alex_fieldname", "alex_externalfieldname", "alex_value", "alex_direction"),
                NoLock = true
            };
            q.Criteria.AddCondition("alex_signaturerequestid", ConditionOperator.Equal, requestId);
            q.Criteria.AddCondition("alex_direction", ConditionOperator.Equal, Direction.ReadBack);
            // Envelope mode: only the read-back rows for this bundle document.
            if (scopedTemplateId != Guid.Empty)
                q.Criteria.AddCondition("alex_templateid", ConditionOperator.Equal, scopedTemplateId);

            var byField = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var e in svc.RetrieveMultiple(q).Entities)
            {
                var value = e.GetAttributeValue<string>("alex_value");
                var fn = e.GetAttributeValue<string>("alex_fieldname");
                var hdr = e.GetAttributeValue<string>("alex_externalfieldname");
                if (!string.IsNullOrEmpty(fn)) byField["id:" + fn] = value;
                if (!string.IsNullOrEmpty(hdr)) byField["hdr:" + hdr] = value;
            }
            return byField;
        }

        private static bool TryGetAnswer(Dictionary<string, string> answers, FieldMapping m, out string raw)
        {
            if (!string.IsNullOrEmpty(m.ExternalId) && answers.TryGetValue("id:" + m.ExternalId, out raw)) return true;
            if (!string.IsNullOrEmpty(m.ExternalName) && answers.TryGetValue("hdr:" + m.ExternalName, out raw)) return true;
            raw = null;
            return false;
        }

        private static EntityReference ResolveWriteTarget(
            IOrganizationService svc, ITracingService trace,
            FieldMapping m, EntityReference primary, EntityReference relatedContact,
            Dictionary<string, Entity> primaryCache)
        {
            // Direct on the primary record.
            if (string.IsNullOrEmpty(m.Lookup))
                return primary;

            // Single hop. Prefer resolving the lookup on the primary record.
            if (primary != null)
            {
                var resolved = MappingReader.ResolveTarget(svc, trace, m, primary, primaryCache);
                if (resolved != null) return resolved;
            }

            // Fallback: a contact-targeted hop can use the request's related contact.
            if (string.Equals(m.Table, "contact", StringComparison.OrdinalIgnoreCase) && relatedContact != null)
                return relatedContact;

            return null;
        }
    }
}
