/*
  EasyDo.Plugins  -  TenantContractCalcPlugin

  Pre-operation plug-in on alex_tenant_contract (Create + Update) that computes
  two derived values in-pipeline (so they persist without an extra Update):

      alex_n_contract_months = whole calendar months between alex_dt_start and
                               alex_dt_end (end - start).
      alex_m_total_contract  = alex_m_monthly_rent * alex_n_contract_months.

  These behave like calculated fields: they are recomputed on every relevant
  save and are shown read-only on the form. Dataverse does not support defining
  real Calculated/Formula columns through the Web API, and Power Fx formula
  columns cannot output a Currency (Money) type - hence this plug-in.

  Runs pre-operation so the values are set on the Target with no extra service
  call. On Update the Target only carries changed columns, so the missing inputs
  are read from the stored row.
*/
using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace EasyDo.Plugins
{
    public sealed class TenantContractCalcPlugin : PluginBase
    {
        public TenantContractCalcPlugin(string unsecure, string secure) : base(typeof(TenantContractCalcPlugin)) { }

        private const string Table = "alex_tenant_contract";
        private const string StartCol = "alex_dt_start";
        private const string EndCol = "alex_dt_end";
        private const string MonthsCol = "alex_n_contract_months";
        private const string RentCol = "alex_m_monthly_rent";
        private const string TotalCol = "alex_m_total_contract";

        protected override void ExecuteDataversePlugin(ILocalPluginContext local)
        {
            if (local == null) throw new ArgumentNullException(nameof(local));
            var ctx = local.PluginExecutionContext;
            var trace = local.TracingService;
            var svc = local.PluginUserService;

            if (!ctx.InputParameters.Contains("Target") || !(ctx.InputParameters["Target"] is Entity target))
                return;

            var isUpdate = string.Equals(ctx.MessageName, "Update", StringComparison.OrdinalIgnoreCase);

            DateTime? start = target.GetAttributeValue<DateTime?>(StartCol);
            DateTime? end = target.GetAttributeValue<DateTime?>(EndCol);
            Money rent = target.GetAttributeValue<Money>(RentCol);
            bool haveRent = target.Contains(RentCol);

            // On Update the Target holds only changed columns - pull the rest from the row.
            if (isUpdate && (start == null || end == null || !haveRent))
            {
                Entity stored = null;
                try
                {
                    stored = svc.Retrieve(Table, target.Id, new ColumnSet(StartCol, EndCol, RentCol));
                }
                catch (Exception ex)
                {
                    trace.Trace("TenantContractCalc: could not load {0}: {1}", target.Id, ex.Message);
                }
                if (stored != null)
                {
                    if (start == null) start = stored.GetAttributeValue<DateTime?>(StartCol);
                    if (end == null) end = stored.GetAttributeValue<DateTime?>(EndCol);
                    if (!haveRent) rent = stored.GetAttributeValue<Money>(RentCol);
                }
            }

            if (start == null || end == null)
            {
                trace.Trace("TenantContractCalc: start/end missing; nothing to compute.");
                return;
            }

            int months = ((end.Value.Year - start.Value.Year) * 12) + (end.Value.Month - start.Value.Month);
            if (months < 0) months = 0;
            target[MonthsCol] = months;
            trace.Trace("TenantContractCalc: months={0}", months);

            decimal? rentValue = rent?.Value;
            if (rentValue != null)
            {
                var total = rentValue.Value * months;
                target[TotalCol] = new Money(total);
                trace.Trace("TenantContractCalc: total={0}", total);
            }
        }
    }
}
