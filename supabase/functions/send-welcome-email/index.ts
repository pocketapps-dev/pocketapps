import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface WelcomeEmailPayload {
  user_id: string;
  email?: string;
  app_name: string;
}

const APP_CONFIG: Record<
  string,
  { name: string; color: string; features: string[]; description: string }
> = {
  expenses: {
    name: "PocketExpenses",
    color: "#6366F1",
    features: ["Gestão de despesas", "Calendário de vencimentos", "Relatórios mensais", "Categorias personalizáveis"],
    description: "Gere as tuas finanças de forma simples e organizada.",
  },
  fuel: {
    name: "PocketFuel",
    color: "#10B981",
    features: ["Registo de abastecimentos", "Consumo médio", "Histórico de despesas", "Gráficos de evolução"],
    description: "Controla os teus abastecimentos e despesas com combustível.",
  },
  shopping: {
    name: "PocketShopping",
    color: "#F59E0B",
    features: ["Listas de compras", "Comparação de preços", "Ofertas e promoções", "Histórico de compras"],
    description: "Organiza as tuas compras e poupa dinheiro.",
  },
};

function buildWelcomeHtml(userName: string, app: (typeof APP_CONFIG)["expenses"]): string {
  const featuresHtml = app.features
    .map((f) => `<li style="padding: 8px 0; color: #374151;">${f}</li>`)
    .join("");

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0; padding:0; background-color:#f3f4f6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6; padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
        <tr>
          <td style="background-color:${app.color}; padding:40px 30px; text-align:center;">
            <h1 style="color:#ffffff; margin:0; font-size:28px; font-weight:700;">${app.name}</h1>
          </td>
        </tr>
        <tr>
          <td style="padding:40px 30px;">
            <h2 style="color:#111827; margin:0 0 8px 0; font-size:22px;">Bem-vindo, ${userName}! 👋</h2>
            <p style="color:#6b7280; margin:0 0 24px 0; font-size:16px; line-height:1.6;">
              ${app.description}
            </p>
            <p style="color:#374151; font-size:16px; font-weight:600; margin:0 0 12px 0;">O que podes fazer:</p>
            <ul style="padding-left:20px; margin:0 0 24px 0;">${featuresHtml}</ul>
            <table cellpadding="0" cellspacing="0" style="margin:0 auto;">
              <tr>
                <td style="background-color:${app.color}; border-radius:8px; padding:14px 32px;">
                  <a href="https://pocketapps.pt" style="color:#ffffff; text-decoration:none; font-size:16px; font-weight:600;">Abrir ${app.name}</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td style="padding:24px 30px; border-top:1px solid #e5e7eb;">
            <p style="color:#9ca3af; font-size:13px; margin:0; text-align:center;">
              PocketApps · Este email foi enviado para ${userName}.<br>
              Se não solicitaste esta conta, podes ignorar este email.
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

async function sendSmtpEmail(
  to: string,
  subject: string,
  html: string,
): Promise<boolean> {
  const host = Deno.env.get("SMTP_HOST") || "smtp.zoho.eu";
  const port = parseInt(Deno.env.get("SMTP_PORT") || "587");
  const user = Deno.env.get("SMTP_USER") || "";
  const pass = Deno.env.get("SMTP_PASS") || "";
  const from = Deno.env.get("SMTP_FROM") || user;

  console.log(`[EMAIL] Enviar para ${to} via ${host}:${port} user="${user}" from="${from}"`);
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
    console.log(`[EMAIL] Enviado com sucesso para ${to}`);
    return true;
  } catch (error) {
    console.error("[EMAIL] Erro:", error);
    return false;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: WelcomeEmailPayload = await req.json();
    const { user_id, email: inlineEmail, app_name } = payload;

    if (!user_id || !app_name) {
      return new Response(
        JSON.stringify({ error: "Missing user_id or app_name" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const app = APP_CONFIG[app_name];
    if (!app) {
      return new Response(
        JSON.stringify({ error: `Unknown app: ${app_name}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const email = inlineEmail || "";
    if (!email) {
      return new Response(
        JSON.stringify({ error: "Missing email" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: access } = await supabase
      .from("user_app_access")
      .select("welcome_email_sent")
      .eq("user_id", user_id)
      .eq("app_name", app_name)
      .maybeSingle();

    if (access?.welcome_email_sent) {
      console.log(`[WELCOME] Ja enviado para ${user_id}, ignorando`);
      return new Response(
        JSON.stringify({ success: true, skipped: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userName = email.split("@")[0];

    const html = buildWelcomeHtml(userName, app);
    const subject = `Bem-vindo ao ${app.name}! 🎉`;

    const emailSent = await sendSmtpEmail(email, subject, html);

    if (emailSent) {
      await supabase
        .from("user_app_access")
        .update({ welcome_email_sent: true })
        .eq("user_id", user_id)
        .eq("app_name", app_name);
    }

    return new Response(
      JSON.stringify({ success: true, email, app_name, email_sent: emailSent }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("send-welcome-email error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
