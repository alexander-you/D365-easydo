/*
  EasyDo.Plugins  -  shared field-mapping reader.

  Reads the alex_templatefieldmapping rows for a template and resolves the
  source / target record for each mapping using the template's primary table,
  the request's primary record anchor (alex_primaryrecordid), and at most one
  lookup hop (alex_lookupfield) on the primary record.
*/
using System;
using System.Collections.Generic;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    internal static class Direction
    {
        public const int Prefill = 626210000;
        public const int ReadBack = 626210001;
        public const int Bidirectional = 626210002;

        public static bool AllowsPrefill(int? d) => d == Prefill || d == Bidirectional || d == null;
        public static bool AllowsReadBack(int? d) => d == ReadBack || d == Bidirectional;
    }

    internal sealed class FieldMapping
    {
        public string ExternalId;     // alex_externalfieldid  (easydo field technical name)
        public string ExternalName;   // alex_externalfieldname (binding header)
        public string Lookup;         // alex_lookupfield  (lookup on primary table; empty = direct)
        public string Table;          // alex_dynamicstable (target table the column lives on)
        public string Column;         // alex_dynamicsfield
        public bool ReadOnly;         // alex_isreadonly
        public int? DirectionValue;   // alex_direction
    }

    internal static class MappingReader
    {
        public static List<FieldMapping> ForTemplate(IOrganizationService svc, Guid templateId)
        {
            var q = new QueryExpression("alex_templatefieldmapping")
            {
                ColumnSet = new ColumnSet(
                    "alex_externalfieldid", "alex_externalfieldname", "alex_lookupfield",
                    "alex_dynamicstable", "alex_dynamicsfield", "alex_isreadonly", "alex_direction"),
                NoLock = true
            };
            q.Criteria.AddCondition("alex_templateid", ConditionOperator.Equal, templateId);

            var list = new List<FieldMapping>();
            foreach (var e in svc.RetrieveMultiple(q).Entities)
            {
                list.Add(new FieldMapping
                {
                    ExternalId = e.GetAttributeValue<string>("alex_externalfieldid"),
                    ExternalName = e.GetAttributeValue<string>("alex_externalfieldname"),
                    Lookup = e.GetAttributeValue<string>("alex_lookupfield"),
                    Table = e.GetAttributeValue<string>("alex_dynamicstable"),
                    Column = e.GetAttributeValue<string>("alex_dynamicsfield"),
                    ReadOnly = e.GetAttributeValue<bool>("alex_isreadonly"),
                    DirectionValue = e.GetAttributeValue<OptionSetValue>("alex_direction")?.Value
                });
            }
            return list;
        }

        /// <summary>
        /// Resolve the record a mapping points at, given the primary record. For a
        /// direct mapping that is the primary record itself; for a single-hop
        /// mapping it is the record referenced by the lookup field on the primary
        /// record. Returns null when the lookup is empty/unset on the record.
        /// </summary>
        public static EntityReference ResolveTarget(
            IOrganizationService svc, ITracingService trace,
            FieldMapping m, EntityReference primary,
            Dictionary<string, Entity> primaryCache)
        {
            if (string.IsNullOrEmpty(m.Lookup))
                return primary; // direct on the primary record

            // Load (and cache) the primary record with the lookup column.
            var key = primary.LogicalName + ":" + primary.Id;
            if (!primaryCache.TryGetValue(key, out var rec))
            {
                try
                {
                    rec = svc.Retrieve(primary.LogicalName, primary.Id, new ColumnSet(true));
                }
                catch (Exception ex)
                {
                    trace.Trace("Could not load primary record {0}: {1}", key, ex.Message);
                    rec = null;
                }
                primaryCache[key] = rec;
            }
            if (rec == null) return null;

            var er = rec.GetAttributeValue<EntityReference>(m.Lookup);
            if (er == null)
            {
                trace.Trace("Lookup '{0}' is empty on {1}; skipping field {2}.", m.Lookup, key, m.ExternalId);
                return null;
            }
            // If the mapping declares a target table, trust the actual reference.
            return er;
        }
    }
}
