import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const APP = { name: "PocketExpenses", color: "#6366F1" };

async function sendSmtpEmail(to: string, subject: string, html: string): Promise<boolean> {
  const host = Deno.env.get("SMTP_HOST") || "smtp.zoho.eu";
  const port = parseInt(Deno.env.get("SMTP_PORT") || "587");
  const user = Deno.env.get("SMTP_USER") || "";
  const pass = Deno.env.get("SMTP_PASS") || "";
  const from = Deno.env.get("SMTP_FROM") || user;

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
    await transporter.sendMail({ from, to, subject, html });
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

function monthLabel(d: Date): string {
  return new Intl.DateTimeFormat("pt-PT", { month: "long", year: "numeric" }).format(d);
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
      .select("id, name, amount, type, category_id, start_date, end_date, installments, frequency, is_active")
      .eq("user_id", userId)
      .in("category_id", catIds)
      .eq("is_active", true);
    expenses = data || [];
  }

  let total = 0;
  let recurring = 0;
  let unique = 0;
  const byCategory = new Map<string, number>();

  const start = new Date(monthStart);
  const end = new Date(monthEnd);
  const now = new Date();

  const occursInMonth = (e: any): boolean => {
    if (e.type === "unique") {
      const s = e.start_date ? new Date(e.start_date + "T00:00:00") : null;
      return !!s && s >= start && s < end;
    }
    if (!e.start_date) return false;
    const s = new Date(e.start_date + "T00:00:00");
    if (s > now) return false;
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
    if (!occursInMonth(e)) continue;
    const amt = Number(e.amount) || 0;
    total += amt;
    if (e.type === "recurring") recurring += amt;
    else unique += amt;
    const cat = catById.get(e.category_id);
    const catName = cat?.name || "Sem Categoria";
    byCategory.set(catName, (byCategory.get(catName) || 0) + amt);
  }

  const sortedCat = [...byCategory.entries()].sort((a, b) => b[1] - a[1]);
  return { total, recurring, unique, byCategory: sortedCat };
}

function buildReportHtml(userName: string, data: any, monthStart: Date, includeCategories: boolean, includeCharts: boolean, unsubscribeUrl: string): string {
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
    ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:24px 0;">
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
          <h2 style="color:#111827; margin:0 0 8px 0; font-size:20px;">Relatório de ${label}</h2>
          <p style="color:#6b7280; margin:0 0 24px 0; font-size:15px;">Olá ${userName}, aqui está o resumo das tuas despesas.</p>
          ${chartsHtml}
          <h3 style="color:#111827; font-size:16px; margin:24px 0 8px 0;">Por categoria</h3>
          ${categoriesHtml}
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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    await req.json().catch(() => ({}));
    const authHeader = req.headers.get("Authorization");

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      authHeader ? Deno.env.get("SUPABASE_ANON_KEY") ?? "" : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      authHeader ? { global: { headers: { Authorization: authHeader } } } : {},
    );

    let targets: { user_id: string; email: string }[] = [];

    if (authHeader) {
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError || !user) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (!user.email) {
        return new Response(JSON.stringify({ error: "User has no email" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      targets = [{ user_id: user.id, email: user.email }];
    } else {
      const now = new Date();
      const day = now.getDate();
      const hour = now.getHours();
      const { data: prefs } = await supabase
        .from("report_preferences")
        .select("user_id, report_day, report_hour, include_categories, include_charts, app_name, unsubscribe_token")
        .eq("email_reports_enabled", true)
        .eq("report_day", day)
        .eq("report_hour", hour);

      const { data: authUsers } = await supabase.auth.admin.listUsers();
      const emailById = new Map((authUsers?.users || []).map((u: any) => [u.id, u.email || ""]));

      for (const p of prefs || []) {
        if (!emailById.get(p.user_id)) continue;
        targets.push({ user_id: p.user_id, email: emailById.get(p.user_id) });
      }
    }

    const results: string[] = [];

    for (const t of targets) {
      const isTest = !!authHeader;
      const now = new Date();
      const monthStart = isTest
        ? new Date(now.getFullYear(), now.getMonth(), 1)
        : new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const monthEnd = new Date(now.getFullYear(), now.getMonth(), 1);

      let prefsRow: any = {};
      const { data: prefsData } = await supabase
        .from("report_preferences")
        .select("include_categories, include_charts, app_name, unsubscribe_token")
        .eq("user_id", t.user_id)
        .maybeSingle();
      prefsRow = prefsData || {};

      const appName = prefsRow.app_name || "expenses";
      const data = await fetchReportData(supabase, t.user_id, appName, monthStart.toISOString(), monthEnd.toISOString());
      const includeCategories = prefsRow.include_categories !== false;
      const includeCharts = prefsRow.include_charts !== false;
      const token = prefsRow.unsubscribe_token;
      const baseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const unsubscribeUrl = token
        ? `${baseUrl}/functions/v1/report-unsubscribe?token=${token}`
        : "https://pocketapps.pt";

      const userName = t.email.split("@")[0];
      const subject = `O teu relatório de ${monthLabel(monthStart)} 📊`;
      const html = buildReportHtml(userName, data, monthStart, includeCategories, includeCharts, unsubscribeUrl);
      const ok = await sendSmtpEmail(t.email, subject, html);
      results.push(`${t.user_id}:${ok ? "sent" : "failed"}`);
    }

    return new Response(JSON.stringify({ success: true, results }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    console.error("send-monthly-report error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
