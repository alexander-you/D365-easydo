# Troubleshooting

A practical guide for diagnosing issues in the Dynamics 365 and easydo integration.
Before changing production data, obtain customer approval and record the original
request values.

[Hebrew version](troubleshooting.md)

## Request is Completed, but no PDF appears in the Timeline

### Symptom

A signature request has **Completed** status (`alex_status = 626210006`), but one
or more of the following are missing:

- `alex_signednoteid` is empty.
- `alex_completedon` is empty.
- No note containing the signed PDF appears in the primary business record's Timeline.
- No Read Back values were created in `alex_signaturefieldvalue`.

The issue has been confirmed in solution version 2.0.0.9. The current repository
flow definition still contains the filtering condition that causes it.

### Which requests does Read Signature Results process?

The scheduled flow runs every five minutes. For a single document, it selects only
records that meet all of these conditions:

| Field | Required value |
| --- | --- |
| `alex_status` | Sent (`626210002`), Delivered (`626210003`), Viewed (`626210004`), or In Progress (`626210005`) |
| `alex_externalformid` | Not empty |
| `alex_realtimesessionactive` | Not `true` |

The effective OData filter is:

```text
(alex_status eq 626210002 or alex_status eq 626210003 or
 alex_status eq 626210004 or alex_status eq 626210005)
and alex_externalformid ne null
and alex_realtimesessionactive ne true
```

Envelope requests use the same status and real-time conditions, but require
`alex_externalenvelopeid` instead of `alex_externalformid`.

### Why can a request become stuck?

After `GetFormStatus`, the flow sets the request to **Completed** when easydo
returns either `status = signed` or `has_data = true`. However, field readback,
PDF download, and Timeline attachment run only when `has_data = true`.

This creates the following possible sequence:

1. easydo returns `status = signed`, but `has_data = false`.
2. The request is updated to Completed.
3. Readback and PDF download do not run in that execution.
4. The next execution no longer selects the request because Completed
   (`626210006`) is absent from the filter.

The same result can occur if an execution fails after updating the status but
before attaching the PDF.

### What does alex_signednoteid mean?

After downloading the PDF from easydo, `alex_AttachSignedPdf` creates a note with
the file on the primary business record's Timeline. Only after the note is created
successfully is its identifier stored in `alex_signednoteid` on the signature request.

- Populated: the request references the Timeline note created for the signed PDF.
- Empty: there is no evidence that the PDF attachment completed successfully.

### Evidence to request from the customer

Request the following without asking for PDF content or Base64 values:

1. Run History for `Check Signature Status` and `Read Signature Results` around the
   incident time.
2. Inputs and outputs of `Get_the_form`, especially `status` and `has_data`.
3. The result of `Check_if_the_recipient_submitted` and the status of
   `Download_the_signed_PDF` and `Attach_the_signed_PDF_to_the_Timeline`.
4. Audit History showing who or what changed `alex_status` to `626210006`, and when.
5. Current values of `alex_externalformid`, `alex_realtimesessionactive`,
   `alex_completedon`, `alex_signednoteid`, `alex_laststatuscheckon`,
   `alex_errorcode`, and `alex_errormessage`.

### Controlled verification procedure

Prefer a test environment. In production, perform this procedure only with the
customer's approval and after recording the original values.

1. Confirm that `alex_externalformid` is populated and
   `alex_realtimesessionactive` is not `true`.
2. Record the status, `alex_completedon`, `alex_signednoteid`, and the number of
   existing Read Back rows for the request.
3. Temporarily change `alex_status` to **Viewed** (`626210004`). This only makes the
   request eligible for polling; easydo remains the source of truth.
4. Wait for the next `Read Signature Results` execution and inspect its Run History.

| Result | Possible meaning |
| --- | --- |
| A PDF is created, `alex_signednoteid` is populated, and `alex_completedon` is updated | easydo now returns `has_data = true`, and recovery succeeded |
| Status returns to Completed, but there is still no PDF | easydo still returned `has_data = false`, or the flow skipped the readback branch |
| The download or attachment action fails | Inspect the error reported by the failed action |
| The request is absent from the query output | At least one selection condition is not met |

This test does not send a copy to the customer. It reads the current state from
easydo, downloads the PDF, and attaches it in Dataverse.

### Risks of manual verification

- `alex_completedon` may be replaced with the verification time.
- Read Back values are created as new rows rather than upserted. Retrying may create
  duplicates if a previous execution created some values.
- The status change and recovery actions appear in Audit History.
- A successful recovery creates the intended Timeline note and PDF attachment.

### Proposed permanent fix

Include Completed requests in the `Read Signature Results` query only when they do
not yet reference a signed PDF note:

```text
(alex_status eq 626210002 or alex_status eq 626210003 or
 alex_status eq 626210004 or alex_status eq 626210005 or
 alex_status eq 626210006)
and alex_signednoteid eq null
and alex_externalformid ne null
and alex_realtimesessionactive ne true
```

Apply the same principle to the envelope path. Before retrying readback, account
for values created by a partial earlier execution so duplicate rows are not created.

> This is a proposed fix. It has not yet been implemented in the repository flow.
