# DocuSign Power Automate Connector Capabilities

Date: 2026-06-19

Scope: research note only. This document summarizes DocuSign Power Automate connector behavior relevant to template-driven sending, recipient roles, tabs, prefill tabs, envelope custom fields, and how those capabilities compare to the custom Dynamics 365 easydo template field mapping experience in this repository.

## Executive summary

The DocuSign connector supports a richer out-of-box Power Automate designer experience than a basic custom connector: templates, accounts, folders, signing groups, recipient types, account custom fields, and several action bodies are exposed through dynamic dropdowns or dynamic schemas. The most relevant action is **Create envelope using template with recipients and tabs**, whose recipient body is a dynamic schema derived from the selected account and template.

That dynamic designer experience is useful for maker-authored flows against known templates. It does not remove the need for a separate mapping layer when the template, source table, fields, or target record are selected at runtime. If the template ID is supplied dynamically, the designer cannot reliably pre-render template-specific recipient and tab inputs, because the connector's dynamic schema depends on a concrete template selection at design time. At runtime, however, the underlying connector actions and eSignature API still accept JSON payloads, so a flow or plugin can construct the recipient, tab, prefill-tab, and custom-field payloads dynamically if it has already resolved the correct role names, tab IDs/labels, document IDs, and values.

Conceptually, the custom Dynamics 365 easydo mapping experience remains valuable even if DocuSign is used instead of easydo. DocuSign can expose template fields and update values; Dynamics still needs a business-facing place to decide which Dataverse source fields map to which signing-service tabs, which fields are read-only/prefill, which fields are read-back/write-back, and how to resolve those values at runtime.

## Sources checked

- Microsoft connector reference: `https://learn.microsoft.com/en-us/connectors/docusign/`
- Published connector definition: `https://raw.githubusercontent.com/microsoft/PowerPlatformConnectors/dev/certified-connectors/DocuSign/apiDefinition.swagger.json`
- DocuSign Power Automate guide: `https://support.docusign.com/en/guides/DocuSign-eSignature-for-Microsoft-Power-Automate`
- DocuSign templates concept: `https://developers.docusign.com/docs/esign-rest-api/esign101/concepts/templates/`
- DocuSign tabs concept: `https://developers.docusign.com/docs/esign-rest-api/esign101/concepts/tabs/`
- DocuSign prefilled tabs concept: `https://developers.docusign.com/docs/esign-rest-api/esign101/concepts/tabs/prefilled-tabs/`
- DocuSign template-send how-to: `https://developers.docusign.com/docs/esign-rest-api/how-to/request-signature-template-remote/`
- DocuSign set envelope tab values how-to: `https://developers.docusign.com/docs/esign-rest-api/how-to/set-envelope-tab-values/`

## Connector capabilities by area

### Template selection

The connector exposes **List templates** and uses it as a dynamic dropdown for template parameters. In the published connector definition, template inputs use `x-ms-dynamic-values` with operation `GetEnvelopeTemplates`, with `templateId` as the value and template `name` as the display title.

Relevant actions include:

| Action | What it does | Notes |
| --- | --- | --- |
| **List templates** | Lists templates for an account. | Drives template dropdowns. |
| **Create envelope using template** | Creates an envelope from a template with no recipients supplied in that action. | Useful for draft or follow-up recipient operations. |
| **Create envelope using template with recipients** | Creates an envelope from a template and supplies signers. | Uses a dynamic signer schema based on selected template. |
| **Create envelope using template with recipients and tabs** | Creates an envelope from a template with recipients and tab values. | Most relevant for template field mapping. Uses a dynamic recipient schema based on selected template. |
| **Create envelope using composite templates** | Creates an envelope using a composite-template body. | More flexible for fully dynamic or multi-template scenarios, but the body is more JSON-centric. |
| **Apply a template to documents** | Applies a template to one or more documents already in an envelope. | Useful when documents are generated or uploaded at runtime. |

Designer behavior: when the maker picks a concrete template in the action card, the connector can ask DocuSign for the template's recipient/role structure and render fields accordingly. If the template ID is an expression from a previous step, the action can still run, but the Power Automate designer cannot know which template-specific fields to render at design time.

Runtime behavior: a flow can dynamically pass a template ID as a string and can construct the body dynamically. The responsibility shifts from the connector designer UI to the flow/plugin/data model: the implementation must know or retrieve the template roles, tab IDs/labels, document IDs, and value payload shape.

### Dynamic recipient roles

DocuSign templates define generic recipient roles rather than final people. When an envelope is created from a template, the sender supplies actual recipients for those roles, including fields such as name, email, role name, recipient ID, routing/signing order, delivery method, embedded signer options, signing group, and verification settings.

Connector support includes:

- **Create envelope using template with recipients**: signer body uses a `DynamicSigners` schema generated by `GetDynamicSigners` for the selected account/template.
- **Create envelope using template with recipients and tabs**: recipient body uses a `DynamicRecipients` schema generated by `GetDynamicRecipients` for the selected account/template.
- **Add recipient to an envelope (V2)** and **Update recipient on an envelope**: support runtime recipient operations, including `roleName`, `routingOrder`, `recipientType`, embedded recipient parameters, signing groups, SMS, and verification-related parameters.
- **List recipients from envelope** and **Get recipient info from envelope**: allow runtime discovery of recipient IDs and recipient state.

Designer behavior: for a selected template, recipient role inputs can appear as named fields in the action card. This is good for a flow built for one known template.

Runtime behavior: recipient roles can be resolved dynamically by storing the role name in Dataverse or reading template metadata, then constructing the recipient object at send time. If roles vary by template, Dynamics needs mapping/configuration data. This mirrors the current easydo design, where template field/recipient facts are synced into Dataverse and the send flow/plugin resolves them per request.

### Recipient tabs

Tabs are DocuSign's document fields/tags. Most recipient-entered fields are assigned to a specific recipient, and the tab can be identified by properties such as `tabId`, `tabLabel`, `tabType`, `documentId`, `recipientId`, and `value`.

Connector support includes:

- **Get document tabs from template**: retrieves template document tabs for a template/document.
- **Get document tabs from envelope**: retrieves tabs for a document in an envelope.
- **Get recipient tabs from envelope**: retrieves tabs assigned to a recipient in an envelope.
- **Get info for recipient tab**: returns the value for a recipient tab by `tabLabel`.
- **Add tabs for a recipient on an envelope**: adds tabs using a selected tab type and a dynamic anchor-tab schema.
- **Update recipient tab values on an envelope**: updates tab values with an array of `{ tabType, tabId, value }` for a recipient.

Designer behavior: some tab-add/update actions expose dynamic schemas or tab-type dropdowns, but not a fully business-friendly cross-template mapping surface. The designer can help with a known envelope/template structure, but it is not a substitute for a CRM-side field mapping control when the mapping must be maintained by business admins across many templates.

Runtime behavior: tab values can be read and written dynamically if the integration has the tab ID or tab label and the recipient/document context. For robust automation, store stable tab identifiers and labels in Dataverse during template sync, then resolve values from the source record at send time and read completed values back after completion.

### Prefill tabs

DocuSign prefilled tabs are sender-supplied values inserted into a document before recipients act. They are visible to recipients but cannot be edited by them. DocuSign documents them as `prefillTabs` under the `tabs` object, not as a separate conceptual field family outside tabs.

Important behavior:

- Prefilled tabs can be used for Text, Checkbox, Radio, Company, and Name tab types.
- Prefilled tabs are useful when the field is not associated with one particular recipient, or when it must be populated before signing and locked from recipient editing.
- Not all production account plans include prefilled tabs, even though developer/demo accounts may support them.
- With composite templates, prefilled tabs from server and inline templates are merged under documented precedence rules. If duplicate prefilled tabs share the same `tabLabel`, the lower sequence template wins.

Connector support includes:

- **Get document tabs from template/envelope**: returned tab records include an `Is Prefill` / `prefill` boolean.
- **Update envelope prefill tabs**: updates values for prefill tabs on an envelope document with an array containing `tabType`, `tabId`, and `value`.

Designer behavior: the connector can expose prefill-tab update parameters, but the maker still needs the envelope ID, document ID, tab type, and tab ID. This tends to be an implementation detail, not a polished mapping experience.

Runtime behavior: prefill-tab values can be set dynamically after the envelope exists, or included when creating envelopes through lower-level JSON/composite-template patterns. A Dynamics implementation should treat prefill tabs as mapping rows with direction/policy, similar to the current easydo `Prefill` and `Bidirectional` model, but with DocuSign-specific identifiers.

### Envelope custom fields / envelope fields

DocuSign uses envelope custom fields as envelope-level metadata. These are different from document tabs. They are useful for correlation, filtering, reporting, and carrying integration keys such as Dynamics table name, record ID, request ID, environment, or business process name.

Connector support includes:

- **Create envelope** and deprecated template-create variants expose account custom fields through a dynamic `AccountCustomFields` schema generated from account custom field metadata.
- **Get envelope custom field info** gets a custom field by name.
- **Update envelope custom field** updates a custom field by field ID, type, name, and value.
- **List envelopes** can filter by custom field name/value.
- The envelope status trigger payload exposes `customFields` as key/value pairs.

Designer behavior: account custom fields can be exposed dynamically in the designer when the account is selected. They are account-level, not template-tab-level.

Runtime behavior: custom fields can be set and updated dynamically, and are a good place to store correlation IDs. They should not be confused with recipient-entered document data. For document field data, use tabs/prefill tabs and tab read-back actions or Connect payload tab data.

### Dynamic fields in Power Automate designer vs runtime resolution

The connector definition uses two different mechanisms:

| Mechanism | Example | Meaning |
| --- | --- | --- |
| Dynamic values | Account, template, folder, signing group, account custom field dropdowns. | The designer calls another connector operation to populate choices. |
| Dynamic schema | Template-specific signers/recipients, recipient-type-specific extra parameters, anchor-tab schema, composite-template schema, account custom fields. | The designer calls another operation to build the input shape for the action card. |

The practical distinction:

- **Designer-time dynamic exposure** works best when the maker chooses a static account/template/tab type in the action configuration. The action card can then show friendly fields.
- **Runtime dynamic resolution** works when values are expressions or JSON constructed earlier in the flow, but the designer will not necessarily show all template-specific fields. The flow must provide a valid payload shape at execution time.
- **Dynamic schema is not a runtime mapping system.** It improves the maker UX for a chosen template; it does not decide which Dataverse field maps to which DocuSign tab for every business record.

## Comparison to the custom Dynamics 365 template field mapping experience

The current repository's easydo design stores template fields and mapping policy in Dataverse and provides a Dynamics/PCF mapping experience. That pattern remains conceptually sound for DocuSign.

| Capability | DocuSign connector | Custom Dynamics mapping experience |
| --- | --- | --- |
| Template selection | Native dropdown from DocuSign templates; template ID can also be supplied dynamically. | Dataverse template table can hold provider template IDs, names, primary table, and sync state. |
| Recipient roles | Template-specific dynamic schema can expose roles in designer. Runtime recipient objects can be constructed with role names. | Mapping table can store business role policy and resolve recipients from CRM relationships at send time. |
| Recipient tabs | Connector can get template/envelope tabs, get recipient tabs, add tabs, and update recipient tab values. | Mapping UI can let business admins bind each provider tab to Dataverse table/field paths and policies. |
| Prefill tabs | Connector can update envelope prefill tabs; API supports locked sender-supplied prefill values. | Mapping UI can model prefill as direction/policy and resolve values from source records before sending. |
| Envelope custom fields | Connector supports account custom fields and trigger customFields payloads. | Dataverse can standardize correlation fields such as source table, source record, request ID, and environment. |
| Designer dynamic fields | Strong for known templates selected in action cards. Weak for fully runtime-selected templates because the designer cannot pre-render unknown schema. | Strong for runtime flexibility because mapping is data, not flow structure. Requires template sync and runtime resolver. |
| Runtime resolution | Possible via dynamic JSON bodies and separate read/update actions, but needs correct IDs/labels and payload shape. | Purpose-built: mappings, resolver plugin/flow, and write-back rules are evaluated per request. |

## Conceptual implementation guidance

### Recommended architecture if DocuSign is adopted

Use the DocuSign connector for transport and authentication, but keep a Dynamics-owned mapping layer for business configuration and runtime resolution.

Recommended Dataverse concepts:

- **Signature Template**: provider = DocuSign, provider template ID, display name, primary/source table, active flag, last synced on.
- **Template Recipient Mapping**: provider role name, recipient type, source path or fixed recipient policy, routing order, delivery method, embedded/external signing policy.
- **Template Field Mapping**: provider tab ID, tab label, tab type, document ID, recipient role/recipient ID when applicable, prefill flag, Dynamics source table/path/column, direction, read-only/locked policy, required flag, write-back policy.
- **Signature Request**: selected template, source record ID/table, envelope ID, status, sent/completed timestamps, signing links if embedded, correlation custom fields.
- **Signature Field Value**: request-specific resolved values and read-back values, preserving provider identifiers and raw text value.

Recommended flow/plugin pattern:

1. Sync DocuSign templates into Dataverse: template list, documents, template tabs, recipient roles, and account custom fields if needed.
2. Let a business admin map DocuSign roles/tabs to Dataverse source paths in the Dynamics template mapping control.
3. At send time, create or prepare the envelope using a DocuSign template action.
4. Resolve recipients from the source record and configured role mappings.
5. Resolve prefill/recipient-tab values from Dataverse using the mapping table.
6. Send a valid connector payload dynamically, or create a draft envelope and then call update actions for recipient tab values, prefill tabs, and envelope custom fields.
7. Store envelope ID and correlation fields in Dataverse and in DocuSign envelope custom fields.
8. On Connect trigger or polling, read status, recipient tabs, prefill/custom fields as needed, write read-back rows, then apply write-back policy with an allow-list/resolver.

### When to rely on the connector designer directly

Use the built-in dynamic action UI when:

- The flow targets one or a small number of known templates.
- Recipient roles and fields are stable.
- A maker owns the flow and is comfortable updating it when templates change.
- Business users do not need a separate in-Dynamics mapping surface.

### When to use the custom Dynamics mapping model

Use a custom Dynamics mapping model when:

- Templates are selected at runtime.
- Different templates have different role names and tabs.
- Business admins need to manage mappings without editing flows.
- Values must resolve from arbitrary Dataverse tables, direct fields, or lookup paths.
- Read-back/write-back needs governed policy rather than ad hoc flow steps.
- The solution must work consistently across environments and templates without rebuilding the flow for every template.

## Key risks and open verification items

- The connector reference confirms dynamic schemas and relevant actions, but an end-to-end maker test in Power Automate would still be needed to observe exactly how fields render when a static template is selected versus when template ID is supplied by expression.
- Production prefilled-tab support may depend on the DocuSign account plan.
- Tab update actions often require `tabId`, `recipientId`, and `documentId`; template sync must capture stable identifiers and handle template revisions.
- The connector's template-specific dynamic schema improves UX but may be brittle if a template is changed after the flow is authored. A Dataverse template sync process should detect changes and flag mappings needing review.
- Envelope custom fields are metadata. They should be used for correlation and filtering, not as a replacement for document tabs or read-back field data.

## Bottom line

DocuSign's Power Automate connector can expose template roles and fields dynamically in the designer for selected templates, and it can also execute dynamically constructed payloads at runtime. For a Dynamics 365 productized template field mapping experience, the stronger architecture is still to keep mapping and policy in Dataverse, use DocuSign metadata sync to populate that mapping surface, and use runtime resolver logic to build the connector payload. This preserves the maker-friendly connector benefits without tying business mappings to static flow action cards.

## Implementation Plan for easydo Based on the DocuSign Capability Model

### Purpose

This plan describes how to reproduce the relevant DocuSign-like capabilities on top of easydo while preserving the Dynamics-owned mapping model. It is conceptual and architectural only: no connector, flow, plugin, PCF, or Dataverse metadata changes are implied by this document.

The useful DocuSign lesson is not that Power Automate must expose every field dynamically in the designer. The stronger product pattern is that provider metadata is synced into Dataverse, business mappings live as data, and runtime automation resolves recipients and field values from the selected Dynamics record. easydo can support the same pattern with its own API primitives.

### easydo capability baseline

The easydo documentation and live verification in this repository support the following baseline:

| Capability area | easydo behavior | Implementation implication |
| --- | --- | --- |
| API access | API clients are created in easydo API Settings and provide a Client ID and Secret; sandbox uses the sandbox host instead of the production host. | Keep credentials in Power Platform connections/environment configuration. Do not store secrets in solution source. |
| Templates | Templates are created in the easydo website with predetermined fields, settings, and default recipients. The API is recommended for sending documents created from those templates. | Treat easydo as the template authoring system and Dynamics as the send/mapping/control system. |
| Template fields | Template details expose field objects with technical `name`, `id`, type, label/export metadata, required flag, and role information. | Sync provider field metadata into Dataverse mapping rows. Use technical `name` as the send-time key and export header as the read-back/business binding key. |
| Template send | A template can be sent with `POST /entity/me/templates/{templateId}/send`, including assignees and `prefill_data`. | Use template-based send for normal execution; do not download/upload the template PDF as a random document. |
| Draft/preview | `POST /entity/me/templates/{templateId}/form` creates a draft form from a template without sending; signed/complete PDFs are only generated after signed/approved. | Use draft form creation for preview and use signed-PDF download only after completion. |
| Recipients | easydo accepts assignees with existing profile references or ad hoc name/email recipients; sequence controls ordering; only one assignee can be the main `recipient:true`. | Model recipients separately from fields and enforce easydo's main-recipient constraint in the send orchestration. |
| Prefill | Send-time `prefill_data` items use `{ name, content_value, read_only }`; `name` must match the field technical name. | Resolve Dynamics values before send and emit provider-specific prefill rows. Use `read_only:true` for locked values. |
| Read-back | `GET /entity/me/forms/{id}` returns completed field data keyed by `export.header` and a `has_data` indicator. | Store read-back values as request field-value rows, then apply governed write-back policy separately. |
| Status/PDF | Complete PDF exists once status is `signed` or `approved`; waiting/in-progress/declined forms only have draft PDFs. | Poll or webhook status, then download and attach/store the signed PDF only when complete. |
| Webhooks | easydo webhooks are configured in API Settings; Form Submitted fires after all recipients sign/fill. | Polling can remain the baseline; webhooks are an architectural upgrade when an HTTPS receiver is available. |
| Envelopes | Envelopes bundle multiple template documents and notify once all are filled/signed. | Keep single-template send as the core path; model envelopes later as a grouping layer over multiple template mappings. |

### Target architecture

The target architecture should mirror the DocuSign capability model but keep provider specifics isolated:

1. **Provider metadata sync** reads easydo templates and template fields into Dataverse.
2. **Business mapping** lets a Dynamics admin map easydo fields to source-table paths, lock/read-only policy, prefill/read-back direction, and write-back policy.
3. **Runtime resolution** reads the selected source record and mapping rows, resolves values, and builds easydo `prefill_data` at send time.
4. **Template send orchestration** sends an easydo template with assignees, prefill values, and correlation metadata.
5. **Preview orchestration** creates a draft form from the template and surfaces a draft/preview artifact without notifying recipients.
6. **Status/read-back orchestration** polls or receives webhook events, reads completed values, downloads the signed PDF, and stores outcomes in Dataverse.
7. **Compatibility layer** keeps legacy manually entered prefill rows and existing request/status behavior working while adding provider-metadata-driven mapping.

This keeps the same separation of concerns as the DocuSign plan: easydo owns document layout and signing UI; Dataverse owns business mapping, runtime policy, source-record resolution, traceability, and downstream writes.

### Template discovery

Template discovery should be a repeatable sync process, not a one-time maker setup step.

Recommended behavior:

- List available easydo templates for the connected entity.
- Upsert a Dataverse Signature Template row per easydo template.
- Store the easydo template ID, display name, active/sync state, last synced timestamp, provider name, and any available template-level flags such as prefill support.
- Keep Dynamics-specific configuration on the Dataverse row: primary/source table, allowed lookup paths, whether the template is active for send, and owner/admin metadata.
- Detect deleted, renamed, or changed templates by comparing provider IDs and sync timestamps.

DocuSign comparison: DocuSign's connector can populate a template dropdown directly in Power Automate. easydo should instead make template discovery visible in Dynamics because the product goal is runtime template selection and business-admin mapping, not static flow authoring.

### Template field sync

Template field sync is the easydo equivalent of DocuSign template tab discovery.

Recommended behavior:

- For each synced template, retrieve template details and parse the template field list.
- Upsert one Template Field Mapping row per easydo field.
- Store both easydo identifiers:
	- technical field `name` as the send-time prefill key;
	- `export.header` as the read-back key and optional business binding expression.
- Store display label, field type, required flag, role ID if available, provider field GUID, and ordering/grouping metadata if available.
- Preserve admin-owned mapping fields during sync: Dynamics table, lookup field/path, Dynamics column, direction, read-only policy, and write-back policy.
- Mark missing provider fields as inactive or removed rather than deleting mapping rows immediately, so template changes do not silently destroy mapping history.

Field identity rule: for easydo send-time prefill, the stable operational key is the field technical `name`, not the field GUID and not the export header. For easydo read-back, the value map is keyed by export header. The mapping model must store both.

### Recipient and role handling

easydo recipient handling is less role-centric than DocuSign's template-role model, but it can be made role-like in Dynamics.

Recommended behavior:

- Keep Signature Recipient rows as the Dynamics-side recipient plan for each request.
- For simple single-signer templates, map the primary source record or related contact to one assignee with `recipient:true`.
- For multi-recipient scenarios, store sequence/routing order, notification channel, fixed recipient versus resolved recipient, and main-recipient flag.
- Enforce the easydo rule that only one assignee can be marked `recipient:true`.
- Use profile IDs when the recipient is an existing easydo profile; use ad hoc `{ name, email, sequence, recipient }` for CRM contacts that do not already exist as profiles.
- Treat easydo role IDs on fields as field ownership metadata where available, but do not rely on DocuSign-style role names unless easydo exposes them consistently for the template.

DocuSign comparison: DocuSign templates define named roles that the sender fills at envelope creation. easydo can approximate this by storing recipient intent in Dataverse and resolving it at runtime. For the current product shape, that is preferable to trying to force all recipient logic into the provider template.

### Field mapping model

The field mapping model should remain Dynamics-owned and provider-neutral where practical.

Recommended mapping fields:

| Mapping concept | easydo-specific value | Dynamics-owned value |
| --- | --- | --- |
| Provider field key | easydo field `name` | Stored as external field ID for send-time prefill. |
| Read-back key | easydo `export.header` | Stored as external field name / binding expression. |
| Field type | easydo input type such as text, checkbox, date, signature | Used for conversion, display, and validation. |
| Direction | None, Prefill, ReadBack, Bidirectional | Determines whether values are sent, read, or written back. |
| Lock policy | `read_only` in easydo `prefill_data` | Controlled by Dynamics mapping, not by the template designer alone. |
| Source path | Not provider-owned | Primary table, optional lookup hop, target table, target column. |
| Write-back policy | Not provider-owned | Allow-list/conversion behavior for completed values. |

The mapping UI should continue to make Dynamics concepts explicit: primary table, lookup path, target field, direction, lock/read-only behavior, and validation status. The easydo template designer should place fields and set visual/signing behavior; the Dynamics mapping layer should decide CRM data policy.

### Value resolution from Dynamics 365

Value resolution should happen at request runtime, not in the Power Automate designer.

Recommended behavior:

1. A Signature Request identifies a selected easydo template and a primary Dynamics source record.
2. The resolver loads active mapping rows for the selected template.
3. For each prefill or bidirectional mapping, the resolver reads the configured source field from the primary record or one supported lookup hop.
4. Values are converted to easydo-friendly strings:
	 - text and numbers as display strings;
	 - choices/options as labels when the document is meant for humans;
	 - dates in a consistent display format expected by the template;
	 - checkboxes as `checked` or `unchecked`;
	 - lookups as primary-name display values unless a GUID is intentionally required.
5. Empty or unresolved values are either omitted from `prefill_data` or sent as empty strings according to mapping policy.
6. The resolver emits easydo `prefill_data` items with `{ name, content_value, read_only }`.

This reproduces the runtime flexibility that DocuSign's lower-level JSON payloads provide, while using the easydo-specific `prefill_data` contract.

### Send flow behavior

The send flow should be template-based by default.

Recommended send sequence:

1. Trigger when a Signature Request is marked ready to send.
2. Load the Signature Template, request recipients, source record anchor, and existing request field-value rows.
3. Resolve mapping-driven prefill values from Dynamics.
4. Merge mapping-driven prefill values with any manually entered request-specific prefill rows, with a deterministic precedence rule.
5. Build the easydo assignee list, ensuring sequence and `recipient:true` constraints are valid.
6. Send the template with `POST /entity/me/templates/{templateId}/send` and body values for assignees, `prefill_data`, and correlation metadata.
7. Store the returned easydo form ID, status, fill/signing link, sent timestamp, and raw provider status.
8. Leave PDF retrieval to the status/read-back process unless the API returns a specific preview/draft artifact required by the UI.

Correlation metadata should be included in the easydo request where supported, using `meta_data.client` or the provider-supported metadata object. At minimum it should contain the Signature Request ID, source table, source record ID, environment identifier, and integration version.

### Preview behavior

Preview should not send notifications or create an active waiting signing task.

Recommended preview pattern:

- Use `POST /entity/me/templates/{templateId}/form` to create a draft form from the selected template.
- Associate the draft form ID with the request as preview state, not as the final sent form unless the later send path explicitly continues from that draft.
- Surface the draft PDF or fill URL only as a preview artifact according to the product UX.
- Do not use `POST /entity/me/templates/{templateId}/send` for preview, because it sends the form and creates waiting recipients.
- Clean up abandoned draft forms when the user cancels preview or when a request is superseded, if the API and retention policy allow.

The important distinction from DocuSign is that DocuSign often uses draft envelopes plus embedded sender/recipient views, while easydo's verified template preview path is draft form creation from the template. The architecture should hide that difference behind a provider-neutral Preview Request concept.

### Status tracking and read-back

Status tracking can be polling-first and webhook-ready.

Recommended polling behavior:

- Periodically list open Signature Requests with an easydo form ID.
- Call the easydo form status/detail endpoint for each open form.
- Map easydo statuses such as waiting, in progress, declined, signed, and approved to Dataverse status choices.
- When `has_data` is true, read the top-level data object keyed by export header and create or update request field-value read-back rows.
- When status is signed or approved, download the signed PDF and attach or store it according to the configured storage policy.
- Record last checked time, provider raw status, failure message, and retry count.

Recommended webhook behavior:

- Keep polling as the reliable baseline.
- Add a webhook receiver later for Form Submitted when a secure HTTPS endpoint is available.
- Use webhook data as a trigger to accelerate the same read-back/download process rather than building separate business logic.

Read-back and write-back should remain separate. Read-back stores what easydo returned. Write-back applies Dynamics-owned policy after conversion and validation, so a template designer cannot cause arbitrary updates to Dataverse by changing an export header.

### Backward compatibility

The easydo implementation should evolve without breaking existing requests, flows, or manually entered values.

Recommended compatibility rules:

- Keep existing Signature Request statuses and provider form ID fields stable.
- Continue supporting request-specific field-value rows as an additive override or supplement to mapping-driven prefill.
- Preserve existing mapping rows during template sync; never delete admin-owned mapping policy automatically.
- Treat missing direction values as a backward-compatible default, such as Prefill-capable where existing behavior depended on it.
- Keep old random-document send operations available only for non-template use cases, but make template send the default product path.
- Keep read-back rows as the durable integration output even if direct write-back becomes available, so implementers can audit and replay results.
- Version provider behavior explicitly if the easydo API shape changes, especially around `prefill_data`, field names, and export headers.

### Phased roadmap

| Phase | Goal | Conceptual deliverable |
| --- | --- | --- |
| 1. Metadata sync | Make easydo templates and fields visible in Dynamics. | Template and field metadata sync with change detection. |
| 2. Mapping UX | Let admins bind easydo fields to Dynamics source paths. | Dynamics mapping control/table using easydo field metadata. |
| 3. Runtime prefill | Resolve mapped values at send time. | Provider-specific `prefill_data` generated from mapping rows and source records. |
| 4. Template send | Replace random-document send as the default. | Template send with assignees, prefill, read-only policy, and correlation metadata. |
| 5. Preview | Support safe pre-send review. | Draft form preview path that does not notify recipients. |
| 6. Read-back and PDF | Complete the return path. | Status polling/webhook processing, read-back rows, signed PDF storage. |
| 7. Compatibility and hardening | Make the model reliable across template changes. | Sync validation, stale-field handling, retries, audit logs, and provider-version notes. |

### Design principles

- Keep provider metadata and business policy separate: easydo supplies fields; Dynamics decides mappings.
- Prefer template-based easydo sending over random document upload for configured templates.
- Use field technical `name` for easydo prefill and export header for easydo read-back.
- Use `read_only` in send-time `prefill_data` as the reliable lock mechanism.
- Resolve values at runtime from Dataverse, not through static Power Automate action cards.
- Store read-back values before applying any write-back policy.
- Keep polling viable even if webhooks are later added.
- Preserve existing rows and behavior unless a migration deliberately changes them.

### Bottom line for easydo

The DocuSign capability model can be reproduced on easydo by treating easydo template fields as provider metadata and Dataverse mappings as the product control plane. easydo does not need to match DocuSign's Power Automate dynamic-schema experience in the designer. The important capabilities are runtime template discovery, field sync, recipient resolution, send-time prefill with lock policy, safe preview through draft forms, status/read-back processing, and backward-compatible storage of all integration outcomes in Dataverse.

## Short Note: DocuSign Security Roles / Permission Profiles

DocuSign eSignature does not use Dataverse-style security roles. The closest equivalent is an account-level **Permission Profile** assigned to each DocuSign user. The eSignature API exposes these profiles through `GET /restapi/v2.1/accounts/{accountId}/permission_profiles`; the documented example includes the standard profiles **Account Administrator**, **DocuSign Sender**, and **DocuSign Viewer**, plus custom permission profiles.

### Standard profiles

| DocuSign profile | Purpose | Typical capabilities |
| --- | --- | --- |
| **Account Administrator** | Account-level administration. | Manages account settings, users, groups, permission profiles, templates/settings, integrations such as Connect where enabled, and other administrative configuration. This is the broadest eSignature account role and should not be used for routine sending unless administration is required. |
| **DocuSign Sender** | Business user who prepares and sends envelopes. | Sends envelopes, uses templates, manages their own sending workflow, and works with envelopes they are allowed to access. Exact abilities, such as template creation or sharing, depend on the account's permission-profile settings. |
| **DocuSign Viewer** | Read-only or limited-access user. | Views envelopes/documents/status information according to account permissions, but is not intended to send envelopes or administer the account. Useful for audit, support, or reporting scenarios where users should not modify sending configuration. |
| **Custom Permission Profile** | Organization-specific least-privilege role. | A tailored profile created by an administrator by enabling only the required permissions, for example send-only, template-manager, reporting-only, or integration-service-user profiles. Custom profiles are usually preferable for production integrations. |

### Organization-level administration

Large DocuSign tenants may also use DocuSign Admin / organization-level administration. That layer can include organization administrators who manage cross-account concerns such as users, domains, identity, SSO, and account membership. This is separate from the eSignature account permission profile used when sending envelopes from a specific account.

### Integration guidance for Dynamics 365 / Power Automate

- Use a dedicated DocuSign integration or service user for the Power Automate connection.
- Prefer a custom least-privilege permission profile over **Account Administrator**.
- For send-only automation, the service user generally needs sender rights and access to the templates it will use.
- If the integration must create/update templates, configure Connect webhooks, manage account custom fields, or administer users, it needs additional administrative permissions, and those should be explicitly justified.
- Store the selected DocuSign account ID and permission-profile expectation in deployment documentation so production support can verify the connection user quickly.
- Before go-live, call or inspect `permission_profiles` for the target account and confirm the actual profile names and settings, because organizations can rename or customize profiles and available permissions can vary by plan.