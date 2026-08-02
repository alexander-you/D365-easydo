# סכימות Flow למיישם — D365 ↔ easydo

תרשימי זרימה (Mermaid) למסלולים הנפוצים שמיישם בונה ב‑Power Automate מול הקונקטור של easydo.
התרשימים הם **סכמטיים** — להמחשת הלוגיקה, לא ייצוא של Flow אמיתי.

הקונקטור עצמו: [src/custom-connector/apiDefinition.swagger.json](../src/custom-connector/apiDefinition.swagger.json)
דוגמאות Flow אמיתיות: [src/flows/](../src/flows/)

---

## סכימה א' — שליחה בסיסית (חד‑כיוונית)

המסלול הפשוט: טריגר ← שליפת איש קשר ← `SendTemplate`. **אין readback** — התוצאה נשארת ב‑easydo.

```mermaid
flowchart TD
    A["טריגר: When a row is added/modified<br/>(טבלת איש קשר / בקשה)"] --> B["Get a row by ID<br/>שליפת פרטי איש הקשר"]
    B --> C["easydo: Send template for signature<br/>SendTemplate"]
    C --> C1["templateId = התבנית"]
    C --> C2["assignees: email + name + recipient=true<br/>(בלי profile)"]
    C --> C3["prefill_data: שדות מ-D365 (אופציונלי)"]
    C --> D["Update row ב-D365<br/>שמירת fill_url + סטטוס 'נשלח'"]
    style C fill:#2b7,stroke:#063,color:#fff
```

המיישם שולף את איש הקשר, שולח את התבנית עם כתובת email ושם כנמען זמני, ושומר ב‑D365 את קישור החתימה.
מספיק כשרק רוצים *לשלוח* — לא לקבל תוצאה בחזרה.

---

## סכימה ב' — שליחה + תגובה (readback מלא)

שני תהליכי Flow נפרדים: הראשון שולח את הבקשה, והשני מתוזמן ומושך את התוצאה לאחר שהלקוח חתם.

```mermaid
flowchart TD
    subgraph FLOW1["Flow 1 — שליחה"]
        A1["טריגר על הרשומה"] --> B1["Get contact + Get template"]
        B1 --> C1["easydo: SendTemplate"]
        C1 --> D1["שמירת formId + סטטוס 'נשלח' ב-D365"]
    end
    subgraph FLOW2["Flow 2 — קריאת תוצאה (מתוזמן)"]
        T2["Recurrence: כל 5 דקות"] --> L2["List רשומות פתוחות (יש formId)"]
        L2 --> G2["easydo: GetFormStatus"]
        G2 --> Q2{"has_data = true?<br/>הלקוח חתם/שלח?"}
        Q2 -->|לא| Z2["עדכון 'נצפה לאחרונה' והמתנה"]
        Q2 -->|כן| W2["כתיבת הערכים חזרה ל-D365"]
        W2 --> P2["easydo: DownloadDocument (PDF חתום)"]
        P2 --> A2["צירוף ה-PDF ל-Timeline + סטטוס 'הושלם'"]
    end
    D1 -. "formId מקשר בין השניים" .-> L2
    style C1 fill:#2b7,stroke:#063,color:#fff
    style G2 fill:#37c,stroke:#036,color:#fff
    style P2 fill:#37c,stroke:#036,color:#fff
```

ה‑formId שנשמר ב‑Flow 1 הוא החוליה המקשרת. Flow 2 רץ במחזוריות, בודק לכל בקשה פתוחה אם הלקוח כבר חתם
(`has_data`), וכשכן — מושך את הערכים וה‑PDF החתום בחזרה ל‑D365.
מימוש אמיתי: [src/flows/read-signature-results.flow.json](../src/flows/read-signature-results.flow.json).

---

## סכימה ג' — תצוגה מקדימה לפני שליחה

כשרוצים שהשולח יראה את המסמך הממולא לפני שהלקוח מקבל אותו.

```mermaid
flowchart TD
    A["טריגר"] --> B["easydo: CreateFormFromTemplate<br/>(טיוטה, לא נשלח מייל)"]
    B --> C["easydo: SetAssignees<br/>הגדרת נמענים"]
    C --> D["easydo: GetFormStatus<br/>קבלת fill_url לתצוגה"]
    D --> E{"השולח אישר?"}
    E -->|כן| F["easydo: SendForm<br/>שליחה בפועל"]
    E -->|לא| G["easydo: DeleteForm<br/>מחיקת הטיוטה"]
    style B fill:#e90,stroke:#960,color:#fff
    style F fill:#2b7,stroke:#063,color:#fff
```

במקום לשלוח מיד, יוצרים טיוטה (`CreateFormFromTemplate`), מציגים אותה (`GetFormStatus` ← `fill_url`),
ורק לאחר אישור שולחים (`SendForm`) — או מוחקים (`DeleteForm`).

---

## סכימה ד' — שליחה רב‑נמענים עם תפקידים (חותם + קצין רכב)

כשהתבנית דורשת כמה תפקידים (`roles`), צריך למפות **נמען לכל תפקיד** לפי סדר החתימה —
אחרת מתקבלת שגיאת `missing_assignee`.

```mermaid
flowchart TD
    A["טריגר על הרשומה"] --> B["easydo: GetTemplate<br/>שליפת payload.roles (התפקידים הנדרשים)"]
    B --> C["שליפת אנשי הקשר<br/>חותם ראשי + קצין רכב"]
    C --> D["בניית מערך assignees לפי roles:"]
    D --> D1["נמען 1 — חותם:<br/>sequence=1, recipient=true"]
    D --> D2["נמען 2 — קצין רכב:<br/>sequence=2, recipient=false"]
    D1 --> E["easydo: SendTemplate<br/>assignees = שני הנמענים"]
    D2 --> E
    E --> F{"כל התפקידים מולאו?"}
    F -->|כן| G["נשלח בהצלחה<br/>כל נמען מקבל fill_url משלו"]
    F -->|לא| H["שגיאת missing_assignee<br/>(תפקיד חסר)"]
    style E fill:#2b7,stroke:#063,color:#fff
    style H fill:#c33,stroke:#700,color:#fff
```

קודם שולפים מהתבנית את רשימת התפקידים (`GetTemplate` ← `payload.roles`), אחר כך בונים `assignees`
שבו לכל תפקיד יש נמען עם ה‑`sequence` הנכון. **רק** הנמען הראשי הוא `recipient=true`; השאר `false`.
אם תפקיד נשאר בלי נמען — easydo מחזיר `missing_assignee`.

### האתגר בבניית ה‑action ב‑Flow

1. **מספר משתנה של נמענים** — לכל תבנית מספר תפקידים שונה, אבל ב‑Flow מגדירים מספר פריטי assignee
   קבוע בזמן עיצוב. כדי לתמוך בכל תבנית צריך לבנות את מערך ה‑assignees דינמית (Select/Loop על ה‑roles).
2. **אין binding לתפקיד** — מעצב ה‑Flow לא יכול לבחור איזה נמען שייך לאיזה role; הכול נשען על
   `sequence`, וזה שביר.
3. **הלוגיקה "איזה איש קשר = איזה תפקיד" חיה מחוץ ל‑easydo** — צריך למפות זאת ב‑D365 ולהבטיח התאמה
   לפי sequence בזמן ריצה.

---

## סכימה ה' — שליחת מעטפה רב‑מסמכית (2.0.0.0)

**מעטפה** מאגדת כמה מסמכים לחבילת חתימה אחת. שולחים ב‑`SendEnvelope` יחיד, ולכל מסמך נוצרת שורת
`alex_signaturerequestitem` עם סטטוס וקישור חתימה משלה.

```mermaid
flowchart TD
    A["טריגר: בקשה עם תבנית שהיא מעטפה<br/>(alex_isenvelope = true)"] --> B["easydo: SendEnvelope<br/>recipient + auth_method + templates[]"]
    B --> C["שמירת alex_externalenvelopeid + סטטוס 'נשלח'"]
    C --> D["יצירת שורת פריט לכל מסמך<br/>alex_signaturerequestitem (sequence, itemstatus)"]
    D --> E["פאנל / זרימת polling עוקבים פר‑מסמך"]
    style B fill:#2b7,stroke:#063,color:#fff
```

---

## סכימה ו' — מעקב מעטפה בזמן אמת (2.0.0.0)

זרימת ה‑polling מזהה מעטפה (יש `alex_externalenvelopeid`, אין `alex_externalformid`), מושכת
`GetEnvelope` ומעדכנת כל מסמך בנפרד עד שכולם נחתמו — ואז מורידה את החבילה המאוחדת.

```mermaid
flowchart TD
    T["טריגר: alex_realtimesessionactive = true"] --> Q{"מעטפה?<br/>externalenvelopeid קיים"}
    Q -->|כן| L["Until: easydo GetEnvelope"]
    L --> U1["עדכון כל alex_signaturerequestitem<br/>נחתם / נדחה / ממתין"]
    U1 --> U2["עדכון alex_status של הבקשה<br/>נשלח → נצפה → הושלם / נדחה"]
    U2 --> C{"כל המסמכים נחתמו?"}
    C -->|לא| L
    C -->|כן| R["קריאה חזרה של השדות מכל מסמך"]
    R --> D["easydo: DownloadEnvelope (PDF מאוחד)"]
    D --> A["צירוף לרשומה + סגירת הסשן"]
    style L fill:#37c,stroke:#036,color:#fff
    style D fill:#37c,stroke:#036,color:#fff
```

מימוש אמיתי: [src/flows/realtime-session-poll.flow.json](../src/flows/realtime-session-poll.flow.json).

---

## סכימה ז' — בדיקת סטטוס לפי דרישה (2.0.0.0)

במקום להמתין למחזור של חמש דקות, פקד המסמכים מעדכן את `alex_statuscheckrequestedon` — פעולה זו מפעילה Flow
שמרעננת מיד את הסטטוס מ‑easydo.

```mermaid
flowchart TD
    A["משתמש לוחץ 'בדיקת סטטוס' בפקד המסמכים"] --> B["עדכון alex_statuscheckrequestedon"]
    B --> C["טריגר: שינוי בעמודה זו<br/>(Check Signature Status flow)"]
    C --> D["easydo: GetFormStatus"]
    D --> E["עדכון alex_status + alex_lastviewedon + alex_statuschecklastrunon"]
    E --> F{"has_data = true?"}
    F -->|כן| G["קריאה חזרה + הורדת PDF + צירוף לרשומה"]
    F -->|לא| H["שמירת התוצאה ב-alex_statuscheckstatus"]
    style D fill:#37c,stroke:#036,color:#fff
```

מימוש אמיתי: [src/flows/check-signature-status.flow.json](../src/flows/check-signature-status.flow.json).
