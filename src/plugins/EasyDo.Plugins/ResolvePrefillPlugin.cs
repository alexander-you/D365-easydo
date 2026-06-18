/*
  EasyDo.Plugins  -  ResolvePrefillPlugin

  Backs the alex_ResolvePrefill Custom API. Given a signature request, it returns
  the prefill_data array (as JSON) that the send flow passes to easydo: one item
  per Prefill / Bidirectional mapping that has a target table + column, read from
  the source record (primary record, or one lookup hop off it).

  Input  parameter : SignatureRequestId (String, the request GUID)
  Output parameter : PrefillData        (String, JSON array of
                     { "name": <easydo field name>,
                       "content_value": <display value>,
                       "read_only": <bool> })

  The value is taken from the formatted (display) value so option sets, dates,
  money and lookups prefill as human-readable text, matching what a recipient
  would see and edit.
*/
using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class ResolvePrefillPlugin : PluginBase
    {
        public ResolvePrefillPlugin(string unsecure, string secure) : base(typeof(ResolvePrefillPlugin)) { }

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;
            var svc = local.PluginUserService;

            var requestIdRaw = ctx.InputParameters.Contains("SignatureRequestId")
                ? ctx.InputParameters["SignatureRequestId"] as string
                : null;
            if (string.IsNullOrEmpty(requestIdRaw) || !Guid.TryParse(requestIdRaw, out var requestId))
            {
                ctx.OutputParameters["PrefillData"] = "[]";
                trace.Trace("SignatureRequestId missing or not a GUID; returning empty.");
                return;
            }

            var request = svc.Retrieve("alex_signaturerequest", requestId, new ColumnSet(
                "alex_templateid", "alex_relatedcontactid", "alex_primaryrecordid"));
            var templateRef = request.GetAttributeValue<EntityReference>("alex_templateid");
            if (templateRef == null) { ctx.OutputParameters["PrefillData"] = "[]"; return; }

            var template = svc.Retrieve("alex_signaturetemplate", templateRef.Id, new ColumnSet("alex_primarytable"));
            var primaryTable = template.GetAttributeValue<string>("alex_primarytable");
            var primaryRecordId = request.GetAttributeValue<string>("alex_primaryrecordid");
            var relatedContact = request.GetAttributeValue<EntityReference>("alex_relatedcontactid");

            EntityReference primary = null;
            if (!string.IsNullOrEmpty(primaryTable) && Guid.TryParse(primaryRecordId, out var prid))
                primary = new EntityReference(primaryTable, prid);

            var mappings = MappingReader.ForTemplate(svc, templateRef.Id);
            var primaryCache = new Dictionary<string, Entity>(StringComparer.OrdinalIgnoreCase);
            var sourceCache = new Dictionary<string, Entity>(StringComparer.OrdinalIgnoreCase);

            var items = new List<string>();
            foreach (var m in mappings)
            {
                if (!Direction.AllowsPrefill(m.DirectionValue)) continue;
                if (string.IsNullOrEmpty(m.Table) || string.IsNullOrEmpty(m.Column)) continue;
                if (string.IsNullOrEmpty(m.ExternalId)) continue;

                var srcRef = ResolveSource(svc, trace, m, primary, relatedContact, primaryCache);
                if (srcRef == null) continue;
                if (!string.Equals(srcRef.LogicalName, m.Table, StringComparison.OrdinalIgnoreCase)) continue;

                var value = ReadDisplayValue(svc, trace, srcRef, m.Column, sourceCache);
                if (value == null) continue;

                items.Add(BuildItem(m.ExternalId, value, m.ReadOnly));
            }

            ctx.OutputParameters["PrefillData"] = "[" + string.Join(",", items) + "]";
            trace.Trace("ResolvePrefill produced {0} item(s).", items.Count);
        }

        private static EntityReference ResolveSource(
            IOrganizationService svc, ITracingService trace,
            FieldMapping m, EntityReference primary, EntityReference relatedContact,
            Dictionary<string, Entity> primaryCache)
        {
            if (string.IsNullOrEmpty(m.Lookup))
                return primary;
            if (primary != null)
            {
                var resolved = MappingReader.ResolveTarget(svc, trace, m, primary, primaryCache);
                if (resolved != null) return resolved;
            }
            if (string.Equals(m.Table, "contact", StringComparison.OrdinalIgnoreCase) && relatedContact != null)
                return relatedContact;
            return null;
        }

        private static string ReadDisplayValue(
            IOrganizationService svc, ITracingService trace,
            EntityReference src, string column, Dictionary<string, Entity> sourceCache)
        {
            var key = src.LogicalName + ":" + src.Id;
            if (!sourceCache.TryGetValue(key, out var rec))
            {
                try { rec = svc.Retrieve(src.LogicalName, src.Id, new ColumnSet(true)); }
                catch (Exception ex) { trace.Trace("Source {0} load failed: {1}", key, ex.Message); rec = null; }
                sourceCache[key] = rec;
            }
            if (rec == null) return null;
            if (!rec.Contains(column) || rec[column] == null) return "";

            if (rec.FormattedValues.Contains(column) && !string.IsNullOrEmpty(rec.FormattedValues[column]))
                return rec.FormattedValues[column];

            var v = rec[column];
            switch (v)
            {
                case string s: return s;
                case EntityReference er: return er.Name ?? er.Id.ToString();
                case Money mo: return mo.Value.ToString(System.Globalization.CultureInfo.InvariantCulture);
                case OptionSetValue os: return os.Value.ToString();
                case bool b: return b ? "true" : "false";
                case DateTime dt: return dt.ToString("o", System.Globalization.CultureInfo.InvariantCulture);
                default: return Convert.ToString(v, System.Globalization.CultureInfo.InvariantCulture);
            }
        }

        // Minimal JSON string builder (no external dependency).
        private static string BuildItem(string name, string value, bool readOnly)
        {
            var sb = new StringBuilder();
            sb.Append("{\"name\":").Append(JsonString(name));
            sb.Append(",\"content_value\":").Append(JsonString(value));
            sb.Append(",\"read_only\":").Append(readOnly ? "true" : "false");
            sb.Append("}");
            return sb.ToString();
        }

        private static string JsonString(string s)
        {
            if (s == null) return "\"\"";
            var sb = new StringBuilder("\"");
            foreach (var c in s)
            {
                switch (c)
                {
                    case '\"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < ' ') sb.Append("\\u").Append(((int)c).ToString("x4"));
                        else sb.Append(c);
                        break;
                }
            }
            sb.Append("\"");
            return sb.ToString();
        }
    }
}
