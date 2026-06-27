const path = require("path");
const pptxgen = require("pptxgenjs");

const pptx = new pptxgen();
pptx.layout = "LAYOUT_16x9";
pptx.author = "GitHub Copilot";
pptx.company = "easydo / Microsoft Power Platform";
pptx.subject = "Commercial presentation for easydo integration with Dynamics 365 and Power Platform";
pptx.title = "easydo for Dynamics 365 and Power Platform";
pptx.lang = "he-IL";
pptx.rtlMode = true;
pptx.theme = {
  headFontFace: "Aptos Display",
  bodyFontFace: "Aptos",
  lang: "he-IL"
};

const S = pptx.ShapeType || pptx.shapes;
const LRM = "\u200E";
const RLM = "\u200F";

const C = {
  ink: "172033",
  muted: "5B6678",
  soft: "F5F8FC",
  surface: "FFFFFF",
  line: "D8E0EA",
  green: "28A866",
  greenDark: "187A49",
  greenSoft: "E9F7EF",
  blue: "2563EB",
  blueSoft: "EAF0FF",
  amber: "F59E0B",
  amberSoft: "FFF6E3",
  redSoft: "FCECEC",
  dark: "111827",
  slate: "27364A"
};

const terms = [
  "Customer Insights",
  "Power Automate",
  "Power Platform",
  "Dynamics 365",
  "Contact Center",
  "Dataverse",
  "WhatsApp",
  "easydo",
  "Microsoft",
  "PowerPoint",
  "Low-code",
  "API",
  "PDF",
  "SMS",
  "Email",
  "DLP",
  "RTL",
  "PCF",
  "MVP"
].sort((a, b) => b.length - a.length);

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function bidi(value) {
  let out = String(value);
  terms.forEach((term) => {
    out = out.replace(new RegExp(escapeRegExp(term), "g"), `${LRM}${term}${LRM}`);
  });
  return `${RLM}${out}${RLM}`;
}

function baseText(options = {}) {
  return Object.assign({
    fontFace: "Aptos",
    color: C.ink,
    lang: "he-IL",
    rtlMode: true,
    align: "right",
    margin: 0.04,
    breakLine: false,
    fit: "shrink"
  }, options);
}

function noteText(lines) {
  return lines.map((line) => bidi(line)).join("\n");
}

function addNotes(slide, lines) {
  slide.addNotes(noteText(lines));
}

function addText(slide, value, options) {
  slide.addText(bidi(value), baseText(options));
}

function addLtrText(slide, value, options = {}) {
  slide.addText(String(value), Object.assign({
    fontFace: "Aptos",
    color: C.ink,
    lang: "en-US",
    rtlMode: false,
    align: "left",
    margin: 0.04,
    fit: "shrink"
  }, options));
}

function addFooter(slide, index) {
  slide.addText(bidi("easydo × Dynamics 365"), baseText({
    x: 0.35, y: 5.22, w: 3.2, h: 0.16,
    fontSize: 6.8,
    color: "8390A3",
    align: "left",
    margin: 0
  }));
  slide.addText(String(index).padStart(2, "0"), {
    x: 9.25, y: 5.17, w: 0.35, h: 0.2,
    fontFace: "Aptos",
    fontSize: 7,
    color: "8390A3",
    align: "right",
    margin: 0
  });
}

function addChrome(slide, title, index, section) {
  slide.background = { color: C.soft };
  slide.addShape(S.rect, { x: 9.72, y: 0, w: 0.28, h: 5.625, fill: { color: C.green }, line: { color: C.green } });
  if (section) {
    slide.addShape(S.rect, { x: 7.1, y: 0.32, w: 2.2, h: 0.22, fill: { color: C.greenSoft }, line: { color: C.greenSoft } });
    addText(slide, section, { x: 7.18, y: 0.355, w: 2.04, h: 0.13, fontSize: 7.3, color: C.greenDark, bold: true, align: "center", margin: 0 });
  }
  addText(slide, title, { x: 3.35, y: 0.56, w: 6.0, h: 0.48, fontSize: 22, bold: true, fontFace: "Aptos Display", margin: 0 });
  addFooter(slide, index);
}

function placeholder(slide, x, y, w, h, label, hint) {
  slide.addShape(S.rect, {
    x, y, w, h,
    fill: { color: "FBFCFE" },
    line: { color: "9FB0C3", width: 1.1, dashType: "dash" }
  });
  slide.addShape(S.rect, { x: x + 0.16, y: y + 0.16, w: 0.46, h: 0.34, fill: { color: C.blueSoft }, line: { color: C.blueSoft } });
  slide.addShape(S.line, { x: x + 0.23, y: y + 0.24, w: 0.31, h: 0.15, line: { color: C.blue, width: 1.1 } });
  slide.addShape(S.line, { x: x + 0.34, y: y + 0.31, w: 0.17, h: 0.08, line: { color: C.blue, width: 1.1 } });
  addText(slide, label, { x: x + 0.3, y: y + h / 2 - 0.18, w: w - 0.6, h: 0.24, fontSize: 13, bold: true, color: C.slate, align: "center" });
  if (hint) {
    addText(slide, hint, { x: x + 0.45, y: y + h / 2 + 0.12, w: w - 0.9, h: 0.34, fontSize: 8.2, color: C.muted, align: "center" });
  }
}

function pill(slide, x, y, w, text, color = C.greenDark, fill = C.greenSoft) {
  slide.addShape(S.roundRect, { x, y, w, h: 0.26, rectRadius: 0.04, fill: { color: fill }, line: { color: fill } });
  addText(slide, text, { x: x + 0.08, y: y + 0.065, w: w - 0.16, h: 0.12, fontSize: 7.6, bold: true, color, align: "center", margin: 0 });
}

function card(slide, x, y, w, h, title, body, options = {}) {
  const fill = options.fill || C.surface;
  const shapeOptions = {
    x, y, w, h,
    fill: { color: fill },
    line: { color: options.line || C.line, width: 0.8 }
  };
  if (options.shadow) {
    shapeOptions.shadow = { type: "outer", color: "000000", blur: 2, offset: 1, angle: 45, opacity: 0.08 };
  }
  slide.addShape(S.rect, shapeOptions);
  if (options.accent) {
    slide.addShape(S.rect, { x: x + w - 0.08, y, w: 0.08, h, fill: { color: options.accent }, line: { color: options.accent } });
  }
  addText(slide, title, { x: x + 0.2, y: y + 0.18, w: w - 0.36, h: 0.22, fontSize: 11.5, bold: true, color: options.titleColor || C.ink });
  addText(slide, body, { x: x + 0.22, y: y + 0.54, w: w - 0.42, h: h - 0.66, fontSize: options.fontSize || 8.8, color: options.bodyColor || C.muted, valign: "mid" });
}

function metric(slide, x, y, number, label, color = C.green) {
  slide.addShape(S.rect, { x, y, w: 1.55, h: 0.72, fill: { color: C.surface }, line: { color: C.line } });
  addText(slide, number, { x: x + 0.12, y: y + 0.1, w: 1.28, h: 0.27, fontSize: 20, bold: true, color, align: "center", margin: 0 });
  addText(slide, label, { x: x + 0.1, y: y + 0.43, w: 1.35, h: 0.16, fontSize: 6.8, color: C.muted, align: "center", margin: 0 });
}

function flowNode(slide, x, y, w, title, caption, color) {
  slide.addShape(S.rect, { x, y, w, h: 0.78, fill: { color: C.surface }, line: { color, width: 1.2 } });
  slide.addShape(S.rect, { x: x + w - 0.12, y, w: 0.12, h: 0.78, fill: { color }, line: { color } });
  addText(slide, title, { x: x + 0.16, y: y + 0.14, w: w - 0.34, h: 0.18, fontSize: 10.2, bold: true, color: C.ink });
  addText(slide, caption, { x: x + 0.16, y: y + 0.43, w: w - 0.34, h: 0.18, fontSize: 7.2, color: C.muted });
}

function arrow(slide, x, y, w) {
  if (w < 0) {
    slide.addShape(S.line, { x: x + w, y, w: Math.abs(w), h: 0, line: { color: "96A4B8", width: 1.4, beginArrowType: "triangle", endArrowType: "none" } });
    return;
  }
  slide.addShape(S.line, { x, y, w, h: 0, line: { color: "96A4B8", width: 1.4, beginArrowType: "none", endArrowType: "triangle" } });
}

function titleSlide() {
  const slide = pptx.addSlide();
  slide.background = { color: "0F172A" };
  slide.addShape(S.rect, { x: 9.62, y: 0, w: 0.38, h: 5.625, fill: { color: C.green }, line: { color: C.green } });
  slide.addShape(S.rect, { x: 0, y: 4.75, w: 10, h: 0.88, fill: { color: "152238" }, line: { color: "152238" } });
  placeholder(slide, 0.55, 0.55, 3.7, 3.55, "מקום לצילום מסך", "רשומת Dynamics עם כפתור Send for Signature");
  addLtrText(slide, "easydo for Dynamics 365 & Power Platform", { x: 4.55, y: 1.0, w: 4.75, h: 0.78, fontSize: 25, bold: true, color: "FFFFFF", fontFace: "Aptos Display" });
  addText(slide, "חתימה דיגיטלית כחלק טבעי מתהליך העבודה העסקי", { x: 4.8, y: 1.92, w: 4.5, h: 0.44, fontSize: 15, color: "DDE8F5", bold: true });
  addText(slide, "שליחה מהרשומה, מעקב אוטומטי, החזרת נתונים ומסמך חתום אל Dataverse", { x: 4.8, y: 2.55, w: 4.5, h: 0.5, fontSize: 10.7, color: "B9C7DA" });
  pill(slide, 7.14, 3.42, 2.15, "מצגת מסחרית / שיווקית", "FFFFFF", "1F8E55");
  addText(slide, "גרסת טיוטה למציג", { x: 0.55, y: 5.05, w: 2.4, h: 0.16, fontSize: 7.3, color: "A9B8CB", align: "left", margin: 0 });
  addNotes(slide, [
    "מטרת השקף: לפתוח עם הבטחה עסקית ברורה ולא עם טכנולוגיה.",
    "מה להגיד: אנחנו לא מציגים עוד כלי חתימה. אנחנו מציגים דרך לסגור תהליך עסקי מתוך Dynamics 365, מהשליחה ועד החזרת המסמך והנתונים.",
    "הכנה למציג: להחליף את ה-placeholder בצילום מסך איכותי של רשומת Contact או Case עם כפתור Send for Signature ופאנל easydo.",
    "זהירות RTL: אם עורכים את הכותרת, להשאיר רווח לפני ואחרי Dynamics 365 ו-Power Platform ולא למחוק את סימני הכיווניות הבלתי נראים סביב המילים באנגלית."
  ]);
}

function slide2() {
  const slide = pptx.addSlide();
  addChrome(slide, "הבעיה העסקית", 2, "למה זה חשוב");
  addText(slide, "תהליכי חתימה עדיין נשברים בין מערכות", { x: 5.55, y: 1.18, w: 3.8, h: 0.34, fontSize: 15.5, bold: true, color: C.slate });
  card(slide, 6.6, 1.75, 2.72, 0.82, "המשתמש עובד ב-Dynamics", "אבל המסמך נשלח ממערכת חיצונית או במייל ידני", { accent: C.blue });
  card(slide, 6.6, 2.75, 2.72, 0.82, "הסטטוס נבדק ידנית", "אין מקור אמת אחד למי פתח, מי חתם ומה עדיין תקוע", { accent: C.amber });
  card(slide, 6.6, 3.75, 2.72, 0.82, "המסמך והנתונים חוזרים מפוזרים", "PDF בתיקייה, ערכים בהקלדה חוזרת, מעט Audit", { accent: C.green });
  placeholder(slide, 0.55, 1.25, 5.3, 3.7, "מקום לאיור Before", "Dynamics → מייל → חתימה → PDF → עדכון ידני");
  addNotes(slide, [
    "מטרת השקף: ליצור הזדהות עם הכאב בלי לתקוף את המצב הקיים.",
    "מה להגיד: ברוב הארגונים Dynamics 365 הוא מרכז העבודה, אבל רגע החתימה מוציא את המשתמש החוצה. שם נוצרות טעויות, עיכובים וחוסר שקיפות.",
    "הכנה למציג: להביא דוגמה אחת מהלקוח, למשל KYC, חוזה שירות או טופס הצטרפות.",
    "שאלה לקהל: איפה אצלכם היום נשמר המסמך החתום, ואיך המשתמש יודע שהתהליך הושלם?"
  ]);
}

function slide3() {
  const slide = pptx.addSlide();
  addChrome(slide, "ההזדמנות", 3, "המסר המרכזי");
  addText(slide, "החתימה צריכה להיות חלק מהרשומה העסקית", { x: 4.2, y: 1.0, w: 5.1, h: 0.38, fontSize: 16, bold: true, color: C.slate });
  addText(slide, "לא פעולה חיצונית, לא קובץ שנשלח ידנית, ולא תהליך שהמשתמש צריך לרדוף אחריו.", { x: 4.25, y: 1.48, w: 5.0, h: 0.36, fontSize: 10.2, color: C.muted });
  const cx = 2.65;
  const cy = 2.7;
  slide.addShape(S.ellipse, { x: cx - 0.75, y: cy - 0.75, w: 1.5, h: 1.5, fill: { color: C.green }, line: { color: C.green } });
  addText(slide, "רשומה עסקית", { x: cx - 0.56, y: cy - 0.1, w: 1.12, h: 0.2, fontSize: 9.2, bold: true, color: "FFFFFF", align: "center" });
  [[1.2, 1.2, "תבנית"], [4.0, 1.12, "נמען"], [5.0, 2.75, "סטטוס"], [3.9, 4.22, "PDF חתום"], [1.0, 4.12, "נתונים שחזרו"], [0.25, 2.65, "Audit"]].forEach(([x, y, text]) => {
    slide.addShape(S.roundRect, { x, y, w: 1.2, h: 0.38, rectRadius: 0.03, fill: { color: C.surface }, line: { color: C.line } });
    addText(slide, text, { x: x + 0.1, y: y + 0.11, w: 1.0, h: 0.12, fontSize: 7.6, bold: true, color: C.slate, align: "center", margin: 0 });
  });
  placeholder(slide, 6.25, 2.2, 3.02, 2.35, "מקום לצילום מסך", "רשומה עם Timeline וסטטוס חתימה");
  addNotes(slide, [
    "מטרת השקף: להעביר את השינוי התפיסתי. לא מוכרים חתימה, מוכרים סגירת תהליך.",
    "מה להגיד: כאשר כל האובייקטים של החתימה קשורים לרשומה, Dynamics 365 נשאר מקור האמת. המשתמש רואה את ההקשר, את המסמך ואת הסטטוס במקום אחד.",
    "הכנה למציג: כדאי להציג כאן רשימה קצרה של תהליכים רלוונטיים ללקוח ולא רשימת פיצ'רים טכנית."
  ]);
}

function slide4() {
  const slide = pptx.addSlide();
  addChrome(slide, "הפתרון במשפט אחד", 4, "easydo בתוך Dynamics");
  addText(slide, "המשתמש שולח מסמך לחתימה מתוך Dynamics 365, easydo מנהלת את החתימה, והנתונים חוזרים אל Dataverse.", { x: 1.08, y: 1.08, w: 8.25, h: 0.72, fontSize: 18, bold: true, color: C.slate, align: "center" });
  flowNode(slide, 6.65, 2.42, 2.2, "Send", "שליחה מתוך הרשומה", C.blue);
  arrow(slide, 6.24, 2.8, -0.65);
  flowNode(slide, 3.88, 2.42, 2.2, "Sign", "חתימה בערוץ הנבחר", C.green);
  arrow(slide, 3.45, 2.8, -0.65);
  flowNode(slide, 1.1, 2.42, 2.2, "Return", "סטטוס, PDF ונתונים", C.amber);
  card(slide, 6.65, 3.68, 2.2, 0.7, "מה רואים המשתמשים", "כפתור, אשף קצר, סטטוס ברור", { fill: C.blueSoft, line: "CAD8FF" });
  card(slide, 3.88, 3.68, 2.2, 0.7, "מה easydo עושה", "חתימה, קישור, מסמך סופי", { fill: C.greenSoft, line: "BCE8CF" });
  card(slide, 1.1, 3.68, 2.2, 0.7, "מה Dynamics מקבל", "מעקב, Audit, מסמך וערכים", { fill: C.amberSoft, line: "FAD58F" });
  addNotes(slide, [
    "מטרת השקף: לתת משפט זכיר שאפשר לחזור אליו לאורך המצגת.",
    "מה להגיד: שלושת הפעלים הם כל הסיפור: Send, Sign, Return. כל היתר הוא שכבת יישום שמוודאת שזה עובד בארגון אמיתי.",
    "הכנה למציג: לעצור כאן לשנייה. אם הקהל מבין את השקף הזה, שאר המצגת תהיה קלה יותר.",
    "RTL: שלושת המילים באנגלית מופרדות בכרטיסים כדי למנוע ערבוב כיווניות בתוך משפט עברי ארוך."
  ]);
}

function slide5() {
  const slide = pptx.addSlide();
  addChrome(slide, "חוויית המשתמש", 5, "מה קורה בפועל");
  placeholder(slide, 0.55, 1.06, 4.15, 3.95, "מקום לרצף מסכים", "כפתור → Wizard → Review → Send");
  const steps = [
    ["1", "פתיחת רשומה", "Contact, Case או רשומה עסקית אחרת"],
    ["2", "בחירת תבנית", "תבניות easydo מסונכרנות ל-Dataverse"],
    ["3", "אימות נתונים", "שדות מתמלאים מראש וניתנים לנעילה"],
    ["4", "שליחה ומעקב", "סטטוס וקישור נשמרים על הבקשה"]
  ];
  steps.forEach(([num, title, body], i) => {
    const y = 1.1 + i * 0.92;
    slide.addShape(S.ellipse, { x: 8.72, y, w: 0.42, h: 0.42, fill: { color: i === 3 ? C.green : C.blue }, line: { color: i === 3 ? C.green : C.blue } });
    addText(slide, num, { x: 8.84, y: y + 0.12, w: 0.18, h: 0.1, fontSize: 7.5, bold: true, color: "FFFFFF", align: "center", margin: 0 });
    addText(slide, title, { x: 5.3, y: y + 0.02, w: 3.15, h: 0.2, fontSize: 11.3, bold: true, color: C.slate });
    addText(slide, body, { x: 5.3, y: y + 0.31, w: 3.15, h: 0.2, fontSize: 8.4, color: C.muted });
  });
  addNotes(slide, [
    "מטרת השקף: להראות שהמשתמש העסקי פוגש תהליך קצר ולא ארכיטקטורה.",
    "מה להגיד: המטרה היא שהנציג או מנהל הלקוח לא יצאו מ-Dynamics 365. הם בוחרים תבנית, בודקים נתונים, שולחים ורואים סטטוס.",
    "הכנה למציג: להוסיף צילום מסך של ה-side pane או ה-send wizard. אם אין צילום, להשתמש ב-mockup נקי שמציג את ארבעת השלבים.",
    "דגש מכירה: פחות הדרכה, פחות טעויות, פחות מעבר בין מערכות."
  ]);
}

function slide6() {
  const slide = pptx.addSlide();
  addChrome(slide, "מה חוזר ל-Dynamics", 6, "Closing the loop");
  addText(slide, "הערך האמיתי הוא לא רק קובץ חתום, אלא סגירת הלולאה העסקית", { x: 3.2, y: 1.04, w: 6.08, h: 0.4, fontSize: 15, bold: true, color: C.slate });
  metric(slide, 7.75, 1.8, "1", "סטטוס חתימה");
  metric(slide, 5.95, 1.8, "2", "מסמך PDF");
  metric(slide, 4.15, 1.8, "3", "ערכי שדות");
  metric(slide, 2.35, 1.8, "4", "Audit ותמיכה");
  placeholder(slide, 0.65, 3.0, 8.65, 1.6, "מקום לצילום Timeline", "בקשת חתימה שהושלמה + PDF חתום + ערכים שחזרו");
  addNotes(slide, [
    "מטרת השקף: להסביר למה האינטגרציה עמוקה יותר משליחת לינק.",
    "מה להגיד: לאחר השליחה המערכת ממשיכה לעבוד. היא בודקת סטטוס, מזהה צפייה או חתימה, מורידה את ה-PDF החתום ושומרת את ערכי השדות שנאספו.",
    "הכנה למציג: להראות דוגמה של בקשת חתימה Completed ודוגמה למסמך שהופיע בציר הזמן של הרשומה המקורית.",
    "שאלה אפשרית: האם חייבים לכתוב את הערכים לשדות המקור? תשובה: אפשר, לפי מדיניות הלקוח. הפתרון מחזיר את הערכים ל-Dataverse כדי לאפשר מיפוי מבוקר."
  ]);
}

function slide7() {
  const slide = pptx.addSlide();
  addChrome(slide, "מיפוי שדות חכם", 7, "נתונים לפני ואחרי חתימה");
  placeholder(slide, 0.55, 1.0, 4.25, 3.95, "מקום לצילום PCF", "מסך Template Field Mapping");
  card(slide, 6.05, 1.05, 3.22, 0.82, "מילוי מקדים", "נתונים מהרשומה מוזרמים אל שדות easydo לפני שהלקוח פותח את הטופס", { accent: C.blue });
  card(slide, 6.05, 2.05, 3.22, 0.82, "נעילת ערכים", "שדות כמו שם, מספר לקוח או תעודת זהות יכולים להישאר לקריאה בלבד", { accent: C.green });
  card(slide, 6.05, 3.05, 3.22, 0.82, "קריאה חזרה", "ערכים שהלקוח מילא נשמרים כנתוני חתימה ב-Dataverse", { accent: C.amber });
  addText(slide, "דוגמה: contact.emailaddress1 → שדה דואר אלקטרוני בתבנית", { x: 5.85, y: 4.35, w: 3.42, h: 0.22, fontSize: 8.2, color: C.muted });
  addNotes(slide, [
    "מטרת השקף: להוכיח שהפתרון מחבר את התבנית לנתוני העסק, ולא רק שולח PDF.",
    "מה להגיד: מנהל המערכת מסנכרן תבניות easydo, רואה את השדות שלהן וממפה אותם לשדות Dynamics 365. אפשר לקבוע כיוון: prefill, read-back או דו-כיווני.",
    "הכנה למציג: להציג צילום של PCF mapping עם שדות אמיתיים. להדגיש שהמדיניות נשלטת ב-Dynamics ולא על ידי עורך התבנית בלבד.",
    "RTL: בשורת הדוגמה יש ביטוי טכני באנגלית. אם עורכים אותו, להשאיר אותו כשורה נפרדת ולא בתוך פסקה עברית צפופה."
  ]);
}

function slide8() {
  const slide = pptx.addSlide();
  addChrome(slide, "ערוצי שליחה והפצה", 8, "גמישות מסחרית");
  addText(slide, "הארגון בוחר מי שולח את הקישור ובאיזה ערוץ", { x: 4.1, y: 1.05, w: 5.2, h: 0.34, fontSize: 15, bold: true, color: C.slate });
  flowNode(slide, 6.95, 2.0, 2.1, "ערוץ ראשי", "easydo שולחת Native", C.green);
  flowNode(slide, 3.95, 2.0, 2.1, "ערוצים נוספים", "Power Automate או CIJ", C.blue);
  flowNode(slide, 0.95, 2.0, 2.1, "הפצה עצמית", "הארגון מפיץ קישור", C.amber);
  arrow(slide, 6.55, 2.38, -0.58);
  arrow(slide, 3.55, 2.38, -0.58);
  card(slide, 6.9, 3.25, 2.15, 0.84, "Email / SMS / WhatsApp", "ערוץ Native אחד לפי מדיניות הארגון", { fill: C.greenSoft, line: "BDE8CF" });
  card(slide, 3.9, 3.25, 2.15, 0.84, "Flow / Journey", "הצהרה מראש על מנגנון ההפצה", { fill: C.blueSoft, line: "CAD8FF" });
  card(slide, 0.9, 3.25, 2.15, 0.84, "קישור בלבד", "easydo שותקת, הלקוח מפיץ בעצמו", { fill: C.amberSoft, line: "FAD58F" });
  addNotes(slide, [
    "מטרת השקף: להראות שהפתרון לא ננעל לערוץ אחד.",
    "מה להגיד: יש מודל ברור. ערוץ ראשי אחד יכול להישלח Native על ידי easydo. אם רוצים ערוצים נוספים או מסרים מותאמים, easydo מחזירה קישור והארגון מפיץ אותו דרך Power Automate, Customer Insights או מנגנון אחר.",
    "הכנה למציג: אם הלקוח מדבר על WhatsApp או SMS, להדגיש את הצורך במספר טלפון תקין ובמדיניות הפצה מוגדרת.",
    "דגש מכירה: זה מאפשר להתחיל פשוט, ואז להרחיב בלי לשנות את מודל הנתונים."
  ]);
}

function slide9() {
  const slide = pptx.addSlide();
  addChrome(slide, "Contact Center בזמן אמת", 9, "תרחיש מובחן");
  placeholder(slide, 0.55, 1.02, 4.45, 3.9, "מקום לצילום Agent Workspace", "שיחה חיה + כפתור easydo + תוצאת חתימה");
  addText(slide, "חתימה יכולה להתרחש תוך כדי שיחה חיה", { x: 5.4, y: 1.1, w: 3.9, h: 0.36, fontSize: 15, bold: true, color: C.slate });
  card(slide, 6.05, 1.75, 3.2, 0.73, "1. הנציג מזהה שיחה פעילה", "הפאנל קורא את ה-Conversation ואת הלקוח המקושר", { accent: C.blue });
  card(slide, 6.05, 2.62, 3.2, 0.73, "2. הקישור נשלח באותו ערוץ", "Chat, SMS או WhatsApp - בלי להוציא את הלקוח מהשיחה", { accent: C.green });
  card(slide, 6.05, 3.49, 3.2, 0.73, "3. התוצאה חוזרת לנציג", "אפשר לראות חתימה בזמן אמת ולשמור על Contact או Case", { accent: C.amber });
  addNotes(slide, [
    "מטרת השקף: לתת תרחיש מרשים ומוחשי שמבדל את האינטגרציה.",
    "מה להגיד: במקום לשלוח את הלקוח למייל אחרי השיחה, הנציג שולח קישור חתימה בתוך הערוץ שבו הלקוח כבר נמצא. זה מקצר תהליך ומעלה סיכוי להשלמה בזמן אמת.",
    "הכנה למציג: להציג צילום מסך של Customer Service workspace או Contact Center עם productivity pane.",
    "דגש עסקי: התרחיש מתאים לשירות לקוחות, אישורים מהירים, תיקוני פרטים, טפסים רגולטוריים ותהליכי הצטרפות."
  ]);
}

function slide10() {
  const slide = pptx.addSlide();
  addChrome(slide, "ארכיטקטורה עסקית", 10, "Power Platform native");
  addText(slide, "בנוי על רכיבי Microsoft מוכרים, עם easydo כשירות החתימה", { x: 3.1, y: 1.02, w: 6.18, h: 0.34, fontSize: 15, bold: true, color: C.slate });
  const rows = [
    ["חוויית משתמש", "Command bar, side pane, wizard, PCF", C.blue],
    ["אורקסטרציה", "Power Automate solution-aware flows", C.green],
    ["נתונים ומעקב", "Dataverse tables, status, field values, documents", C.amber],
    ["שירות חתימה", "Custom Connector מול easydo API", C.slate]
  ];
  rows.forEach(([title, body, color], i) => {
    const y = 1.62 + i * 0.78;
    slide.addShape(S.rect, { x: 2.0, y, w: 6.95, h: 0.55, fill: { color: C.surface }, line: { color: C.line } });
    slide.addShape(S.rect, { x: 8.78, y, w: 0.17, h: 0.55, fill: { color }, line: { color } });
    addText(slide, title, { x: 7.0, y: y + 0.15, w: 1.5, h: 0.14, fontSize: 8.7, bold: true, color: C.slate });
    addLtrText(slide, body, { x: 2.25, y: y + 0.15, w: 4.25, h: 0.14, fontSize: 8.1, color: C.muted, align: "left" });
  });
  placeholder(slide, 0.55, 1.62, 1.15, 3.0, "לוגואים", null);
  addNotes(slide, [
    "מטרת השקף: לתת ביטחון ל-IT בלי להיכנס ליותר מדי פרטים.",
    "מה להגיד: הפתרון נשען על רכיבים מוכרים של Power Platform: Dataverse כמודל הנתונים, Power Automate לאורקסטרציה, Custom Connector מול easydo, ורכיבי UX בתוך Dynamics 365.",
    "הכנה למציג: אם יש קהל טכני, אפשר להוסיף שקף נספח עם תרשים מפורט יותר. במצגת המכירה לא צריך להתחיל מזה.",
    "נקודה חשובה: אין צורך ב-Azure Function ב-MVP, אבל הארכיטקטורה מאפשרת להוסיף שכבה כזו בהמשך אם יש צורך ב-webhooks, עומסים גבוהים או Key Vault."
  ]);
}

function slide11() {
  const slide = pptx.addSlide();
  addChrome(slide, "אבטחה וממשל", 11, "Enterprise ready");
  card(slide, 6.65, 1.15, 2.7, 1.05, "סודות נשמרים ב-Connection", "ה-token של easydo לא נשמר בקוד, לא ב-flow ולא במצגת", { accent: C.green, shadow: true });
  card(slide, 3.7, 1.15, 2.7, 1.05, "גישה לפי הרשאות Dynamics", "מסמך חתום נגיש לפי הרשאות הרשומה המקורית", { accent: C.blue, shadow: true });
  card(slide, 0.75, 1.15, 2.7, 1.05, "תיעוד ובקרה", "סטטוסים, Audit, Integration Log וסיכומי שגיאות בטוחים", { accent: C.amber, shadow: true });
  card(slide, 5.15, 2.72, 4.2, 1.18, "Outbound only במודל הראשוני", "Power Automate קורא ל-easydo. אין endpoint נכנס ב-MVP, ולכן שטח התקיפה הראשוני קטן יותר.", { fill: C.greenSoft, line: "BDE8CF" });
  card(slide, 0.75, 2.72, 4.2, 1.18, "DLP ותפקידי אבטחה", "אפשר להפריד בין Admin, Sender, Viewer, Manager ו-Auditor לפי צורכי הארגון.", { fill: C.blueSoft, line: "CAD8FF" });
  addNotes(slide, [
    "מטרת השקף: להסיר חששות של אבטחה, Compliance ותפעול.",
    "מה להגיד: האינטגרציה נבנתה לפי עקרונות Power Platform. סודות נמצאים ב-Connection References, התקשורת מוצפנת, והרשאות המסמך נשענות על הרשאות Dynamics 365.",
    "הכנה למציג: אם יש CISO או ארכיטקט בקהל, להדגיש שאין סודות ב-source control ושאפשר להגדיר DLP על הקונקטור.",
    "שאלה צפויה: האם יש webhooks? תשובה: במודל הראשוני יש polling יוצא בלבד. ניתן להוסיף webhook מאובטח בשלב מתקדם."
  ]);
}

function slide12() {
  const slide = pptx.addSlide();
  addChrome(slide, "הערך ללקוח", 12, "Before / After");
  addText(slide, "פחות זמן, פחות טעויות, יותר שליטה", { x: 3.6, y: 1.0, w: 5.7, h: 0.36, fontSize: 16, bold: true, color: C.slate });
  slide.addShape(S.rect, { x: 5.15, y: 1.62, w: 4.12, h: 2.72, fill: { color: C.redSoft }, line: { color: "F4C7C7" } });
  addText(slide, "לפני", { x: 8.16, y: 1.86, w: 0.85, h: 0.22, fontSize: 13, bold: true, color: "9F2A2A" });
  ["שליחה ידנית מחוץ ל-Dynamics", "מעקב ב-email או Excel", "PDF נשמר במקום לא אחיד", "הקלדה חוזרת של נתונים"].forEach((item, i) => {
    addText(slide, item, { x: 5.55, y: 2.25 + i * 0.42, w: 3.2, h: 0.16, fontSize: 8.6, color: C.slate });
  });
  slide.addShape(S.rect, { x: 0.75, y: 1.62, w: 4.12, h: 2.72, fill: { color: C.greenSoft }, line: { color: "BDE8CF" } });
  addText(slide, "אחרי", { x: 3.78, y: 1.86, w: 0.85, h: 0.22, fontSize: 13, bold: true, color: C.greenDark });
  ["שליחה מתוך הרשומה", "סטטוס אוטומטי ב-Dataverse", "מסמך חתום בציר הזמן", "ערכים חוזרים כנתוני תהליך"].forEach((item, i) => {
    addText(slide, item, { x: 1.15, y: 2.25 + i * 0.42, w: 3.2, h: 0.16, fontSize: 8.6, color: C.slate });
  });
  addNotes(slide, [
    "מטרת השקף: לתרגם יכולות טכניות לערך עסקי.",
    "מה להגיד: השינוי הוא לא רק נוחות. הוא מפחית טעויות, מקצר SLA, משפר שקיפות ומאפשר בקרה על תהליכים שחוצים מערכות.",
    "הכנה למציג: אם יש נתונים פנימיים, אפשר להחליף את הרשימה במדדים כמו זמן טיפול, אחוז השלמה או מספר פעולות ידניות שנחסכות.",
    "דגש מכירה: להשתמש בשפה של תהליך, לא בשפה של אינטגרציה."
  ]);
}

function slide13() {
  const slide = pptx.addSlide();
  addChrome(slide, "תרחישי שימוש מובילים", 13, "איפה מתחילים");
  const items = [
    ["KYC / הכר את הלקוח", "מילוי פרטי לקוח, הצהרות וחתימה"],
    ["חוזה לקוח", "שליחה מתוך Contact או Account"],
    ["טופס הצטרפות", "נתונים נמשכים מהרשומה וחוזרים אחרי חתימה"],
    ["אישור שירות", "חתימה מתוך Case או Work Order"],
    ["Contact Center", "שליחה באותו ערוץ שיחה"],
    ["אישורי ציוד / רכב", "ריבוי תפקידים וסדר חתימה"]
  ];
  items.forEach(([title, body], i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = 0.75 + col * 2.95;
    const y = 1.38 + row * 1.42;
    card(slide, x, y, 2.58, 1.06, title, body, { accent: [C.green, C.blue, C.amber][col], shadow: true, fontSize: 8.0 });
  });
  placeholder(slide, 0.75, 4.45, 8.58, 0.55, "מקום לרצועת לוגואים / אייקונים", "אפשר להוסיף אייקון לכל תרחיש או צילום מסך קצר");
  addNotes(slide, [
    "מטרת השקף: לתת לקהל אפשרויות התחלה ולזהות pain point רלוונטי.",
    "מה להגיד: לא צריך להתחיל מכל הארגון. בוחרים תהליך אחד עם ערך ברור, מוכיחים אותו, ואז מרחיבים לתבניות וטבלאות נוספות.",
    "הכנה למציג: לבחור מראש 2 תרחישים שמתאימים לקהל הספציפי ולהרחיב עליהם בעל פה.",
    "טיפ: אם הקהל מגיע משירות לקוחות, להתחיל מ-Contact Center. אם הוא מגיע ממכירות או תפעול, להתחיל מחוזה לקוח או KYC."
  ]);
}

function slide14() {
  const slide = pptx.addSlide();
  addChrome(slide, "תוכנית פיילוט מוצעת", 14, "Call to action");
  const steps = [
    ["1", "בחירת תהליך אחד", "למשל KYC, חוזה או טופס שירות"],
    ["2", "חיבור תבנית easydo", "סנכרון שדות ומיפוי ל-Dynamics"],
    ["3", "דמו מקצה לקצה", "שליחה, חתימה, חזרה ל-Dataverse"],
    ["4", "הרחבה מבוקרת", "עוד טבלאות, ערוצים ותפקידי אבטחה"]
  ];
  steps.forEach(([num, title, body], i) => {
    const x = 0.85 + i * 2.15;
    slide.addShape(S.ellipse, { x: x + 0.76, y: 1.3, w: 0.58, h: 0.58, fill: { color: i === 3 ? C.green : C.blue }, line: { color: i === 3 ? C.green : C.blue } });
    addText(slide, num, { x: x + 0.94, y: 1.49, w: 0.2, h: 0.12, fontSize: 8.8, bold: true, color: "FFFFFF", align: "center", margin: 0 });
    if (i < 3) arrow(slide, x + 0.52, 1.59, -0.56);
    card(slide, x, 2.2, 1.85, 1.18, title, body, { fill: C.surface, line: C.line, fontSize: 7.7 });
  });
  addText(slide, "הצעה לפתיחה: פיילוט של שבועיים עד ארבעה שבועות על תהליך אחד עם תבנית אחת וקבוצת משתמשים מוגדרת.", { x: 1.15, y: 4.05, w: 8.0, h: 0.34, fontSize: 11.5, bold: true, color: C.slate, align: "center" });
  addNotes(slide, [
    "מטרת השקף: לסיים בפעולה ברורה ולא רק בסיכום.",
    "מה להגיד: הדרך הנכונה היא להתחיל קטן ומדיד. תהליך אחד, תבנית אחת, רשומה אחת, ואז הרחבה. זה מצמצם סיכון ומראה ערך מהר.",
    "הכנה למציג: להגיע עם הצעה קונקרטית לתהליך הפיילוט לפי הלקוח. למשל KYC על Contact או חתימה במהלך Case.",
    "CTA: לקבוע סדנת מיפוי קצרה שבה בוחרים תהליך, תבנית, שדות, ערוץ שליחה ומדדי הצלחה."
  ]);
}

function slide15() {
  const slide = pptx.addSlide();
  addChrome(slide, "נספח פנימי: עברית, RTL ומילים באנגלית", 15, "לעריכת המצגת");
  addText(slide, "שקף זה מיועד למי שעורך את המצגת, לא בהכרח להצגה ללקוח", { x: 3.15, y: 1.04, w: 6.15, h: 0.26, fontSize: 12.5, bold: true, color: C.slate });
  card(slide, 6.25, 1.55, 3.05, 0.95, "כלל 1: לא להצמיד עברית ואנגלית", "להשאיר רווח לפני ואחרי easydo, Dynamics 365, Power Platform וכל מונח באנגלית", { accent: C.green });
  card(slide, 6.25, 2.7, 3.05, 0.95, "כלל 2: פיסוק בעברית", "עדיף לסיים משפט עברי אחרי מילה עברית. אם חייבים לסיים אחרי PDF או API, לבדוק ידנית ב-PowerPoint", { accent: C.blue });
  card(slide, 2.95, 1.55, 2.95, 0.95, "כלל 3: מונחים טכניים", "כאשר יש ביטוי ארוך באנגלית, עדיף לשים אותו בשורה נפרדת או בכרטיס נפרד", { accent: C.amber });
  card(slide, 2.95, 2.7, 2.95, 0.95, "כלל 4: הערות מציג", "לכל שקף יש notes עם מטרת השקף, מה להגיד, הכנה ותשובות לשאלות", { accent: C.slate });
  placeholder(slide, 0.65, 1.55, 1.85, 2.1, "בדיקת RTL", "לפתוח ב-PowerPoint ולבדוק חזותית לפני שליחה");
  addText(slide, "הסקריפט עוטף מונחים באנגלית בסימני LRM בלתי נראים כדי לצמצם בעיות הדבקה ופיסוק. אם עורכים ידנית, חשוב לבדוק שוב.", { x: 0.8, y: 4.28, w: 8.4, h: 0.28, fontSize: 10.2, color: C.muted, align: "center" });
  addNotes(slide, [
    "מטרת השקף: לשמש checklist פנימי לעריכה עברית ו-RTL.",
    "מה להגיד אם מציגים אותו: במצגות עברית עם מילים באנגלית, הבעיה המרכזית היא לא התוכן אלא הכיווניות. לכן יש לבצע בדיקה חזותית אחרי כל שינוי ידני.",
    "הכנה למציג: אם שולחים ללקוח, אפשר להסתיר או למחוק את השקף הזה. אם עובדים בצוות, להשאיר אותו כנספח פנימי.",
    "כלל עבודה: לא לערוך מונחי English בתוך משפטים ארוכים אם אין צורך. עדיף להפוך אותם לכותרת משנה, כרטיס או label נפרד."
  ]);
}

titleSlide();
slide2();
slide3();
slide4();
slide5();
slide6();
slide7();
slide8();
slide9();
slide10();
slide11();
slide12();
slide13();
slide14();
slide15();

pptx.writeFile({ fileName: path.join(__dirname, "easydo-dynamics-commercial-deck.pptx") });