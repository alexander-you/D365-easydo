/*
  EasyDo.Plugins  -  EnsureSignatureLookupPlugin

  Backs the alex_EnsureSignatureLookup Custom API. Given a primary business
  table (e.g. "account"), it provisions the dedicated, native N:1 lookup from
  alex_signaturerequest back to that table - the same convention used by
  22-create-related-record-lookups.ps1 and consumed by PopulateAnchorPlugin:

      schema        = alex_Related<Pascal(table)>Id   (e.g. alex_RelatedAccountId)
      logical       = alex_related<table>id           (e.g. alex_relatedaccountid)
      relationship  = alex_<table>_signaturerequest    referenced=<table>,
                                                        referencing=alex_signaturerequest

  This lets a record of <table> show a real subgrid of its signature requests.

  Creating a relationship is a metadata operation that is NOT easily reversible,
  which is why the admin center warns the user and asks for explicit confirmation
  before calling this API.

  Input  parameter : TableLogicalName        (String, required)
  Output parameters: RelationshipSchemaName  (String)  - the relationship schema name
                     LookupLogicalName        (String)  - the lookup column logical name
                     Created                  (Boolean) - true when newly created by this call

  Idempotent: if the lookup already exists the call is a no-op and returns
  Created = false. The new relationship is added to the alex_d365_easydo solution.
*/
using System;
using Microsoft.Crm.Sdk.Messages;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using Microsoft.Xrm.Sdk.Metadata;

namespace EasyDo.Plugins
{
    public sealed class EnsureSignatureLookupPlugin : PluginBase
    {
        private const string RequestEntity = "alex_signaturerequest";
        private const string SolutionUniqueName = "alex_d365_easydo";

        public EnsureSignatureLookupPlugin(string unsecure, string secure) : base(typeof(EnsureSignatureLookupPlugin)) { }

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;
            var svc = local.PluginUserService;

            var tableRaw = ctx.InputParameters.Contains("TableLogicalName")
                ? ctx.InputParameters["TableLogicalName"] as string
                : null;
            if (string.IsNullOrWhiteSpace(tableRaw))
                throw new InvalidPluginExecutionException("TableLogicalName is required.");

            var table = tableRaw.Trim().ToLowerInvariant();
            if (table == RequestEntity)
                throw new InvalidPluginExecutionException("Cannot create a signature-request lookup that points to the signature request table itself.");

            var pascal = ToPascal(table);
            var schemaName = "alex_Related" + pascal + "Id";
            var lookupLogical = ("alex_related" + table.Replace("_", string.Empty) + "id").ToLowerInvariant();
            var relationshipName = "alex_" + table + "_signaturerequest";

            ctx.OutputParameters["RelationshipSchemaName"] = relationshipName;
            ctx.OutputParameters["LookupLogicalName"] = lookupLogical;

            // Idempotency: if the lookup column already exists, do nothing.
            if (AttributeExists(svc, trace, lookupLogical))
            {
                trace.Trace("EnsureSignatureLookup: lookup {0} already exists; no-op.", lookupLogical);
                ctx.OutputParameters["Created"] = false;
                return;
            }

            // Validate the referenced table exists before touching metadata.
            var meta = RetrieveEntityMeta(svc, trace, table);
            if (meta == null)
                throw new InvalidPluginExecutionException("Table '" + table + "' was not found.");

            // Guard: the signed PDF is returned as a note (annotation) on the source
            // record, so the table MUST have notes/attachments enabled - otherwise the
            // signed document could never be written back. Refuse to enable it.
            if (meta.HasNotes != true)
                throw new InvalidPluginExecutionException(
                    "Table '" + table + "' does not have notes/attachments (timeline) enabled, " +
                    "so the signed document could not be returned to the record. Enable 'Attachments (including notes and files)' on the table first.");

            var rel = new OneToManyRelationshipMetadata
            {
                SchemaName = relationshipName,
                ReferencedEntity = table,
                ReferencingEntity = RequestEntity,
                CascadeConfiguration = new CascadeConfiguration
                {
                    Assign = CascadeType.NoCascade,
                    Delete = CascadeType.RemoveLink,
                    Merge = CascadeType.NoCascade,
                    Reparent = CascadeType.NoCascade,
                    Share = CascadeType.NoCascade,
                    Unshare = CascadeType.NoCascade
                }
            };

            var lookup = new LookupAttributeMetadata
            {
                SchemaName = schemaName,
                DisplayName = new Label(pascal + " (signature source)", 1033),
                Description = new Label("Source " + table + " record this signature request was sent from.", 1033),
                RequiredLevel = new AttributeRequiredLevelManagedProperty(AttributeRequiredLevel.None)
            };

            var createReq = new CreateOneToManyRequest
            {
                OneToManyRelationship = rel,
                Lookup = lookup
            };

            CreateOneToManyResponse createResp;
            try
            {
                createResp = (CreateOneToManyResponse)svc.Execute(createReq);
            }
            catch (Exception ex)
            {
                trace.Trace("EnsureSignatureLookup: create relationship failed: {0}", ex.Message);
                throw new InvalidPluginExecutionException("Failed to create the signature-request lookup for '" + table + "': " + ex.Message, ex);
            }

            trace.Trace("EnsureSignatureLookup: created relationship {0} (attribute id {1}).",
                relationshipName, createResp.AttributeId);

            // Add the new relationship to the easydo solution so it travels with ALM.
            try
            {
                svc.Execute(new AddSolutionComponentRequest
                {
                    ComponentType = 10, // Entity Relationship
                    ComponentId = createResp.RelationshipId,
                    SolutionUniqueName = SolutionUniqueName,
                    AddRequiredComponents = false
                });
            }
            catch (Exception ex)
            {
                // Non-fatal: the lookup is live even if solution add fails.
                trace.Trace("EnsureSignatureLookup: AddSolutionComponent failed (non-fatal): {0}", ex.Message);
            }

            ctx.OutputParameters["Created"] = true;
        }

        private static bool AttributeExists(IOrganizationService svc, ITracingService trace, string logical)
        {
            try
            {
                svc.Execute(new RetrieveAttributeRequest
                {
                    EntityLogicalName = RequestEntity,
                    LogicalName = logical,
                    RetrieveAsIfPublished = true
                });
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static EntityMetadata RetrieveEntityMeta(IOrganizationService svc, ITracingService trace, string logical)
        {
            try
            {
                var resp = (RetrieveEntityResponse)svc.Execute(new RetrieveEntityRequest
                {
                    LogicalName = logical,
                    EntityFilters = EntityFilters.Entity,
                    RetrieveAsIfPublished = true
                });
                return resp.EntityMetadata;
            }
            catch (Exception ex)
            {
                trace.Trace("EnsureSignatureLookup: entity metadata for {0} failed: {1}", logical, ex.Message);
                return null;
            }
        }

        // contact -> Contact, alex_foo -> AlexFoo (mirrors ConvertTo-Pascal in script 22).
        private static string ToPascal(string logical)
        {
            if (string.IsNullOrEmpty(logical)) return logical;
            var parts = logical.Split(new[] { '_' }, StringSplitOptions.RemoveEmptyEntries);
            var sb = new System.Text.StringBuilder();
            foreach (var p in parts)
                sb.Append(char.ToUpperInvariant(p[0])).Append(p.Substring(1));
            return sb.ToString();
        }
    }
}
