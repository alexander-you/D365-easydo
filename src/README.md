# Source

> תיקיית הקוד ורכיבי הפתרון של האינטגרציה בין Dynamics 365 ל-easydo.

Solution components:

```text
custom-connector/     easydo custom connector (OpenAPI swagger + apiProperties)
flows/                Solution-aware cloud flows (send / read / sync / real-time / status / expiry)
pcf/                  Template Field Mapping PCF (signature-template form)
pcf-template-gallery/ Template Gallery PCF (card gallery of templates/envelopes)
pcf-envelope/         Envelope Composition PCF (envelope-template tab)
pcf-documents/        Documents grid PCF (requests + on-demand status check)
plugins/              Dataverse plug-ins (write-back, ResolvePrefill, wizard intake, …)
webresources/         HTML web resources (send wizard, admin center, document viewer, real-time session)
scripts/              PowerShell setup/deploy scripts (Dataverse Web API)
```

