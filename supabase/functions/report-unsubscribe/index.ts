import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const HTML = (title: string, message: string, ok: boolean) => `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background-color:#f3f4f6;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6;padding:40px 20px;">
    <tr><td align="center">
      <table width="520" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <tr><td style="background-color:${ok ? "#6366F1" : "#ef4444"};padding:32px 30px;text-align:center;">
          <h1 style="color:#ffffff;margin:0;font-size:22px;">${title}</h1>
        </td></tr>
        <tr><td style="padding:32px 30px;">
          <p style="color:#374151;font-size:15px;line-height:1.6;margin:0;">${message}</p>
        </td></tr>
        <tr><td style="padding:20px 30px;border-top:1px solid #e5e7eb;">
          <p style="color:#9ca3af;font-size:12px;margin:0;text-align:center;">
            PocketApps ·
            <a href="https://pocketapps.pt/privacy" style="color:#9ca3af;">Política de Privacidade</a> ·
            <a href="https://pocketapps.pt/terms" style="color:#9ca3af;">Termos de Serviço</a>
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");

  if (!token) {
    return new Response(
      HTML("Link invalido", "O link de cancelamento de relatorios e invalido. Tenta novamente ou contacta-nos em geral@pocketapps.pt.", false),
      { status: 400, headers: { "Content-Type": "text/html; charset=utf-8" } },
    );
  }

  try {
    const { data: prefs, error } = await supabase
      .from("report_preferences")
      .select("id, user_id, app_name, email_reports_enabled")
      .eq("unsubscribe_token", token)
      .maybeSingle();

    if (error) {
      console.error("report-unsubscribe error:", error);
      return new Response(
        HTML("Erro", "Ocorreu um erro ao processar o pedido. Tenta novamente mais tarde.", false),
        { status: 500, headers: { "Content-Type": "text/html; charset=utf-8" } },
      );
    }

    if (!prefs) {
      return new Response(
        HTML("Link invalido", "O link de cancelamento de relatorios e invalido ou ja foi utilizado. Contacta-nos em geral@pocketapps.pt se precisares de ajuda.", false),
        { status: 404, headers: { "Content-Type": "text/html; charset=utf-8" } },
      );
    }

    if (prefs.email_reports_enabled) {
      await supabase
        .from("report_preferences")
        .update({ email_reports_enabled: false })
        .eq("id", prefs.id);
    }

    return new Response(
      HTML(
        "Subscricao cancelada",
        "Os teus relatorios mensais por email foram desativados. Nao voltaras a receber estes relatorios.<br><br>Se mudares de ideias, podes reativar os relatorios nas preferencias da app PocketExpenses.",
        true,
      ),
      { headers: { "Content-Type": "text/html; charset=utf-8" } },
    );
  } catch (e) {
    console.error("report-unsubscribe error:", e);
    return new Response(
      HTML("Erro", "Ocorreu um erro ao processar o pedido. Tenta novamente mais tarde.", false),
      { status: 500, headers: { "Content-Type": "text/html; charset=utf-8" } },
    );
  }
});
