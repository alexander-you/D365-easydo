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
  Created = false.

  ALM-safe solution targeting: the relationship must be added to an UNMANAGED
  solution. The base solution (alex_d365_easydo) is installed managed on customer
  environments, and a managed solution cannot receive new components. The plugin
  therefore resolves a writable target:
     - base solution unmanaged -> use it (clean ALM, e.g. the dev environment);
     - base solution managed   -> ensure/create a dedicated unmanaged solution
                                  (alex_d365_easydo_runtime) and warn the admin;
     - cannot create one        -> leave the component in the Default solution.
  It never swallows an OrganizationService failure and continues - doing so
  aborts the platform transaction ("ISV code reduced the open transaction count").

  Output parameter Warning (String) carries any ALM advisory back to the UI.
*/
using System;
using Microsoft.Crm.Sdk.Messages;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Messages;
using Microsoft.Xrm.Sdk.Metadata;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class EnsureSignatureLookupPlugin : PluginBase
    {
        private const string RequestEntity = "alex_signaturerequest";
        private const string PrimarySolution = "alex_d365_easydo";
        private const string RuntimeSolution = "alex_d365_easydo_runtime";
        private const string RuntimeSolutionFriendly = "D365 easydo - Runtime Customizations";

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

            // Add the new relationship to a WRITABLE (unmanaged) solution so it travels
            // with ALM. A managed base solution cannot receive components, so resolve a
            // safe target. We do NOT swallow an OrganizationService failure and continue:
            // doing so aborts the platform transaction.
            string warning;
            var targetSolution = ResolveTargetSolution(svc, trace, out warning);

            if (!string.IsNullOrEmpty(targetSolution))
            {
                svc.Execute(new AddSolutionComponentRequest
                {
                    ComponentType = 10, // Entity Relationship
                    ComponentId = createResp.RelationshipId,
                    SolutionUniqueName = targetSolution,
                    AddRequiredComponents = false
                });
                trace.Trace("EnsureSignatureLookup: relationship added to solution '{0}'.", targetSolution);
            }
            else
            {
                trace.Trace("EnsureSignatureLookup: relationship left in the Default solution.");
            }

            ctx.OutputParameters["TargetSolution"] = targetSolution ?? "Default";
            ctx.OutputParameters["Warning"] = warning ?? string.Empty;
            ctx.OutputParameters["Created"] = true;
        }

        // Resolves an UNMANAGED solution the new relationship can be added to.
        // Returns null to mean "leave the component in the Default solution".
        //
        // CRITICAL: a plug-in must never make an OrganizationService call that is
        // expected to fail. A caught OrganizationService fault still aborts the whole
        // platform transaction ("ISV code reduced the open transaction count"), which
        // would roll back the lookup we just created. So we only attempt to create the
        // runtime solution when we KNOW its publisher is writable; on a managed customer
        // install the base publisher is read-only, and we fall back to the Default
        // solution WITHOUT a doomed call.
        private static string ResolveTargetSolution(IOrganizationService svc, ITracingService trace, out string warning)
        {
            warning = null;

            var primary = RetrieveSolution(svc, PrimarySolution);
            if (primary != null && !primary.IsManaged)
                return PrimarySolution; // unmanaged base (e.g. dev): keep ALM clean.

            // Base solution is managed (or missing) -> it cannot receive new components.
            var runtime = RetrieveSolution(svc, RuntimeSolution);
            if (runtime != null && !runtime.IsManaged)
            {
                warning = "Base solution '" + PrimarySolution + "' is managed; the relationship was added to the " +
                          "unmanaged solution '" + RuntimeSolution + "'. Track this solution in your ALM/source control.";
                return RuntimeSolution;
            }

            // We would like a dedicated unmanaged runtime solution, but creating one is
            // only possible when the base publisher is writable. On a managed customer
            // install the publisher is read-only and the create would throw - poisoning
            // the transaction and losing the lookup. Check FIRST, and only create when
            // we know it will succeed.
            if (primary != null && primary.PublisherId != Guid.Empty && IsPublisherWritable(svc, trace, primary.PublisherId))
            {
                var sol = new Entity("solution");
                sol["uniquename"] = RuntimeSolution;
                sol["friendlyname"] = RuntimeSolutionFriendly;
                sol["version"] = "1.0.0.0";
                sol["publisherid"] = new EntityReference("publisher", primary.PublisherId);
                svc.Create(sol);
                trace.Trace("EnsureSignatureLookup: created unmanaged runtime solution '{0}'.", RuntimeSolution);
                warning = "Base solution '" + PrimarySolution + "' is managed. A new unmanaged solution '" +
                          RuntimeSolution + "' was created automatically to hold signature-request relationships " +
                          "made on this environment. New relationships will be added there from now on - include it in your ALM.";
                return RuntimeSolution;
            }

            // Publisher is read-only (managed install) or unavailable: leave the
            // relationship in the Default solution. It still exists org-wide, so the
            // native subgrid on the source record works; it is simply not packaged in a
            // named unmanaged solution (these per-table relationships are environment-
            // specific and are stripped from the managed export anyway - see script 62).
            trace.Trace("EnsureSignatureLookup: base publisher not writable; leaving relationship in the Default solution.");
            warning = "The base publisher is read-only (managed install), so the relationship was left in the " +
                      "Default solution. It is fully functional; it is simply not packaged in a named solution.";
            return null;
        }

        // Returns true when the publisher can receive new solutions/components. A
        // read-only publisher (e.g. one that arrived via a managed solution import)
        // cannot, and creating a solution under it would throw and abort the whole
        // plug-in transaction - so this MUST be checked BEFORE attempting the create.
        private static bool IsPublisherWritable(IOrganizationService svc, ITracingService trace, Guid publisherId)
        {
            var publisher = svc.Retrieve("publisher", publisherId, new ColumnSet("isreadonly"));
            var readOnly = publisher.GetAttributeValue<bool>("isreadonly");
            trace.Trace("EnsureSignatureLookup: publisher {0} isreadonly={1}.", publisherId, readOnly);
            return !readOnly;
        }

        private static SolutionInfo RetrieveSolution(IOrganizationService svc, string uniqueName)
        {
            var q = new QueryExpression("solution")
            {
                ColumnSet = new ColumnSet("solutionid", "ismanaged", "publisherid"),
                TopCount = 1
            };
            q.Criteria.AddCondition("uniquename", ConditionOperator.Equal, uniqueName);

            var res = svc.RetrieveMultiple(q);
            if (res.Entities.Count == 0) return null;

            var e = res.Entities[0];
            return new SolutionInfo
            {
                IsManaged = e.GetAttributeValue<bool>("ismanaged"),
                PublisherId = e.Contains("publisherid") ? ((EntityReference)e["publisherid"]).Id : Guid.Empty
            };
        }

        private sealed class SolutionInfo
        {
            public bool IsManaged;
            public Guid PublisherId;
        }

        private static bool AttributeExists(IOrganizationService svc, ITracingService trace, string logical)
        {
            var response = (RetrieveEntityResponse)svc.Execute(new RetrieveEntityRequest
            {
                LogicalName = RequestEntity,
                EntityFilters = EntityFilters.Attributes,
                RetrieveAsIfPublished = true
            });

            foreach (var attribute in response.EntityMetadata.Attributes)
            {
                if (string.Equals(attribute.LogicalName, logical, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        private static EntityMetadata RetrieveEntityMeta(IOrganizationService svc, ITracingService trace, string logical)
        {
            var resp = (RetrieveEntityResponse)svc.Execute(new RetrieveEntityRequest
            {
                LogicalName = logical,
                EntityFilters = EntityFilters.Entity,
                RetrieveAsIfPublished = true
            });
            return resp.EntityMetadata;
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
