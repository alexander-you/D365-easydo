/*
  EasyDo.Plugins  -  shared value conversion.

  Converts the string values that come from / go to the easydo form into the
  CLR types Dataverse expects for a given target column, based on that column's
  attribute metadata. Attribute metadata is retrieved once and cached for the
  lifetime of the plugin execution (per organization service call).
*/
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using Microsoft.Xrm.Sdk.Metadata;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    internal sealed class ValueConverter
    {
        private readonly IOrganizationService _svc;
        private readonly ITracingService _trace;
        private readonly Dictionary<string, AttributeMetadata> _cache =
            new Dictionary<string, AttributeMetadata>(StringComparer.OrdinalIgnoreCase);

        public ValueConverter(IOrganizationService svc, ITracingService trace)
        {
            _svc = svc;
            _trace = trace;
        }

        private AttributeMetadata GetAttribute(string entity, string attribute)
        {
            var key = entity + "." + attribute;
            if (_cache.TryGetValue(key, out var cached)) return cached;

            var req = new RetrieveAttributeRequest
            {
                EntityLogicalName = entity,
                LogicalName = attribute,
                RetrieveAsIfPublished = true
            };
            var resp = (RetrieveAttributeResponse)_svc.Execute(req);
            _cache[key] = resp.AttributeMetadata;
            return resp.AttributeMetadata;
        }

        /// <summary>
        /// Convert a raw string to the value expected by the target column.
        /// Returns true and sets <paramref name="value"/> when a value should be
        /// written (null clears the column); returns false to skip the column.
        /// </summary>
        public bool TryConvert(string entity, string attribute, string raw, out object value)
        {
            value = null;
            AttributeMetadata meta;
            try { meta = GetAttribute(entity, attribute); }
            catch (Exception ex)
            {
                _trace.Trace("Metadata for {0}.{1} failed: {2}", entity, attribute, ex.Message);
                return false;
            }

            if (raw == null) { value = null; return true; }

            switch (meta.AttributeType)
            {
                case AttributeTypeCode.String:
                case AttributeTypeCode.Memo:
                    value = raw;
                    return true;

                case AttributeTypeCode.Boolean:
                    value = ParseBool(raw);
                    return true;

                case AttributeTypeCode.DateTime:
                    if (TryParseDate(raw, out var dt)) { value = dt; return true; }
                    return false;

                case AttributeTypeCode.Integer:
                    if (int.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var i)) { value = i; return true; }
                    return false;

                case AttributeTypeCode.BigInt:
                    if (long.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var l)) { value = l; return true; }
                    return false;

                case AttributeTypeCode.Decimal:
                    if (decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var dec)) { value = dec; return true; }
                    return false;

                case AttributeTypeCode.Double:
                    if (double.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var dbl)) { value = dbl; return true; }
                    return false;

                case AttributeTypeCode.Money:
                    if (decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var m)) { value = new Money(m); return true; }
                    return false;

                case AttributeTypeCode.Picklist:
                case AttributeTypeCode.State:
                case AttributeTypeCode.Status:
                    if (TryMatchOption(meta, raw, out var osv)) { value = osv; return true; }
                    return false;

                case AttributeTypeCode.Uniqueidentifier:
                    if (Guid.TryParse(raw, out var g)) { value = g; return true; }
                    return false;

                case AttributeTypeCode.Lookup:
                case AttributeTypeCode.Customer:
                case AttributeTypeCode.Owner:
                    if (TryResolveLookup(meta as LookupAttributeMetadata, raw, out var er)) { value = er; return true; }
                    return false;

                default:
                    _trace.Trace("Unsupported type {0} for {1}.{2}; skipped.", meta.AttributeType, entity, attribute);
                    return false;
            }
        }

        private static bool ParseBool(string raw)
        {
            var s = (raw ?? "").Trim().ToLowerInvariant();
            return s == "checked" || s == "true" || s == "1" || s == "yes" || s == "on" || s == "כן";
        }

        private static bool TryParseDate(string raw, out DateTime dt)
        {
            if (DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out dt))
                return true;
            if (DateTime.TryParse(raw, CultureInfo.CurrentCulture, DateTimeStyles.AssumeLocal, out dt))
                return true;
            return false;
        }

        private static bool TryMatchOption(AttributeMetadata meta, string raw, out OptionSetValue osv)
        {
            osv = null;
            OptionMetadataCollection options = null;
            if (meta is PicklistAttributeMetadata p) options = p.OptionSet?.Options;
            else if (meta is StateAttributeMetadata s) options = s.OptionSet?.Options;
            else if (meta is StatusAttributeMetadata st) options = st.OptionSet?.Options;
            if (options == null) return false;

            // Match by numeric value first, then by localized label (case-insensitive).
            if (int.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var num)
                && options.Any(o => o.Value == num))
            {
                osv = new OptionSetValue(num);
                return true;
            }
            var target = (raw ?? "").Trim();
            var match = options.FirstOrDefault(o =>
                o.Label?.UserLocalizedLabel != null &&
                string.Equals(o.Label.UserLocalizedLabel.Label, target, StringComparison.OrdinalIgnoreCase));
            if (match == null)
            {
                match = options.FirstOrDefault(o => o.Label != null && o.Label.LocalizedLabels.Any(ll =>
                    string.Equals(ll.Label, target, StringComparison.OrdinalIgnoreCase)));
            }
            if (match?.Value != null) { osv = new OptionSetValue(match.Value.Value); return true; }
            return false;
        }

        private bool TryResolveLookup(LookupAttributeMetadata meta, string raw, out EntityReference er)
        {
            er = null;
            if (meta?.Targets == null || meta.Targets.Length == 0) return false;
            var target = (raw ?? "").Trim();
            if (target.Length == 0) return false;

            // Allow passing a GUID directly (first target).
            if (Guid.TryParse(target, out var gid))
            {
                er = new EntityReference(meta.Targets[0], gid);
                return true;
            }

            // Otherwise resolve by primary-name field on each candidate target.
            foreach (var t in meta.Targets)
            {
                string primaryName;
                try { primaryName = GetPrimaryNameAttribute(t); }
                catch { continue; }
                if (string.IsNullOrEmpty(primaryName)) continue;

                var q = new QueryExpression(t)
                {
                    ColumnSet = new ColumnSet(false),
                    TopCount = 2,
                    NoLock = true
                };
                q.Criteria.AddCondition(primaryName, ConditionOperator.Equal, target);
                var res = _svc.RetrieveMultiple(q);
                if (res.Entities.Count == 1)
                {
                    er = new EntityReference(t, res.Entities[0].Id);
                    return true;
                }
            }
            _trace.Trace("Lookup value '{0}' could not be resolved to a single record.", raw);
            return false;
        }

        private readonly Dictionary<string, string> _primaryNameCache =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        private string GetPrimaryNameAttribute(string entity)
        {
            if (_primaryNameCache.TryGetValue(entity, out var cached)) return cached;
            var req = new RetrieveEntityRequest
            {
                LogicalName = entity,
                EntityFilters = EntityFilters.Entity,
                RetrieveAsIfPublished = true
            };
            var resp = (RetrieveEntityResponse)_svc.Execute(req);
            var name = resp.EntityMetadata.PrimaryNameAttribute;
            _primaryNameCache[entity] = name;
            return name;
        }
    }
}
