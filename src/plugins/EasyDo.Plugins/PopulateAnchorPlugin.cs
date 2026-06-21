/*
  EasyDo.Plugins  -  PopulateAnchorPlugin

  Pre-operation plug-in on alex_signaturerequest (Create + Update). It closes the
  "who fills alex_primaryrecordid?" gap by deriving the primary-record anchor
  automatically from the generic launch context the send wizard records:

      alex_relatedtablename + alex_relatedrecordid   (where the send was launched)
      alex_relatedcontactid                          (contact fallback)

  The anchor (alex_primaryrecordid) is the GUID of the record the template's
  primary table (alex_signaturetemplate.alex_primarytable) is built on. The
  ResolvePrefill / WriteBack plug-ins read it to resolve every mapped value, so
  the wizard only has to dump the raw launch context - this plug-in computes the
  precise anchor, and only when the launch table actually matches the primary
  table (otherwise it leaves it empty so nothing is resolved against the wrong
  table).

  Runs pre-operation so the value is set in-pipeline with no extra Update call.
  An explicit anchor already present on the row is always respected.
*/
using System;
using System.Collections.Generic;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using Microsoft.Xrm.Sdk.Metadata;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class PopulateAnchorPlugin : PluginBase
    {
        public PopulateAnchorPlugin(string unsecure, string secure) : base(typeof(PopulateAnchorPlugin)) { }

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;
            var svc = local.PluginUserService;

            if (!ctx.InputParameters.Contains("Target") || !(ctx.InputParameters["Target"] is Entity target))
                return;

            // Respect an explicit anchor supplied on this very operation.
            if (!string.IsNullOrEmpty(target.GetAttributeValue<string>("alex_primaryrecordid")))
                return;

            var templateRef = target.GetAttributeValue<EntityReference>("alex_templateid");
            var relatedTable = target.GetAttributeValue<string>("alex_relatedtablename");
            var relatedRecordId = target.GetAttributeValue<string>("alex_relatedrecordid");
            var relatedContact = target.GetAttributeValue<EntityReference>("alex_relatedcontactid");

            var isUpdate = string.Equals(ctx.MessageName, "Update", StringComparison.OrdinalIgnoreCase);

            // On Update the Target only carries changed columns; pull the rest from
            // the stored row. If the stored row already has an anchor, do nothing.
            if (isUpdate &&
                (templateRef == null || string.IsNullOrEmpty(relatedTable) ||
                 string.IsNullOrEmpty(relatedRecordId) || relatedContact == null))
            {
                Entity existing;
                try
                {
                    existing = svc.Retrieve("alex_signaturerequest", target.Id, new ColumnSet(
                        "alex_primaryrecordid", "alex_templateid", "alex_relatedtablename",
                        "alex_relatedrecordid", "alex_relatedcontactid"));
                }
                catch (Exception ex)
                {
                    trace.Trace("PopulateAnchor: could not load existing request {0}: {1}", target.Id, ex.Message);
                    return;
                }
                if (!string.IsNullOrEmpty(existing.GetAttributeValue<string>("alex_primaryrecordid")))
                    return;
                templateRef = templateRef ?? existing.GetAttributeValue<EntityReference>("alex_templateid");
                if (string.IsNullOrEmpty(relatedTable)) relatedTable = existing.GetAttributeValue<string>("alex_relatedtablename");
                if (string.IsNullOrEmpty(relatedRecordId)) relatedRecordId = existing.GetAttributeValue<string>("alex_relatedrecordid");
                relatedContact = relatedContact ?? existing.GetAttributeValue<EntityReference>("alex_relatedcontactid");
            }

            if (templateRef == null)
            {
                trace.Trace("PopulateAnchor: no template on the request; cannot resolve the primary table.");
                return;
            }

            string primaryTable;
            try
            {
                var template = svc.Retrieve("alex_signaturetemplate", templateRef.Id, new ColumnSet("alex_primarytable"));
                primaryTable = template.GetAttributeValue<string>("alex_primarytable");
            }
            catch (Exception ex)
            {
                trace.Trace("PopulateAnchor: template {0} load failed: {1}", templateRef.Id, ex.Message);
                return;
            }
            if (string.IsNullOrEmpty(primaryTable))
            {
                trace.Trace("PopulateAnchor: template has no primary table; leaving anchor empty.");
                return;
            }

            string anchor = null;

            // 1. The send was launched from a record of the template's primary table.
            if (!string.IsNullOrEmpty(relatedTable) && !string.IsNullOrEmpty(relatedRecordId)
                && string.Equals(relatedTable, primaryTable, StringComparison.OrdinalIgnoreCase)
                && Guid.TryParse(relatedRecordId, out _))
            {
                anchor = relatedRecordId;
            }
            // 2. The document is built directly on contact - use the related contact.
            else if (string.Equals(primaryTable, "contact", StringComparison.OrdinalIgnoreCase)
                && relatedContact != null)
            {
                anchor = relatedContact.Id.ToString();
            }

            if (anchor == null)
            {
                trace.Trace("PopulateAnchor: launch context (table={0}) does not match primary table {1}; anchor left empty.",
                    relatedTable, primaryTable);
                return;
            }

            target["alex_primaryrecordid"] = anchor;
            trace.Trace("PopulateAnchor: set alex_primaryrecordid={0} (primary table {1}).", anchor, primaryTable);

            // Also populate the dedicated, native lookup (e.g. alex_relatedentitlementid)
            // so the primary record shows a real subgrid of its signature requests.
            // The contact case is already handled by alex_relatedcontactid; for every
            // other primary table a per-table lookup is provisioned by script 22.
            if (Guid.TryParse(anchor, out var anchorId))
                SetDedicatedLookup(svc, trace, target, primaryTable, anchorId);
        }

        // Convention (mirrors 22-create-related-record-lookups.ps1):
        //   logical column = "alex_related" + <primary table without underscores> + "id"
        // e.g. entitlement -> alex_relatedentitlementid, contact -> alex_relatedcontactid.
        private static void SetDedicatedLookup(
            IOrganizationService svc, ITracingService trace, Entity target,
            string primaryTable, Guid anchorId)
        {
            var column = "alex_related" + primaryTable.Replace("_", string.Empty).ToLowerInvariant() + "id";

            // Skip if the operation already carries this lookup (e.g. the wizard set
            // alex_relatedcontactid for a contact-based template).
            if (target.Contains(column)) return;

            // Only set the lookup when the column actually exists on the request,
            // otherwise the platform would reject the whole create/update.
            if (!RequestLookupExists(svc, trace, column))
            {
                trace.Trace("PopulateAnchor: lookup column {0} not present; skipping native link.", column);
                return;
            }

            target[column] = new EntityReference(primaryTable, anchorId);
            trace.Trace("PopulateAnchor: set {0} -> {1}:{2}.", column, primaryTable, anchorId);
        }

        private static HashSet<string> _lookupColumns;
        private static readonly object _lock = new object();

        // Returns the set of Lookup attribute logical names on alex_signaturerequest,
        // retrieved once via entity metadata. RetrieveEntityRequest is reliable inside
        // the sandbox where a per-attribute RetrieveAttributeRequest was not.
        private static bool RequestLookupExists(IOrganizationService svc, ITracingService trace, string column)
        {
            if (_lookupColumns == null)
            {
                lock (_lock)
                {
                    if (_lookupColumns == null)
                    {
                        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                        try
                        {
                            var resp = (RetrieveEntityResponse)svc.Execute(new RetrieveEntityRequest
                            {
                                LogicalName = "alex_signaturerequest",
                                EntityFilters = EntityFilters.Attributes,
                                RetrieveAsIfPublished = true
                            });
                            foreach (var a in resp.EntityMetadata.Attributes)
                            {
                                if (a.AttributeType == AttributeTypeCode.Lookup && a.LogicalName != null)
                                    set.Add(a.LogicalName);
                            }
                        }
                        catch (Exception ex)
                        {
                            trace.Trace("PopulateAnchor: entity metadata retrieve failed: {0}", ex.Message);
                        }
                        _lookupColumns = set;
                    }
                }
            }
            return _lookupColumns.Contains(column);
        }
    }
}
