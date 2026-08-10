import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";
import { PDFDocument, StandardFonts, rgb } from "https://esm.sh/pdf-lib@1.17.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const APP = { name: "PocketExpenses", color: "#6366F1" };

async function sendSmtpEmail(to: string, subject: string, html: string, attachments: any[] = []): Promise<boolean> {
  const host = Deno.env.get("SMTP_HOST") || "smtp-relay.brevo.com";
  const port = parseInt(Deno.env.get("SMTP_PORT") || "587");
  const user = Deno.env.get("SMTP_USER") || "";
  const pass = Deno.env.get("SMTP_PASS") || "";
  const from = Deno.env.get("SMTP_FROM") || "no-reply@pocketapps.pt";
  const replyTo = Deno.env.get("SMTP_REPLY_TO") || "suporte@pocketapps.pt";

  if (!user || !pass) {
    console.error("[EMAIL] Credenciais em falta");
    return false;
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
    tls: { rejectUnauthorized: false },
  });

  try {
    await transporter.sendMail({ from, to, replyTo, subject, html, attachments });
    console.log(`[EMAIL] Enviado para ${to}`);
    return true;
  } catch (error) {
    console.error("[EMAIL] Erro:", error);
    return false;
  }
}

function money(v: number): string {
  return new Intl.NumberFormat("pt-PT", { style: "currency", currency: "EUR" }).format(v || 0);
}

function escapeHtml(v: unknown): string {
  return String(v ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function monthLabel(d: Date): string {
  return new Intl.DateTimeFormat("pt-PT", { month: "long", year: "numeric" }).format(d);
}

function parseMonthParam(value: string): Date | null {
  const m = /^(\d{4})-(\d{1,2})$/.exec(String(value));
  if (!m) return null;
  const year = parseInt(m[1], 10);
  const month = parseInt(m[2], 10);
  if (month < 1 || month > 12) return null;
  return new Date(year, month - 1, 1);
}

async function fetchReportData(supabase: any, userId: string, appName: string, monthStart: string, monthEnd: string) {
  const { data: categories } = await supabase
    .from("categories")
    .select("id, name, color_hex")
    .eq("user_id", userId)
    .eq("app_name", appName);

  const catIds = (categories || []).map((c: any) => c.id);
  const catById = new Map((categories || []).map((c: any) => [c.id, c]));

  let expenses: any[] = [];
  if (catIds.length > 0) {
    const { data } = await supabase
      .from("expenses")
      .select("id, name, amount, type, category_id, start_date, end_date, due_day, installments, frequency, is_active")
      .eq("user_id", userId)
      .in("category_id", catIds)
      .eq("is_active", true);
    expenses = data || [];
  }

  console.log(`[REPORT] userId=${userId} app=${appName} period=${monthStart}->${monthEnd}`);
  console.log(`[REPORT] categories=${(categories || []).length} catIds=[${catIds.join(",")}] expensesFetched=${expenses.length}`);

  let total = 0;
  let recurring = 0;
  let unique = 0;
  let count = 0;
  const byCategory = new Map<string, { amount: number; color: string }>();
  const items: { name: string; amount: number; type: string; category: string; when: string }[] = [];

  const start = new Date(monthStart);
  const end = new Date(monthEnd);

  const occursInMonth = (e: any): boolean => {
    if (e.type === "unique") {
      const s = e.start_date ? new Date(e.start_date + "T00:00:00") : null;
      return !!s && s >= start && s < end;
    }
    if (!e.start_date) return false;
    const s = new Date(e.start_date + "T00:00:00");
    const endD = e.end_date ? new Date(e.end_date + "T00:00:00") : null;
    if (endD && endD < start) return false;
    if (e.installments && e.installments > 0) {
      return s < end;
    }
    const freq = e.frequency || 1;
    let cursor = new Date(s);
    let count = 0;
    while (cursor < end && count < 2400) {
      if (cursor >= start) return true;
      cursor.setMonth(cursor.getMonth() + freq);
      count++;
    }
    return false;
  };

  for (const e of expenses || []) {
    const inMonth = occursInMonth(e);
    console.log(
      `[REPORT] expense id=${e.id} name="${e.name}" type=${e.type} amount=${e.amount} start=${e.start_date} end=${e.end_date} due=${e.due_day} freq=${e.frequency} inst=${e.installments} inMonth=${inMonth}`,
    );
    if (!inMonth) continue;
    const amt = Number(e.amount) || 0;
    total += amt;
    count++;
    if (e.type === "recurring") recurring += amt;
    else unique += amt;
    const cat = catById.get(e.category_id);
    const catName = cat?.name || "Sem Categoria";
    const prev = byCategory.get(catName);
    byCategory.set(catName, {
      amount: (prev?.amount || 0) + amt,
      color: cat?.color_hex || "#6366F1",
    });
    items.push({
      name: e.name,
      amount: amt,
      type: e.type,
      category: catName,
      when: e.type === "unique"
        ? (e.start_date || "")
        : (e.due_day ? `Dia ${e.due_day}` : e.start_date || ""),
    });
  }

  const sortedCat = [...byCategory.entries()].sort((a, b) => b[1].amount - a[1].amount);
  const sortedItems = items.sort((a, b) => b.amount - a.amount);
  console.log(`[REPORT] RESULT total=${total} recurring=${recurring} unique=${unique} count=${count} items=${items.length}`);
  return { total, recurring, unique, count, byCategory: sortedCat, items: sortedItems };
}

function statsRowsHtml(data: any): string {
  return `<table width="100%" cellpadding="0" cellspacing="0" style="margin:20px 0;">
    <tr>
      <td style="width:25%; text-align:center; background-color:#f9fafb; border-radius:8px; padding:12px 4px;">
        <div style="font-size:20px; font-weight:700; color:#111827;">${money(data.total)}</div>
        <div style="color:#6b7280; font-size:12px; margin-top:4px;">Total</div>
      </td>
      <td style="width:25%; text-align:center; padding:12px 4px;">
        <div style="font-size:20px; font-weight:700; color:#111827;">${money(data.recurring)}</div>
        <div style="color:#6b7280; font-size:12px; margin-top:4px;">Recorrentes</div>
      </td>
      <td style="width:25%; text-align:center; padding:12px 4px;">
        <div style="font-size:20px; font-weight:700; color:#111827;">${money(data.unique)}</div>
        <div style="color:#6b7280; font-size:12px; margin-top:4px;">Únicas</div>
      </td>
      <td style="width:25%; text-align:center; padding:12px 4px;">
        <div style="font-size:20px; font-weight:700; color:#111827;">${data.count}</div>
        <div style="color:#6b7280; font-size:12px; margin-top:4px;">Despesas</div>
      </td>
    </tr>
  </table>`;
}

function buildExpensesTableHtml(items: any[]): string {
  if (!items || items.length === 0) return "";
  const rows = items
    .map((it: any) => `<tr>
      <td style="padding:8px 0; color:#111827; font-size:14px; font-weight:600; width:38%;">${escapeHtml(it.name)}</td>
      <td style="padding:8px 0; color:#6b7280; font-size:13px; width:22%;">${escapeHtml(it.category)}</td>
      <td style="padding:8px 0; color:#6b7280; font-size:12px; width:20%;">${it.type === "recurring" ? "Recorrente" : "Única"}${it.when ? " · " + escapeHtml(it.when) : ""}</td>
      <td style="padding:8px 0; text-align:right; color:#111827; font-size:14px; font-weight:600; width:20%;">${money(it.amount)}</td>
    </tr>`)
    .join("");
  return `<table width="100%" cellpadding="0" cellspacing="0" style="margin:8px 0 0 0;">${rows}</table>`;
}

function buildShellHtml(title: string, subtitle: string, bodyHtml: string, unsubscribeUrl: string): string {
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0; padding:0; background-color:#f3f4f6; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6; padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <tr><td style="background-color:${APP.color}; padding:40px 30px; text-align:center;">
          <h1 style="color:#ffffff; margin:0; font-size:26px;">${APP.name}</h1>
        </td></tr>
        <tr><td style="padding:40px 30px;">
          <h2 style="color:#111827; margin:0 0 8px 0; font-size:20px;">${title}</h2>
          <p style="color:#6b7280; margin:0 0 8px 0; font-size:15px;">${subtitle}</p>
          ${bodyHtml}
          <table cellpadding="0" cellspacing="0" style="margin:24px auto 0 auto;">
            <tr>
              <td style="background-color:${APP.color}; border-radius:8px; padding:14px 32px;">
                <a href="https://pocketapps.pt" style="color:#ffffff; text-decoration:none; font-size:15px; font-weight:600;">Abrir ${APP.name}</a>
              </td>
            </tr>
          </table>
        </td></tr>
        <tr><td style="padding:24px 30px; border-top:1px solid #e5e7eb;">
          <p style="color:#9ca3af; font-size:13px; margin:0; text-align:center;">
            PocketApps · Relatório gerado automaticamente.<br>
            <a href="${unsubscribeUrl}" style="color:#9ca3af;">Cancelar subscrição destes relatórios</a>
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function buildSimpleReportHtml(userName: string, data: any, monthStart: Date, unsubscribeUrl: string): string {
  const label = monthLabel(monthStart);
  return buildShellHtml(
    `Relatório de ${label}`,
    `Olá ${userName}, aqui está o resumo das tuas despesas.`,
    `<h3 style="color:#111827; font-size:16px; margin:24px 0 0 0;">Visão geral</h3>${statsRowsHtml(data)}`,
    unsubscribeUrl,
  );
}

function buildSplitBarHtml(data: any): string {
  const total = data.total > 0 ? data.total : 1;
  const recPct = Math.round((data.recurring / total) * 100);
  const uniPct = 100 - recPct;
  return `<table width="100%" cellpadding="0" cellspacing="0" style="margin:18px 0 0 0;">
    <tr>
      <td style="color:#374151; font-size:13px; padding-bottom:6px;">Recorrentes vs únicas</td>
    </tr>
    <tr>
      <td style="background-color:#e5e7eb; border-radius:6px;">
        <table width="100%" cellpadding="0" cellspacing="0"><tr>
          <td width="${recPct}%" style="background-color:${APP.color}; height:12px; border-radius:6px 0 0 6px;"></td>
          <td width="${uniPct}%" style="background-color:#10B981; height:12px; border-radius:0 6px 6px 0;"></td>
        </tr></table>
      </td>
    </tr>
    <tr>
      <td style="padding-top:8px; font-size:12px; color:#6b7280;">
        <span style="color:${APP.color};">■</span> Recorrentes ${money(data.recurring)} &nbsp;&nbsp;&nbsp;
        <span style="color:#10B981;">■</span> Únicas ${money(data.unique)}
      </td>
    </tr>
  </table>`;
}

function buildDetailedReportHtml(userName: string, data: any, monthStart: Date, includeCategories: boolean, includeCharts: boolean, unsubscribeUrl: string): string {
  const label = monthLabel(monthStart);
  const max = data.byCategory.length ? data.byCategory[0][1].amount : 1;

  const categoriesHtml = includeCategories
    ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;">
       ${data.byCategory
         .map(([name, { amount: amt }]: [string, { amount: number; color: string }]) => {
           const pct = max > 0 ? Math.round((amt / max) * 100) : 0;
           return `<tr>
             <td style="padding:6px 0; color:#374151; font-size:14px; width:45%;">${name}</td>
             <td style="width:35%; padding:6px 0;"><table width="100%" cellpadding="0" cellspacing="0"><tr><td style="background-color:#e5e7eb; border-radius:4px;"><table width="${pct}%" cellpadding="0" cellspacing="0"><tr><td style="background-color:${APP.color}; height:8px; border-radius:4px;"></td></tr></table></td></tr></table></td>
             <td style="padding:6px 0; text-align:right; color:#111827; font-size:14px; font-weight:600;">${money(amt)}</td>
           </tr>`;
         })
         .join("")}
     </table>`
    : "";

  const chartsHtml = includeCharts
    ? `<h3 style="color:#111827; font-size:16px; margin:24px 0 8px 0;">Gráficos</h3>
       <table width="100%" cellpadding="0" cellspacing="0" style="margin:4px 0 0 0;">
         ${data.byCategory.length === 0
           ? `<tr><td style="color:#9ca3af; font-size:13px; padding:8px 0;">Sem despesas neste mês.</td></tr>`
           : data.byCategory
               .map(([name, { amount: amt, color }]: [string, { amount: number; color: string }]) => {
                 const pct = max > 0 ? Math.round((amt / max) * 100) : 0;
                 return `<tr>
                   <td style="padding:5px 0; color:#374151; font-size:13px; width:38%;">${name}</td>
                   <td style="padding:5px 0; width:46%;"><table width="100%" cellpadding="0" cellspacing="0"><tr><td style="background-color:#e5e7eb; border-radius:4px;"><table width="${pct}%" cellpadding="0" cellspacing="0"><tr><td style="background-color:${color}; height:10px; border-radius:4px;"></td></tr></table></td></tr></table></td>
                   <td style="padding:5px 0; text-align:right; color:#111827; font-size:13px; font-weight:600; width:16%;">${money(amt)}</td>
                 </tr>`;
               })
               .join("")}
       </table>
       ${data.byCategory.length > 0 ? buildSplitBarHtml(data) : ""}`
    : "";

  const bodyHtml = `${chartsHtml}${statsRowsHtml(data)}<h3 style="color:#111827; font-size:16px; margin:24px 0 8px 0;">Por categoria</h3>${categoriesHtml}<h3 style="color:#111827; font-size:16px; margin:24px 0 8px 0;">Despesas do mês</h3>${buildExpensesTableHtml(data.items)}`;
  return buildShellHtml(
    `Relatório de ${label}`,
    `Olá ${userName}, aqui está o resumo das tuas despesas.`,
    bodyHtml,
    unsubscribeUrl,
  );
}

function pdfSafe(text: string): string {
  return String(text ?? "")
    .replace(/[–—]/g, "-")
    .replace(/[’‘]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/·/g, "-")
    .replace(/…/g, "...")
    .replace(/[^\x00-\xFF\u20AC]/g, "");
}

function hexToRgb(hex: string): any {
  const m = /^#?([0-9a-f]{6})$/i.exec(String(hex || "").trim());
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return rgb(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255);
}

async function buildReportPdf(opts: {
  userName: string;
  data: any;
  monthStart: Date;
  reportType: string;
  includeCategories: boolean;
  includeCharts: boolean;
}): Promise<Uint8Array> {
  const { userName, data, monthStart, reportType, includeCategories, includeCharts } = opts;
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const pageWidth = 595.28;
  const pageHeight = 841.89;
  const margin = 50;
  const primary = rgb(0.388, 0.4, 0.945);
  const textDark = rgb(0.067, 0.094, 0.153);
  const textGray = rgb(0.42, 0.45, 0.5);
  const lightBg = rgb(0.976, 0.98, 0.984);
  const lineColor = rgb(0.898, 0.91, 0.918);
  const green = rgb(0.063, 0.725, 0.506);
  const white = rgb(1, 1, 1);

  let page = doc.addPage([pageWidth, pageHeight]);
  let y = pageHeight - 40;

  const ensureSpace = (needed: number): void => {
    if (y - needed < margin) {
      page = doc.addPage([pageWidth, pageHeight]);
      y = pageHeight - 40;
    }
  };

  const sectionTitle = (text: string): void => {
    ensureSpace(32);
    page.drawText(text, { x: margin, y, size: 15, font: bold, color: textDark });
    y -= 22;
  };

  const drawFitText = (text: string, x: number, baseY: number, maxWidth: number, size: number, color: any, f: any = font): void => {
    let s = size;
    while (s > 6 && f.widthOfTextAtSize(text, s) > maxWidth) s -= 0.5;
    page.drawText(text, { x, y: baseY, size: s, font: f, color });
  };

  page.drawRectangle({ x: 0, y: pageHeight - 80, width: pageWidth, height: 80, color: primary });
  page.drawText("PocketExpenses", { x: margin, y: pageHeight - 52, size: 22, font: bold, color: white });

  y = pageHeight - 130;
  page.drawText(`Relatório de ${pdfSafe(monthLabel(monthStart))}`, { x: margin, y, size: 20, font: bold, color: textDark });
  y -= 26;
  page.drawText(`Olá ${pdfSafe(userName)}, aqui está o resumo das tuas despesas.`, { x: margin, y, size: 12, font, color: textGray });
  y -= 28;

  const stats = [
    { v: money(data.total), l: "Total" },
    { v: money(data.recurring), l: "Recorrentes" },
    { v: money(data.unique), l: "Únicas" },
    { v: String(data.count), l: "Despesas" },
  ];
  const gap = 12;
  const boxW = (pageWidth - margin * 2 - gap * 3) / 4;
  const boxH = 56;
  ensureSpace(boxH + 24);
  stats.forEach((s, i) => {
    const x = margin + i * (boxW + gap);
    page.drawRectangle({ x, y: y - boxH, width: boxW, height: boxH, color: lightBg, borderColor: lineColor, borderWidth: 1 });
    drawFitText(pdfSafe(s.v), x + 8, y - 30, boxW - 16, 13, textDark, bold);
    page.drawText(s.l, { x: x + 8, y: y - 14, size: 9, font, color: textGray });
  });
  y -= boxH + 26;

  const drawCatBars = (withColors: boolean): void => {
    const maxAmt = data.byCategory.length ? data.byCategory[0][1].amount : 1;
    const barX = margin + 180;
    const barMaxW = 250;
    for (const [name, { amount: amt, color: hex }] of data.byCategory) {
      ensureSpace(24);
      drawFitText(pdfSafe(name), margin, y, 170, 11, textDark);
      const w = maxAmt > 0 ? Math.max((amt / maxAmt) * barMaxW, 3) : 3;
      page.drawRectangle({ x: barX, y: y - 4, width: barMaxW, height: 12, color: lineColor });
      page.drawRectangle({ x: barX, y: y - 4, width: w, height: 12, color: withColors ? (hexToRgb(hex) || primary) : primary });
      drawFitText(money(amt), barX + barMaxW + 10, y, 80, 11, textDark, bold);
      y -= 24;
    }
  };

  if (includeCharts && data.byCategory.length > 0) {
    sectionTitle("Gráficos");
    drawCatBars(true);
    ensureSpace(50);
    y -= 8;
    page.drawText("Recorrentes vs únicas", { x: margin, y, size: 11, font: bold, color: textDark });
    y -= 20;
    const total = data.total > 0 ? data.total : 1;
    const barW = pageWidth - margin * 2;
    const recW = (data.recurring / total) * barW;
    page.drawRectangle({ x: margin, y: y - 4, width: barW, height: 14, color: lineColor });
    page.drawRectangle({ x: margin, y: y - 4, width: recW, height: 14, color: primary });
    page.drawRectangle({ x: margin + recW, y: y - 4, width: barW - recW, height: 14, color: green });
    y -= 26;
    page.drawText(`■ ${money(data.recurring)} Recorrentes      ■ ${money(data.unique)} Únicas`, { x: margin, y, size: 10, font, color: textGray });
    y -= 16;
  }

  if (reportType === "detailed" && includeCategories && data.byCategory.length > 0) {
    sectionTitle("Por categoria");
    drawCatBars(false);
  }

  if (reportType === "detailed" && data.items.length > 0) {
    sectionTitle("Despesas do mês");
    ensureSpace(24);
    page.drawText("Despesa", { x: margin, y, size: 10, font: bold, color: textGray });
    page.drawText("Categoria", { x: margin + 200, y, size: 10, font: bold, color: textGray });
    page.drawText("Tipo", { x: margin + 320, y, size: 10, font: bold, color: textGray });
    page.drawText("Valor", { x: pageWidth - margin - 80, y, size: 10, font: bold, color: textGray });
    y -= 12;
    page.drawLine({ start: { x: margin, y }, end: { x: pageWidth - margin, y }, thickness: 0.5, color: lineColor });
    y -= 16;
    for (const it of data.items) {
      ensureSpace(22);
      drawFitText(pdfSafe(it.name), margin, y, 190, 11, textDark);
      drawFitText(pdfSafe(it.category), margin + 200, y, 110, 10, textGray);
      drawFitText(pdfSafe(it.type === "recurring" ? `Recorrente${it.when ? " · " + it.when : ""}` : `Única${it.when ? " · " + it.when : ""}`), margin + 320, y, 120, 10, textGray);
      drawFitText(pdfSafe(money(it.amount)), pageWidth - margin - 80, y, 80, 11, textDark, bold);
      y -= 20;
    }
  }

  for (const p of doc.getPages()) {
    p.drawText("PocketApps · Relatório gerado automaticamente.", { x: margin, y: 30, size: 9, font, color: textGray });
  }
  return doc.save();
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json().catch(() => ({}));
    const authHeader = req.headers.get("Authorization");
    const jwt = authHeader ? authHeader.replace(/^Bearer\s+/i, "").trim() : "";
    const apikey = req.headers.get("apikey") || "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const isServiceRole = (jwt && jwt === serviceRole) || (!jwt && apikey === serviceRole);

    let supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRole,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    let user: { id: string; email?: string | undefined } | null = null;

    if (jwt) {
      const client = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        {
          global: { headers: { Authorization: `Bearer ${jwt}` } },
          auth: { autoRefreshToken: false, persistSession: false },
        },
      );
      const { data, error } = await client.auth.getUser(jwt);
      if (!error && data?.user) {
        user = data.user;
        supabase = client;
      }
    }

    let targets: { user_id: string; email: string }[] = [];

    if (user && user.email) {
      targets = [{ user_id: user.id, email: user.email }];
    } else if (isServiceRole) {
      const now = new Date();
      const day = now.getDate();
      const hour = now.getHours();
      const { data: prefs } = await supabase
        .from("report_preferences")
        .select("user_id, report_day, report_hour, include_categories, include_charts, app_name, report_type, unsubscribe_token")
        .eq("email_reports_enabled", true)
        .eq("report_day", day)
        .eq("report_hour", hour);

      const { data: authUsers } = await supabase.auth.admin.listUsers();
      const emailById = new Map((authUsers?.users || []).map((u: any) => [u.id, u.email || ""]));

      for (const p of prefs || []) {
        if (!emailById.get(p.user_id)) continue;
        targets.push({ user_id: p.user_id, email: emailById.get(p.user_id) });
      }
    } else {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const results: string[] = [];
    const testData: any[] = [];

    for (const t of targets) {
      const isTest = !!user;
      const now = new Date();
      const testMonth = isTest && body.month ? parseMonthParam(body.month) : null;
      const monthStart = isTest
        ? (testMonth ?? new Date(now.getFullYear(), now.getMonth(), 1))
        : new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const monthEnd = testMonth
        ? new Date(testMonth.getFullYear(), testMonth.getMonth() + 1, 1)
        : new Date(now.getFullYear(), now.getMonth(), 1);
      let prefsRow: any = {};
      const { data: prefsData } = await supabase
        .from("report_preferences")
        .select("include_categories, include_charts, app_name, report_type, unsubscribe_token")
        .eq("user_id", t.user_id)
        .maybeSingle();
      prefsRow = prefsData || {};

      const appName = prefsRow.app_name || "expenses";
      const data = await fetchReportData(supabase, t.user_id, appName, monthStart.toISOString(), monthEnd.toISOString());
      const includeCategories = prefsRow.include_categories !== false;
      const includeCharts = prefsRow.include_charts !== false;
      const reportType = body.report_type || prefsRow.report_type || "detailed";
      const token = prefsRow.unsubscribe_token;
      const baseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const unsubscribeUrl = token
        ? `${baseUrl}/functions/v1/report-unsubscribe?token=${token}`
        : "https://pocketapps.pt";

      const userName = t.email.split("@")[0];
      const subject = `O teu relatório de ${monthLabel(monthStart)} 📊`;
      const html = reportType === "simple"
        ? buildSimpleReportHtml(userName, data, monthStart, unsubscribeUrl)
        : buildDetailedReportHtml(userName, data, monthStart, includeCategories, includeCharts, unsubscribeUrl);

      const attachments: any[] = [];
      try {
        const pdfBytes = await buildReportPdf({
          userName,
          data,
          monthStart,
          reportType,
          includeCategories,
          includeCharts,
        });
        attachments.push({
          filename: `relatorio-${monthStart.getFullYear()}-${String(monthStart.getMonth() + 1).padStart(2, "0")}.pdf`,
          content: pdfBytes,
          contentType: "application/pdf",
        });
      } catch (error) {
        console.error(`[PDF] Erro ao gerar PDF para ${t.user_id}:`, error);
      }

      const ok = await sendSmtpEmail(t.email, subject, html, attachments);
      results.push(`${t.user_id}:${reportType}:${ok ? "sent" : "failed"}`);
      if (isTest) {
        testData.push({
          month: `${monthStart.getFullYear()}-${String(monthStart.getMonth() + 1).padStart(2, "0")}`,
          monthStart: monthStart.toISOString(),
          monthEnd: monthEnd.toISOString(),
          total: data.total,
          recurring: data.recurring,
          unique: data.unique,
          count: data.count,
          items: data.items,
        });
      }
    }

    return new Response(JSON.stringify({ success: true, results, testData }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    console.error("send-monthly-report error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
