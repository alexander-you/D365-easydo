/*
  EasyDo.Plugins  -  AutoMapTemplateFieldsPlugin

  Backs the alex_AutoMapTemplateFields Custom API. Given a template, it walks every
  alex_templatefieldmapping row and tries to resolve its EXPORT name
  (alex_externalexportname) into a Dynamics binding, writing:
      alex_dynamicstable  (target table logical name)
      alex_dynamicsfield  (column logical name)
      alex_lookupfield    (lookup attribute on the primary table; cleared for direct)

  Binding key grammar (logical names, first segment MUST equal the template's
  primary table):
      <primary>.<column>                       -> direct on the primary table
      <primary>.<lookup>.<column>              -> single-target lookup hop
                                                  (target derived from metadata;
                                                   polymorphic lookups are skipped)
      <primary>.<lookup>.<target>.<column>     -> polymorphic lookup hop with an
                                                  explicit target table

  Overwrites every row it can resolve. Rows it cannot resolve are left untouched
  and reported in the Message output.

  Input  : TemplateId (String, the alex_signaturetemplate GUID)
  Outputs: Matched (Integer), Skipped (Integer), Message (String)
*/
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using Microsoft.Xrm.Sdk.Metadata;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class AutoMapTemplateFieldsPlugin : PluginBase
    {
        public AutoMapTemplateFieldsPlugin(string unsecure, string secure) : base(typeof(AutoMapTemplateFieldsPlugin)) { }

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;
            var svc = local.PluginUserService;

            var templateIdRaw = ctx.InputParameters.Contains("TemplateId")
                ? ctx.InputParameters["TemplateId"] as string
                : null;
            if (string.IsNullOrEmpty(templateIdRaw) || !Guid.TryParse(templateIdRaw, out var templateId))
                throw new InvalidPluginExecutionException(
                    "TemplateId is missing or not a valid GUID. / מזהה התבנית חסר או אינו GUID תקין.");

            var template = svc.Retrieve("alex_signaturetemplate", templateId, new ColumnSet("alex_primarytable"));
            var primaryTable = template.GetAttributeValue<string>("alex_primarytable");
            if (string.IsNullOrWhiteSpace(primaryTable))
                throw new InvalidPluginExecutionException(
                    "The template has no primary table (alex_primarytable). Set it before auto-mapping. / " +
                    "לתבנית אין טבלה ראשית (alex_primarytable). הגדר אותה לפני התאמה אוטומטית.");
            primaryTable = primaryTable.Trim().ToLowerInvariant();

            var meta = new MetaCache(svc, trace);
            if (meta.Get(primaryTable) == null)
                throw new InvalidPluginExecutionException(
                    "The primary table '" + primaryTable + "' could not be read from metadata. / " +
                    "לא ניתן לקרוא את הטבלה הראשית '" + primaryTable + "' מהמטא-דאטה.");

            var rows = svc.RetrieveMultiple(new QueryExpression("alex_templatefieldmapping")
            {
                ColumnSet = new ColumnSet("alex_externalexportname", "alex_dynamicstable", "alex_dynamicsfield", "alex_lookupfield"),
                Criteria = BuildCriteria(templateId),
                NoLock = true
            }).Entities;

            int matched = 0, skipped = 0;
            var skips = new List<string>();

            foreach (var row in rows)
            {
                var key = (row.GetAttributeValue<string>("alex_externalexportname") ?? string.Empty).Trim();
                if (key.Length == 0) { skipped++; continue; } // no binding key on this row

                string table, column, lookup, reason;
                if (TryResolve(meta, primaryTable, key, out table, out column, out lookup, out reason))
                {
                    var upd = new Entity("alex_templatefieldmapping", row.Id)
                    {
                        ["alex_dynamicstable"] = table,
                        ["alex_dynamicsfield"] = column,
                        ["alex_lookupfield"] = string.IsNullOrEmpty(lookup) ? null : lookup
                    };
                    svc.Update(upd);
                    matched++;
                    trace.Trace("Mapped '{0}' -> {1}.{2} (lookup '{3}').", key, table, column, lookup ?? "");
                }
                else
                {
                    skipped++;
                    if (skips.Count < 20) skips.Add("'" + key + "': " + reason);
                    trace.Trace("Skipped '{0}': {1}", key, reason);
                }
            }

            var msg = new StringBuilder();
            msg.Append("Mapped ").Append(matched).Append(", skipped ").Append(skipped).Append('.');
            if (skips.Count > 0) msg.Append(" Skipped: ").Append(string.Join("; ", skips));

            ctx.OutputParameters["Matched"] = matched;
            ctx.OutputParameters["Skipped"] = skipped;
            ctx.OutputParameters["Message"] = msg.ToString();
        }

        private static FilterExpression BuildCriteria(Guid templateId)
        {
            var f = new FilterExpression();
            f.AddCondition("alex_templateid", ConditionOperator.Equal, templateId);
            return f;
        }

        // Resolves a binding key to table/column/lookup. Returns false with a reason
        // when the key does not follow the grammar or does not exist in metadata.
        private static bool TryResolve(
            MetaCache meta, string primaryTable, string key,
            out string table, out string column, out string lookup, out string reason)
        {
            table = column = lookup = null;
            reason = null;

            // easydo appends a copy index like " (1)" to the export header when the
            // same field repeats in the document. Strip it so the binding resolves.
            key = StripCopyIndex(key);

            var parts = key.Split('.');
            for (int i = 0; i < parts.Length; i++) parts[i] = parts[i].Trim().ToLowerInvariant();

            if (parts.Length < 2) { reason = "not a table-prefixed binding key"; return false; }
            if (parts[0].Length == 0 || !string.Equals(parts[0], primaryTable, StringComparison.OrdinalIgnoreCase))
            { reason = "first segment '" + parts[0] + "' is not the primary table '" + primaryTable + "'"; return false; }

            var primaryMeta = meta.Get(primaryTable);
            if (primaryMeta == null) { reason = "primary table metadata unavailable"; return false; }

            if (parts.Length == 2)
            {
                // direct: <primary>.<column>
                var col = parts[1];
                if (!meta.HasAttribute(primaryTable, col)) { reason = "column '" + col + "' not found on '" + primaryTable + "'"; return false; }
                table = primaryTable; column = col; lookup = null;
                return true;
            }

            if (parts.Length == 3)
            {
                // single-target hop: <primary>.<lookup>.<column>
                var look = parts[1];
                var col = parts[2];
                var la = meta.GetLookup(primaryTable, look);
                if (la == null) { reason = "'" + look + "' is not a lookup on '" + primaryTable + "'"; return false; }
                var targets = la.Targets ?? new string[0];
                if (targets.Length == 0) { reason = "lookup '" + look + "' has no target table"; return false; }
                if (targets.Length > 1) { reason = "lookup '" + look + "' is polymorphic; specify a target table (" + string.Join(", ", targets) + ")"; return false; }
                var tgt = targets[0].ToLowerInvariant();
                if (!meta.HasAttribute(tgt, col)) { reason = "column '" + col + "' not found on '" + tgt + "'"; return false; }
                table = tgt; column = col; lookup = look;
                return true;
            }

            if (parts.Length == 4)
            {
                // explicit-target hop (polymorphic): <primary>.<lookup>.<target>.<column>
                var look = parts[1];
                var tgt = parts[2];
                var col = parts[3];
                var la = meta.GetLookup(primaryTable, look);
                if (la == null) { reason = "'" + look + "' is not a lookup on '" + primaryTable + "'"; return false; }
                var targets = la.Targets ?? new string[0];
                if (!Contains(targets, tgt)) { reason = "lookup '" + look + "' cannot reference '" + tgt + "' (targets: " + string.Join(", ", targets) + ")"; return false; }
                if (!meta.HasAttribute(tgt, col)) { reason = "column '" + col + "' not found on '" + tgt + "'"; return false; }
                table = tgt; column = col; lookup = look;
                return true;
            }

            reason = "too many segments (only a single lookup hop is supported)";
            return false;
        }

        private static bool Contains(string[] arr, string value)
        {
            foreach (var a in arr)
                if (string.Equals(a, value, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        // Removes a trailing copy index such as " (1)" / "(12)" that easydo appends
        // to duplicated field headers. Dataverse logical names never contain spaces
        // or parentheses, so this is safe.
        private static string StripCopyIndex(string key)
        {
            if (string.IsNullOrEmpty(key)) return key;
            return Regex.Replace(key, @"\s*\(\d+\)\s*$", string.Empty).Trim();
        }

        // Loads and caches entity metadata (attributes) per logical name. Uses
        // RetrieveEntityRequest, which is reliable inside the sandbox where a
        // per-attribute RetrieveAttributeRequest was not.
        private sealed class MetaCache
        {
            private readonly IOrganizationService _svc;
            private readonly ITracingService _trace;
            private readonly Dictionary<string, EntityMetadata> _cache =
                new Dictionary<string, EntityMetadata>(StringComparer.OrdinalIgnoreCase);

            public MetaCache(IOrganizationService svc, ITracingService trace) { _svc = svc; _trace = trace; }

            public EntityMetadata Get(string logicalName)
            {
                if (string.IsNullOrEmpty(logicalName)) return null;
                if (_cache.TryGetValue(logicalName, out var em)) return em;
                try
                {
                    var resp = (RetrieveEntityResponse)_svc.Execute(new RetrieveEntityRequest
                    {
                        LogicalName = logicalName,
                        EntityFilters = EntityFilters.Attributes,
                        RetrieveAsIfPublished = true
                    });
                    em = resp.EntityMetadata;
                }
                catch (Exception ex)
                {
                    _trace.Trace("Metadata retrieve for '{0}' failed: {1}", logicalName, ex.Message);
                    em = null;
                }
                _cache[logicalName] = em;
                return em;
            }

            public bool HasAttribute(string logicalName, string attribute)
            {
                var em = Get(logicalName);
                if (em?.Attributes == null) return false;
                foreach (var a in em.Attributes)
                    if (string.Equals(a.LogicalName, attribute, StringComparison.OrdinalIgnoreCase)) return true;
                return false;
            }

            public LookupAttributeMetadata GetLookup(string logicalName, string attribute)
            {
                var em = Get(logicalName);
                if (em?.Attributes == null) return null;
                foreach (var a in em.Attributes)
                    if (string.Equals(a.LogicalName, attribute, StringComparison.OrdinalIgnoreCase)
                        && a.AttributeType == AttributeTypeCode.Lookup)
                        return a as LookupAttributeMetadata;
                return null;
            }
        }
    }
}
