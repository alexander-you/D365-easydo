# Dynamics 365 Contact Center Integration — easydo Signing in a Live Conversation

> **עברית למטה** · English first, Hebrew below.
> Status: **draft / starting point** · Env: demo-contact-center-en.crm4.dynamics.com · Solution: `alex_d365_easydo`
> Related: [self-distribution-contract.md](self-distribution-contract.md) · real-time mode (`realtime-session-poll.flow.json`, `realtimeSession.html`)

---

## English

### 1. Goal

During a **live Contact Center conversation** (chat / WhatsApp / SMS), the agent:

1. Generates an easydo **signing link** for the customer they are talking to.
2. **Auto-sends** that link to the customer **over the same conversation channel** — the
   customer never leaves the conversation.
3. Sees the **signing result in real-time** inside the agent session — or not — **depending
   on configuration**.

This is the existing **real-time mode**, where the "channel" is the **live conversation
itself**, and distribution uses the **self-distribution contract** (easydo stays silent).

### 2. The conversation entity — `msdyn_ocliveworkitem`

The live conversation is the Dataverse table **`msdyn_ocliveworkitem`** (the "live work item").
It holds the conversation channel and the linked customer.

**Verified live (2026-06-22)** on `demo-contact-center-en`:

| Field | Type | Notes |
| --- | --- | --- |
| `msdyn_channel` | MultiSelect Picklist | Channel type. Values: Live Chat `192360000`, SMS `192340000`, WhatsApp `192300000`, Voice `192370000`, Facebook `192330000`, LINE `192310000`, WeChat `192320000`, Teams `19241000`, Twitter `192350001`, Apple Messages `192450000`, Google Business Messages `192450001`, Custom `192350002`, Entity records `192350000`. |
| `_msdyn_customer_value` | Customer (polymorphic) | Linked customer; in sample → **contact** "Raviv Azulay". Mirrored on `_regardingobjectid_value`. |
| `subject` | Text | e.g. "Raviv Azulay: Live Chat". |
| `statecode` / `statuscode` | State/Status | Conversation lifecycle. |

Decision for the admin center:

- **Hide `msdyn_ocliveworkitem` from the generic Entities / tables list** (it is a system OOB
  table, not part of our integration data model).
- Move every Contact-Center-related setting into a **new admin area**:
  **"אינטגרציה עם Dynamics 365 Contact Center"**.

### 2.1 Where the signed document is hosted — contact vs case

`msdyn_ocliveworkitem` is an **exceptional host**: the conversation is transient (it closes) and a
system table we are hiding, so the **document / signature request cannot live on it**. At send time
the agent must choose a **durable host** for the signature request (and therefore the resulting
file), among the records the conversation already references:

| Option | Field on `msdyn_ocliveworkitem` | Target |
| --- | --- | --- |
| **Linked contact** (always present) | `msdyn_customer` / `_msdyn_customer_value` | account / **contact** |
| **Linked case** (only if a case is attached to the conversation) | `msdyn_issueid` | **incident** |

Behaviour:

- The send panel reads both references from the live work item and offers the agent a **host picker**
  (contact vs case). The chosen record becomes `alex_primarytable` + `alex_primaryrecordid` on the
  `alex_signaturerequest` (so the request and its file are attached to a durable record, not the
  conversation).
- If **no case** is linked, default to the **contact**. If a case **is** linked, default to the case
  (it is the more specific context) but let the agent switch.
- `regardingobjectid` mirrors the customer/case and is polymorphic — prefer the explicit
  `msdyn_customer` / `msdyn_issueid` fields for a deterministic choice.

### 3. Building blocks (Omnichannel JavaScript API — verified 2026-06-22)

Client-side API, runs inside the Customer Service workspace / Contact Center app (same-origin
`Xrm` available):

| API | Purpose |
| --- | --- |
| `Microsoft.Omnichannel.getConversationId()` → `Promise<string>` | Current conversation GUID = the `msdyn_ocliveworkitem` row id. Read it to get channel + customer. |
| `Microsoft.Omnichannel.sendMessageToConversation(message, toSendBox?, conversationId?)` → `Promise` | Send the signing link into the conversation. `toSendBox=false` → send directly to customer; default `true` → drop in the agent sendbox for review. |
| `Microsoft.Omnichannel.linkToConversation(...)` | Link a contact/account/case if the customer is not yet identified. |
| `getConversations`, `openConversation`, `unlinkFromConversation`, `runMacro` | Supporting methods. |

Constraints:

- The conversation must be **assigned to the logged-in agent**.
- `message` may be a **string literal** or a **rich-object JSON**. For **SMS / WhatsApp** send
  the link as a **plain string** (rich cards render on chat channels only).
- Requires an **Omnichannel / Contact Center license** (add-on).

### 4. Flow (end-to-end)

```
Agent in live conversation
   │
   │ 1. getConversationId()  ─────────────► conversation GUID
   │ 2. read msdyn_ocliveworkitem (Web API) ─► channel + customer (msdyn_customer) + case (msdyn_issueid)
   │ 3. agent picks host (contact vs case) + template (session side pane)
   ▼
create alex_signaturerequest (alex_isrealtime = true, channel = conversation channel,
                               alex_primarytable/alex_primaryrecordid = chosen contact OR incident)
   ▼
Send flow → easydo generate link (notify_platform = null  → easydo stays silent)
   ▼
alex_signinglink ready  (self-distribution contract)
   ▼
sendMessageToConversation(signingLink, false)  → link delivered over the LIVE channel
   ▼
realtime-session-poll flow + realtimeSession.html modal → agent sees signing result live
   (only if real-time is enabled, per config)
```

### 5. Mapping to what already exists

| Capability | Reuse / New |
| --- | --- |
| Create request + generate link | **Reuse** — `alex_signaturerequest` → Send flow → `alex_signinglink`. |
| Silent easydo (link only) | **Reuse** — self-distribution contract (`notify_platform = null`). |
| Real-time results | **Reuse** — `realtime-session-poll.flow.json` + `realtimeSession.html`. |
| "See results or not, per config" | **Reuse** — `alex_realtimeenabled` (global) + per-send `alex_isrealtime`. |
| **Agent trigger inside the session** | **New** — side pane / productivity pane web resource that reads `getConversationId` + the live work item and pre-fills the request. |
| **Distribution over the live channel** | **New** — call `sendMessageToConversation(link, false)`. |

### 6. Admin center changes (this work item)

1. **New area**: "אינטגרציה עם Dynamics 365 Contact Center" in the admin center (`adminCenter.html`).
2. **Hide** `msdyn_ocliveworkitem` from the generic entities list.
3. Settings to surface in the new area (proposed):
   - **Enable Contact Center signing (master toggle)** — enabling it is what **exposes the Send
     button** inside the agent session. Disabled = no button.
   - Default behaviour: send directly (`toSendBox=false`) vs agent review (`toSendBox=true`).
   - Real-time results in conversation: on / off (maps to `alex_realtimeenabled`).
   - Default host on send: contact vs case (when both exist).
   - Default template / template per channel.
   - Channel mapping (conversation channel → easydo channel).

### 6.1 Send button exposure rules

The Send button (the agent trigger inside the session) is shown **only** when **both** hold:

1. The **integration is enabled** (master toggle in the new admin area). Enabling the integration is
   precisely what reveals the button.
2. There is an **active conversation** — `getConversationId()` resolves to a live work item that is
   **open / active** (not wrapped-up or closed). The button is hidden on closed conversations, on
   non-conversation sessions, and when no conversation is focused.

### 6.2 Agent-side launcher (built)

The host surface chosen is the **productivity pane** (always available next to the live
conversation; the agent passes it no context — it discovers the focused conversation itself).

- `contactCenterSend.js` (`alex_/scripts/contactCenterSend.js`) — namespace `EasyDo.ContactCenter`:
  - `isEnabled()` → `Promise<boolean>`: master toggle on **and** an active conversation exists.
  - `getCurrentContext()` → `{ enabled, hasConversation, host }` for a hosting UI.
  - `launch()` → resolves the durable host (contact via `msdyn_customer`, or case via `msdyn_issueid`
    per `alex_ccdefaultcase`) and opens the **shared** send wizard (`alex_/html/sendWizard.html`,
    pane `easydoSendWizard`) pre-targeted at it, passing `ccconversationid` + `ccchannel` for the
    later distribution step.
- `contactCenterPane.html` (`alex_/html/contactCenterPane.html`) — productivity-pane host: shows the
  active customer / document host / channel and a **Send for signature** button gated by `isEnabled`.
- **Surface registration** (remaining): register `contactCenterPane.html` as a **custom productivity
  tool** in the Contact Center admin center agent experience profile. Config-only; not scripted.

### 7. Open questions

**Resolved (verified live 2026-06-22):**

- Channel type field → `msdyn_channel` (multi-select picklist; see §2 for option values).
- Customer link → `_msdyn_customer_value` (polymorphic customer; contact in the sample row).
- Case link → `msdyn_issueid` (→ incident). Document host = contact or case, agent picks (§2.1).

**Still open (build-time decisions):**

- ~~Best **host surface** for the agent control~~ → **Resolved**: **productivity pane** custom tool
  (`contactCenterPane.html`). The pane discovers the focused conversation itself via
  `getConversationId()`, so no context needs to be passed in.
- Send **directly** (`toSendBox=false`) vs to the **agent sendbox** (`toSendBox=true`) by default.

---

## עברית

### 1. מטרה

במהלך **שיחה חיה ב-Contact Center** (צ'אט / WhatsApp / SMS), הנציג:

1. מחולל **קישור חתימה** של easydo ללקוח שאיתו הוא מדבר.
2. **שולח אוטומטית** את הקישור ללקוח **באותו ערוץ השיחה** — הלקוח לא יוצא מהשיחה.
3. רואה את **תוצאת החתימה בזמן אמת** בתוך סשן הנציג — או לא — **תלוי בהגדרה**.

זהו **מודל זמן-אמת** הקיים, כאשר ה"ערוץ" הוא **השיחה החיה עצמה**, וההפצה משתמשת ב**חוזה
ההפצה-העצמית** (easydo שותק).

### 2. יישות השיחה — `msdyn_ocliveworkitem`

השיחה החיה היא טבלת Dataverse **`msdyn_ocliveworkitem`**. היא מחזיקה את ערוץ השיחה ואת הלקוח
המקושר.

**אומת חי (22-06-2026)** על `demo-contact-center-en`:

| שדה | סוג | הערות |
| --- | --- | --- |
| `msdyn_channel` | MultiSelect Picklist | סוג הערוץ. ערכים: צ'אט חי `192360000`, SMS `192340000`, WhatsApp `192300000`, קול `192370000`, ועוד. |
| `_msdyn_customer_value` | Customer (פולימורפי) | הלקוח המקושר; בדוגמה → **contact** "Raviv Azulay". משוכפל ב-`_regardingobjectid_value`. |
| `subject` | טקסט | למשל "Raviv Azulay: Live Chat". |

החלטה לאזור הניהול:

- **להעלים את `msdyn_ocliveworkitem` מרשימת היישויות הכללית** (זו טבלת מערכת OOB, לא חלק ממודל
  הנתונים של האינטגרציה שלנו).
- להעביר כל הגדרה הקשורה ל-Contact Center ל**אזור ניהול חדש**:
  **"אינטגרציה עם Dynamics 365 Contact Center"**.

### 2.1 לאן משייכים את המסמך — איש קשר מול אירוע

`msdyn_ocliveworkitem` היא **היישות החריגה**: השיחה זמנית (נסגרת) והיא טבלת מערכת שאנחנו
מעלימים — לכן **המסמך / בקשת החתימה לא יכולים לשבת עליה**. במעמד השליחה הנציג
חייב לבחור **יעד קבוע** לשיוך, מתוך הרשומות שהשיחה כבר מצביעה אליהן:

| אפשרות | שדה על `msdyn_ocliveworkitem` | יעד |
| --- | --- | --- |
| **איש הקשר המקושר** (תמיד קיים) | `msdyn_customer` / `_msdyn_customer_value` | account / **contact** |
| **האירוע המקושר** (רק אם משויך תיק לשיחה) | `msdyn_issueid` | **incident** |

התנהגות:

- פאנל השליחה קורא את שתי ההפניות מה-live work item ומציג לנציג **בורר יעד** (איש קשר מול
  אירוע). הרשומה שנבחרה הופכת ל-`alex_primarytable` + `alex_primaryrecordid` על ה-`alex_signaturerequest`
  (כך שהבקשה והקובץ שלה משויכים לרשומה קבועה, לא לשיחה).
- אם **אין אירוע** מקושר — ברירת מחדל ל**איש הקשר**. אם **יש** אירוע — ברירת מחדל לאירוע
  (הקשר ספציפי יותר), אבל לאפשר לנציג להחליף.

### 3. אבני הבניין (Omnichannel JavaScript API — אומת 22-06-2026)

API צד-לקוח, רץ בתוך Customer Service workspace / Contact Center (אותו origin, `Xrm` זמין):

| API | תפקיד |
| --- | --- |
| `Microsoft.Omnichannel.getConversationId()` | GUID של השיחה הפעילה = מזהה רשומת `msdyn_ocliveworkitem`. ממנו קוראים ערוץ + לקוח. |
| `Microsoft.Omnichannel.sendMessageToConversation(message, toSendBox?, conversationId?)` | שולח את קישור החתימה לשיחה. `toSendBox=false` → ישירות ללקוח; ברירת מחדל `true` → לתיבת הנציג לאישור. |
| `Microsoft.Omnichannel.linkToConversation(...)` | קישור איש קשר/חשבון/תיק אם הלקוח עדיין לא מזוהה. |

מגבלות:

- השיחה חייבת להיות **משויכת לנציג המחובר**.
- `message` יכול להיות **string** או **rich-object**. ל-**SMS / WhatsApp** שולחים את הקישור כ-**string
  רגיל** (כרטיסים עשירים מוצגים בערוצי צ'אט בלבד).
- דורש **רישוי Omnichannel / Contact Center** (add-on).

### 4. שינויים באזור הניהול (פריט העבודה הזה)

1. **אזור חדש**: "אינטגרציה עם Dynamics 365 Contact Center" ב-`adminCenter.html`.
2. **להעלים** את `msdyn_ocliveworkitem` מרשימת היישויות הכללית.
3. הגדרות שיופיעו באזור החדש (הצעה):
   - **הפעלת חתימה ב-Contact Center (מתג ראשי)** — הפעלתה היא מה ש**חושף את כפתור
     השליחה** בתוך סשן הנציג. כבוי = אין כפתור.
   - התנהגות ברירת מחדל: שליחה ישירה (`toSendBox=false`) מול אישור נציג (`toSendBox=true`).
   - תוצאות בזמן אמת בשיחה: דלוק / כבוי (ממופה ל-`alex_realtimeenabled`).
   - יעד ברירת מחדל בשליחה: איש קשר מול אירוע (כששניהם קיימים).
   - תבנית ברירת מחדל / תבנית לפי ערוץ.
   - מיפוי ערוצים (ערוץ שיחה → ערוץ easydo).

### 4.1 כללי חשיפת כפתור השליחה

כפתור השליחה (הטריגר בתוך הסשן) מוצג **רק** כאשר **שני התנאים** מתקיימים:

1. **האינטגרציה מופעלת** (המתג הראשי באזור החדש). הפעלת האינטגרציה היא בדיוק מה
   שחושף את הכפתור.
2. קיימת **שיחה פעילה** — `getConversationId()` מחזיר live work item שהוא **פתוח / פעיל**
   (לא סגור או ב-wrap-up). הכפתור מוסתר בשיחות סגורות, בסשנים שאינם שיחה, וכשאין
   שיחה בפוקוס.

### 5. שאלות פתוחות

**נסגר (אומת חי 22-06-2026):**

- שדה סוג הערוץ → `msdyn_channel` (multi-select; ערכים בסעיף 2).
- קישור הלקוח → `_msdyn_customer_value` (customer פולימורפי; contact בדוגמה).
- קישור האירוע → `msdyn_issueid` (→ incident). יעד המסמך = איש קשר או אירוע, הנציג בוחר (סעיף 2.1).

**עדיין פתוח (החלטות בנייה):**

- משטח האירוח הטוב ביותר לפקד הנציג: **App Side Pane** (CIF 2.0) מול **Productivity Pane** מול
  web resource בטופס השיחה.
- שליחה **ישירה** (`toSendBox=false`) מול **תיבת הנציג** (`toSendBox=true`) כברירת מחדל.
