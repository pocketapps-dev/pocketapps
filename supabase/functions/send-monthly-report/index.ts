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
  const catById = new Map<string, { name: string; color_hex: string }>((categories || []).map((c: any) => [c.id, c]));

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
  const items: { name: string; amount: number; type: string; category: string; when: string; color?: string }[] = [];

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

  const CATEGORY_PALETTE = ["#EF4444", "#3B82F6", "#F59E0B", "#22C55E", "#8B5CF6", "#EC4899", "#06B6D4", "#F97316", "#14B8A6", "#78716C"];
  let sortedCat = [...byCategory.entries()].sort((a, b) => b[1].amount - a[1].amount);
  sortedCat = sortedCat.map(([name, { amount, color }]: [string, { amount: number; color: string }], i) => {
    const valid = /^#[0-9a-fA-F]{6}$/.test(color || "");
    const finalColor = valid && !/^#6366f1$/i.test(color) ? color : CATEGORY_PALETTE[i % CATEGORY_PALETTE.length];
    return [name, { amount, color: finalColor }];
  });
  const sortedItems = items.sort((a, b) => b.amount - a.amount);
  const colorByName = new Map(sortedCat.map(([name, { color }]: [string, { color: string }]) => [name, color]));
  for (const it of items) it.color = colorByName.get(it.category) || "#6366F1";
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
      <td style="padding:8px 0; color:#6b7280; font-size:13px; width:22%;"><span style="display:inline-block; width:10px; height:10px; border-radius:2px; background-color:${it.color || "#6366F1"}; vertical-align:middle; margin-right:6px;"></span>${escapeHtml(it.category)}</td>
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

function buildCategoryBarsHtml(data: any): string {
  if (data.byCategory.length === 0) return "";
  const total = data.total > 0 ? data.total : 1;
  const rows = data.byCategory
    .map(([name, { amount, color }]: [string, { amount: number; color: string }]) => {
      const pct = Math.round((amount / total) * 100);
      return `<tr>
        <td style="padding:10px 0 0 0;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td style="color:#374151; font-size:13px; padding-bottom:4px;">${escapeHtml(name)}</td>
              <td style="color:#6b7280; font-size:12px; text-align:right; padding-bottom:4px;">${pct}%</td>
            </tr>
            <tr>
              <td colspan="2" style="background-color:#f3f4f6; border-radius:5px; height:10px;">
                <table width="100%" cellpadding="0" cellspacing="0"><tr>
                  <td width="${pct}%" style="background-color:${color}; height:10px; border-radius:5px;"></td>
                  <td></td>
                </tr></table>
              </td>
            </tr>
          </table>
        </td>
      </tr>`;
    })
    .join("");
  return `<table width="100%" cellpadding="0" cellspacing="0" style="margin:22px 0 0 0;">
    <tr><td style="color:#374151; font-size:13px; padding-bottom:2px;">Despesas por categoria</td></tr>
    ${rows}
  </table>`;
}

function buildDonutSvg(data: any): string | null {
  if (!data.byCategory || data.byCategory.length === 0) return null;
  const entries = data.byCategory as [string, any][];
  const total = entries.reduce((s: number, [, c]: [string, any]) => s + c.amount, 0) || 1;

  const S = 440;
  const cx = S / 2;
  const cy = S / 2;
  const r = 138;
  const sw = 42;
  const gap = 4;
  const circ = 2 * Math.PI * r;

  const rings: string[] = [];
  const marks: string[] = [];
  let acc = 0;
  let outIdx = 0;
  for (const [, c] of entries) {
    const frac = c.amount / total;

    if (frac >= 0.999) {
      rings.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${c.color}" stroke-width="${sw}"/>`);
    } else {
      const len = Math.max(frac * circ - gap, 0.5);
      const rot = (acc / circ) * 360 - 90;
      rings.push(
        `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${c.color}" stroke-width="${sw}" stroke-dasharray="${len.toFixed(2)} ${(circ - len).toFixed(2)}" transform="rotate(${rot.toFixed(3)} ${cx} ${cy})"/>`,
      );
    }

    const pct = Math.round(frac * 100);
    const midDeg = ((acc + (frac * circ) / 2) / circ) * 360 - 90;
    const rad = (midDeg * Math.PI) / 180;
    const dirX = Math.cos(rad);
    const dirY = Math.sin(rad);
    const p1r = r + sw / 2 + 3;
    const p2r = p1r + 16 + (outIdx++ % 2) * 12;
    const x1 = cx + p1r * dirX;
    const y1 = cy + p1r * dirY;
    const x2 = cx + p2r * dirX;
    const y2 = cy + p2r * dirY;
    const anchor = dirX >= 0 ? "start" : "end";
    const tx = x2 + (dirX >= 0 ? 4 : -4);
    marks.push(`<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="#94a3b8" stroke-width="1.5"/>`);
    marks.push(
      `<text x="${tx.toFixed(1)}" y="${y2.toFixed(1)}" dy="0.35em" font-family="NanumGothic" font-size="15" font-weight="bold" fill="#334155" text-anchor="${anchor}">${pct}%</text>`,
    );

    acc += frac * circ;
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">${rings.join("")}${marks.join("")}</svg>`;
}

const CHARTS_BUCKET = "report-charts";

async function fetchDonutPng(data: any): Promise<Uint8Array | null> {
  const svg = buildDonutSvg(data);
  if (!svg) return null;
  try {
    const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/svg-to-png`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
        Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""}`,
      },
      body: JSON.stringify({ svg, width: 880 }),
    });
    if (!res.ok) {
      console.error(`[Charts] svg-to-png erro: ${res.status} ${await res.text()}`);
      return null;
    }
    return new Uint8Array(await res.arrayBuffer());
  } catch (error) {
    console.error("[Charts] svg-to-png falhou:", error);
    return null;
  }
}

async function uploadDonutPng(png: Uint8Array, userId: string, monthStart: Date): Promise<string | null> {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
  try {
    await admin.storage.createBucket(CHARTS_BUCKET, { public: true }).catch(() => {});
    const stamp = Date.now();
    const path = `donuts/${userId}-${monthStart.getFullYear()}-${String(monthStart.getMonth() + 1).padStart(2, "0")}-${stamp}.png`;
    const { error } = await admin.storage.from(CHARTS_BUCKET).upload(path, png, {
      contentType: "image/png",
      upsert: false,
      cacheControl: "3600",
    });
    if (error) {
      console.error("[Charts] Upload Storage falhou:", error.message);
      return null;
    }
    return `${Deno.env.get("SUPABASE_URL")}/storage/v1/object/public/${CHARTS_BUCKET}/${path}`;
  } catch (error) {
    console.error("[Charts] Storage indisponível:", error);
    return null;
  }
}

function buildDonutLegendHtml(data: any): string {
  const rows = data.byCategory
    .map(([name, c]: [string, any]) => {
      return `<tr>
        <td style="padding:0;">
          <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc; border-radius:10px;">
            <tr>
              <td style="padding:9px 12px; vertical-align:middle; white-space:nowrap;">
                <span style="display:inline-block; width:10px; height:10px; border-radius:3px; background-color:${c.color}; margin-right:8px;"></span>
                <span style="color:#334155; font-size:13px;">${escapeHtml(name)}</span>
              </td>
              <td align="right" style="padding:9px 12px; color:#0f172a; font-size:13px; font-weight:bold; white-space:nowrap;">${money(c.amount)}</td>
            </tr>
          </table>
        </td>
      </tr>`;
    })
    .join("");
  return `<table cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse:separate; border-spacing:0 5px;">${rows}</table>`;
}

function buildChartsHtml(data: any, donutUrl: string | null): string {
  if (data.byCategory.length === 0) {
    return `<h3 style="color:#111827; font-size:16px; margin:28px 0 8px 0;">Gráficos</h3>
      <p style="color:#9ca3af; font-size:13px; margin:0;">Sem despesas neste mês.</p>`;
  }

  if (!donutUrl) {
    return `<h3 style="color:#111827; font-size:16px; margin:28px 0 8px 0;">Gráficos</h3>${buildCategoryBarsHtml(data)}${buildSplitBarHtml(data)}`;
  }

  return `<h3 style="color:#111827; font-size:16px; margin:28px 0 8px 0;">Gráficos</h3>
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td align="center" style="padding:4px 0 10px 0;">
          <img src="${donutUrl}" alt="Despesas por categoria" width="320" style="width:320px; max-width:100%; height:auto; border:0; outline:none; text-decoration:none; display:block; margin:0 auto;">
        </td>
      </tr>
    </table>
    ${buildDonutLegendHtml(data)}
    ${buildSplitBarHtml(data)}`;
}

function buildDetailedReportHtml(userName: string, data: any, monthStart: Date, donutUrl: string | null, unsubscribeUrl: string): string {
  const label = monthLabel(monthStart);

  const chartsHtml = buildChartsHtml(data, donutUrl);

  const bodyHtml = `${statsRowsHtml(data)}<h3 style="color:#111827; font-size:16px; margin:48px 0 8px 0;">Despesas do mês</h3>${buildExpensesTableHtml(data.items)}${chartsHtml}`;
  return buildShellHtml(
    `Relatório de ${label}`,
    `Olá ${userName}, aqui está o resumo das tuas despesas.`,
    bodyHtml,
    unsubscribeUrl,
  );
}

function hexToRgb(hex: string): any {
  const m = /^#?([0-9a-f]{6})$/i.exec(String(hex ?? ""));
  if (!m) return rgb(0.5, 0.5, 0.5);
  const n = parseInt(m[1], 16);
  return rgb(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255);
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

async function buildReportPdf(opts: {
  userName: string;
  data: any;
  monthStart: Date;
  reportType: string;
  donut?: { content: Uint8Array } | null;
}): Promise<Uint8Array> {
  const { userName, data, monthStart, reportType, donut } = opts;
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

  const sectionTitle = (text: string, gap = 0): void => {
    ensureSpace(32 + gap);
    y -= gap;
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

  if (reportType === "detailed" && data.items.length > 0) {
    sectionTitle("Despesas do mês", 18);
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

  if (data.byCategory.length > 0) {
    sectionTitle("Gráficos");

    const pngImage = donut?.content ? await doc.embedPng(donut.content) : null;
    if (pngImage) {
      const w = 200;
      const h = 200;
      ensureSpace(h + 16);
      page.drawImage(pngImage, { x: margin, y: y - h, width: w, height: h });
      y -= h + 14;
      const cardX = margin;
      const cardW = pageWidth - margin * 2;
      let ly = y;
      for (const [name, c] of data.byCategory as [string, any][]) {
        ensureSpace(34);
        if (ly - 30 < margin) break;
        page.drawRectangle({ x: cardX, y: ly - 28, width: cardW, height: 26, color: lightBg });
        page.drawRectangle({ x: cardX + 10, y: ly - 21, width: 9, height: 9, color: hexToRgb(c.color) });
        drawFitText(pdfSafe(name), cardX + 26, ly - 19, cardW - 130, 10, textDark);
        const vt = pdfSafe(money(c.amount));
        const vw = bold.widthOfTextAtSize(vt, 10);
        page.drawText(vt, { x: cardX + cardW - 10 - vw, y: ly - 19, size: 10, font: bold, color: textGray });
        ly -= 32;
      }
      y = ly - 14;
    }

    ensureSpace(70);
    page.drawText("Recorrentes vs únicas", { x: margin, y, size: 11, font: bold, color: textDark });
    y -= 20;
    const total = data.total > 0 ? data.total : 1;
    const splitBarW = pageWidth - margin * 2;
    const recW = (data.recurring / total) * splitBarW;
    page.drawRectangle({ x: margin, y: y - 4, width: splitBarW, height: 14, color: lineColor });
    page.drawRectangle({ x: margin, y: y - 4, width: recW, height: 14, color: primary });
    page.drawRectangle({ x: margin + recW, y: y - 4, width: splitBarW - recW, height: 14, color: green });
    y -= 26;
    const legendY = y;
    page.drawRectangle({ x: margin, y: legendY - 7, width: 9, height: 9, color: primary });
    drawFitText(`Recorrentes ${pdfSafe(money(data.recurring))}`, margin + 14, legendY, 150, 10, textGray);
    page.drawRectangle({ x: margin + 175, y: legendY - 7, width: 9, height: 9, color: green });
    drawFitText(`Únicas ${pdfSafe(money(data.unique))}`, margin + 189, legendY, 150, 10, textGray);
    y -= 16;
  }

  for (const p of doc.getPages()) {
    p.drawText("PocketApps · Relatório gerado automaticamente.", { x: margin, y: 30, size: 9, font, color: textGray });
  }
  return doc.save();
}

function isLegacyServiceRoleJwt(jwt: string): boolean {
  try {
    const parts = jwt.split(".");
    if (parts.length !== 3) return false;
    let payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    while (payload.length % 4 !== 0) payload += "=";
    const claims = JSON.parse(atob(payload));
    if (claims?.role !== "service_role" || !claims?.ref) return false;
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    return url.includes(`${claims.ref}.supabase.`) || url.startsWith(`https://${claims.ref}.`);
  } catch {
    return false;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json().catch(() => ({}));
    const authHeader = req.headers.get("Authorization");
    const jwt = authHeader ? authHeader.replace(/^Bearer\s+/i, "").trim() : "";
    const apikey = req.headers.get("apikey") || "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const bearerIsServiceRole = !!jwt && (jwt === serviceRole || isLegacyServiceRoleJwt(jwt));
    const isServiceRole = bearerIsServiceRole || (!jwt && apikey === serviceRole);

    let supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      bearerIsServiceRole && jwt ? jwt : serviceRole,
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
        .select("user_id, report_day, report_hour, app_name, report_type, unsubscribe_token")
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
        .select("app_name, report_type, unsubscribe_token")
        .eq("user_id", t.user_id)
        .maybeSingle();
      prefsRow = prefsData || {};

      const appName = prefsRow.app_name || "expenses";
      const data = await fetchReportData(supabase, t.user_id, appName, monthStart.toISOString(), monthEnd.toISOString());
      const reportType = body.report_type || prefsRow.report_type || "detailed";
      const token = prefsRow.unsubscribe_token;
      const baseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const unsubscribeUrl = token
        ? `${baseUrl}/functions/v1/report-unsubscribe?token=${token}`
        : "https://pocketapps.pt";

      const userName = t.email.split("@")[0];
      const subject = `O teu relatório de ${monthLabel(monthStart)} 📊`;

      let donutUrl: string | null = null;
      const donutPng = reportType === "detailed"
        ? await fetchDonutPng(data)
        : null;
      if (donutPng) {
        donutUrl = await uploadDonutPng(donutPng, t.user_id, monthStart);
      }

      const html = reportType === "simple"
        ? buildSimpleReportHtml(userName, data, monthStart, unsubscribeUrl)
        : buildDetailedReportHtml(userName, data, monthStart, donutUrl, unsubscribeUrl);

      const attachments: any[] = [];
      try {
        const pdfBytes = await buildReportPdf({
          userName,
          data,
          monthStart,
          reportType,
          donut: donutPng ? { content: donutPng } : null,
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
