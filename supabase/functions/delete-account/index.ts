import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function getGoodbyeHtml(fullName: string): string {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background-color:#f8fafc;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8fafc;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 6px rgba(0,0,0,0.05);">
          <tr>
            <td style="background:linear-gradient(135deg,#ef4444,#f97316);padding:40px 30px;text-align:center;">
              <h1 style="color:#ffffff;font-size:28px;margin:0;font-weight:700;">Conta Eliminada</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 30px;">
              <p style="color:#334155;font-size:16px;line-height:1.6;margin:0 0 20px 0;">
                Olá <strong>${fullName || "utilizador"}</strong>,
              </p>
              <p style="color:#334155;font-size:16px;line-height:1.6;margin:0 0 20px 0;">
                Conta eliminada com sucesso. Todos os dados foram removidos permanentemente.
              </p>
              <p style="color:#334155;font-size:16px;line-height:1.6;margin:0 0 20px 0;">
                Obrigado por usares o PocketApps — volta quando quiseres.
              </p>
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:10px 0 30px 0;">
                    <a href="https://pocketapps.pt" style="display:inline-block;background:linear-gradient(135deg,#6366f1,#8b5cf6);color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:8px;font-size:16px;font-weight:600;">
                      Criar Nova Conta
                    </a>
                  </td>
                </tr>
              </table>
              <p style="color:#64748b;font-size:14px;line-height:1.6;margin:0;">
                Se tiveres alguma questão sobre a eliminação da tua conta, contacta-nos em
                <a href="mailto:geral@pocketapps.pt" style="color:#6366f1;">geral@pocketapps.pt</a>.
              </p>
            </td>
          </tr>
          <tr>
            <td style="background-color:#f1f5f9;padding:20px 30px;text-align:center;">
              <p style="color:#94a3b8;font-size:12px;margin:0;">
                © ${new Date().getFullYear()} PocketApps ·
                <a href="https://pocketapps.pt/privacy" style="color:#94a3b8;">Política de Privacidade</a> ·
                <a href="https://pocketapps.pt/terms" style="color:#94a3b8;">Termos de Serviço</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

async function sendSmtpEmail(
  to: string,
  subject: string,
  html: string,
): Promise<boolean> {
  const host = Deno.env.get("SMTP_HOST") || "smtp-relay.brevo.com";
  const port = parseInt(Deno.env.get("SMTP_PORT") || "587");
  const user = Deno.env.get("SMTP_USER") || "";
  const pass = Deno.env.get("SMTP_PASS") || "";
  const from = Deno.env.get("SMTP_FROM") || "no-reply@pocketapps.pt";

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
  console.log("delete-account invoked, method:", req.method);

  if (req.method === "OPTIONS") {
    console.log("delete-account: responding to OPTIONS");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("delete-account: missing Authorization header");
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const userId = user.id;
    const userEmail = user.email || "";
    const fullName = user.user_metadata?.full_name || user.user_metadata?.name || "";

    // 1. Send goodbye email via SMTP (best effort)
    let emailSent = false;
    if (userEmail) {
      console.log(`[EMAIL] A enviar email de goodbye para ${userEmail}`);
      emailSent = await sendSmtpEmail(
        userEmail,
        "Conta PocketApps eliminada",
        getGoodbyeHtml(fullName),
      );
    } else {
      console.warn("[EMAIL] Sem email para enviar goodbye");
    }

    // 2. Delete user data per table
    console.log("[DELETE] A eliminar dados do utilizador...");
    await supabase.from("monthly_status").delete().eq("user_id", userId);
    await supabase.from("monthly_summaries").delete().eq("user_id", userId);
    await supabase.from("expenses").delete().eq("user_id", userId);
    await supabase.from("subscriptions").delete().eq("user_id", userId);
    await supabase.from("user_settings").delete().eq("user_id", userId);
    await supabase.from("report_preferences").delete().eq("user_id", userId);
    await supabase.from("user_app_access").delete().eq("user_id", userId);
    await supabase.from("profiles").delete().eq("id", userId);
    console.log("[DELETE] Dados eliminados");

    // 3. Delete auth user
    console.log("[DELETE] A eliminar utilizador de auth...");
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error("[DELETE] Erro ao eliminar utilizador:", deleteError);
      return new Response(
        JSON.stringify({
          error: "Failed to delete account",
          email_sent: emailSent,
          delete_error: deleteError.message,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    console.log("[DELETE] Conta eliminada com sucesso");
    return new Response(
      JSON.stringify({
        success: true,
        message: "Account deleted successfully",
        email_sent: emailSent,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error(error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
