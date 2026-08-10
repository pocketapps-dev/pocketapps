import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const APP = { name: "PocketExpenses", color: "#6366F1" };

async function sendSmtpEmail(to: string, subject: string, html: string): Promise<boolean> {
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
    await transporter.sendMail({ from, to, replyTo, subject, html });
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
  const byCategory = new Map<string, number>();
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
    byCategory.set(catName, (byCategory.get(catName) || 0) + amt);
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

  const sortedCat = [...byCategory.entries()].sort((a, b) => b[1] - a[1]);
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

function buildDetailedReportHtml(userName: string, data: any, monthStart: Date, includeCategories: boolean, includeCharts: boolean, unsubscribeUrl: string): string {
  const label = monthLabel(monthStart);
  const max = data.byCategory.length ? data.byCategory[0][1] : 1;

  const categoriesHtml = includeCategories
    ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;">
       ${data.byCategory
         .map(([name, amt]: [string, number]) => {
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
    ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:24px 0 0 0;">
        <tr>
          <td style="width:50%; text-align:center;">
            <div style="font-size:24px; font-weight:700; color:${APP.color};">${money(data.total)}</div>
            <div style="color:#6b7280; font-size:12px; margin-top:4px;">Total do mês</div>
          </td>
          <td style="width:50%; text-align:center;">
            <div style="font-size:24px; font-weight:700; color:#10B981;">${data.byCategory.length}</div>
            <div style="color:#6b7280; font-size:12px; margin-top:4px;">Categorias usadas</div>
          </td>
        </tr>
      </table>`
    : "";

  const bodyHtml = `${chartsHtml}${statsRowsHtml(data)}<h3 style="color:#111827; font-size:16px; margin:24px 0 8px 0;">Por categoria</h3>${categoriesHtml}<h3 style="color:#111827; font-size:16px; margin:24px 0 8px 0;">Despesas do mês</h3>${buildExpensesTableHtml(data.items)}`;
  return buildShellHtml(
    `Relatório de ${label}`,
    `Olá ${userName}, aqui está o resumo das tuas despesas.`,
    bodyHtml,
    unsubscribeUrl,
  );
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
      const ok = await sendSmtpEmail(t.email, subject, html);
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
