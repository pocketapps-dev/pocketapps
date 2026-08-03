import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "stripe";
import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2024-12-18.acacia",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

async function sendEmail(to, subject, html) {
  const host = Deno.env.get("SMTP_HOST") || "smtp-relay.brevo.com";
  const port = parseInt(Deno.env.get("SMTP_PORT") || "587");
  const user = Deno.env.get("SMTP_USER") || "";
  const pass = Deno.env.get("SMTP_PASS") || "";
  const from = Deno.env.get("SMTP_FROM") || "no-reply@pocketapps.pt";
  const replyTo = Deno.env.get("SMTP_REPLY_TO") || "suporte@pocketapps.pt";
  if (!user || !pass) { console.error("[EMAIL] Credenciais em falta"); return false; }
  const transporter = nodemailer.createTransport({ host, port, secure: port === 465, auth: { user, pass }, tls: { rejectUnauthorized: false } });
  try { await transporter.sendMail({ from, to, replyTo, subject, html }); console.log("[EMAIL] Enviado para " + to); return true; }
  catch (error) { console.error("[EMAIL] Erro:", error); return false; }
}

async function sendThemePurchaseEmail(email, themeName) {
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"></head><body style="margin:0;padding:0;background-color:#f3f4f6;font-family:sans-serif;"><table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6;padding:40px 20px;"><tr><td align="center"><table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);"><tr><td style="background-color:#6366F1;padding:40px 30px;text-align:center;"><h1 style="color:#ffffff;margin:0;font-size:28px;font-weight:700;">Tema Desbloqueado!</h1></td></tr><tr><td style="padding:40px 30px;"><h2 style="color:#111827;margin:0 0 8px 0;font-size:22px;">O tema ${themeName} esta disponivel!</h2><p style="color:#6b7280;margin:0 0 24px 0;font-size:16px;line-height:1.6;">A tua compra foi processada com sucesso. O tema <strong>${themeName}</strong> ja esta disponivel na tua app PocketExpenses.</p><p style="color:#374151;font-size:16px;margin:0 0 12px 0;">Para usar o novo tema:</p><ol style="padding-left:20px;color:#374151;font-size:16px;line-height:1.8;"><li>Abre a app PocketExpenses</li><li>Vai a Definicoes - Temas</li><li>Seleciona o tema ${themeName}</li></ol></td></tr><tr><td style="padding:24px 30px;border-top:1px solid #e5e7eb;"><p style="color:#9ca3af;font-size:13px;margin:0;text-align:center;">PocketApps - Obrigado pela tua compra!<br>Precisas de ajuda? Contacta-nos em suporte@pocketapps.pt</p></td></tr></table></td></tr></table></body></html>`;
  await sendEmail(email, "Tema " + themeName + " desbloqueado!", html);
}

async function sendSubscriptionEmail(email, plan) {
  const planLabel = plan === "founder" ? "Founder (Lifetime)" : "Premium";
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"></head><body style="margin:0;padding:0;background-color:#f3f4f6;font-family:sans-serif;"><table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6;padding:40px 20px;"><tr><td align="center"><table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);"><tr><td style="background-color:#6366F1;padding:40px 30px;text-align:center;"><h1 style="color:#ffffff;margin:0;font-size:28px;font-weight:700;">Plano ${planLabel} Ativado!</h1></td></tr><tr><td style="padding:40px 30px;"><h2 style="color:#111827;margin:0 0 8px 0;font-size:22px;">O teu plano esta pronto a usar!</h2><p style="color:#6b7280;margin:0 0 24px 0;font-size:16px;line-height:1.6;">A tua compra foi processada com sucesso. O plano <strong>${planLabel}</strong> ja esta ativo na tua conta.</p><p style="color:#374151;font-size:16px;margin:0;">Abre a app PocketExpenses para desfrutares de todas as funcionalidades premium!</p></td></tr><tr><td style="padding:24px 30px;border-top:1px solid #e5e7eb;"><p style="color:#9ca3af;font-size:13px;margin:0;text-align:center;">PocketApps - Obrigado pela tua compra!<br>Precisas de ajuda? Contacta-nos em suporte@pocketapps.pt</p></td></tr></table></td></tr></table></body></html>`;
  await sendEmail(email, "Plano " + planLabel + " ativado!", html);
}

async function processThemePurchase(userId, appName, themeKey, paymentRef, amountCents) {
  const { data, error } = await supabase.rpc("grant_theme_to_user", {
    p_user_id: userId, p_app_name: appName, p_theme_key: themeKey,
    p_source: "purchase", p_payment_provider: "stripe",
    p_payment_ref: paymentRef, p_amount_cents: amountCents,
  });
  if (error) { console.error("[WEBHOOK] Error granting theme:", error); return { success: false }; }
  return { success: data?.success ?? false, themeName: data?.theme_name };
}

async function processSubscriptionPurchase(userId, appName, plan, durationMonths, paymentRef) {
  const endsAt = new Date();
  endsAt.setMonth(endsAt.getMonth() + durationMonths);
  const { error } = await supabase.from("subscriptions").upsert({
    user_id: userId, app_name: appName, plan: plan, status: "active",
    started_at: new Date().toISOString(),
    ends_at: plan === "founder" ? null : endsAt.toISOString(),
    payment_provider: "stripe", metadata: { stripe_ref: paymentRef },
  });
  if (error) { console.error("[WEBHOOK] Error updating subscription:", error); return false; }
  return true;
}

serve(async (req) => {
  if (req.method === "OPTIONS") { return new Response("ok", { headers: corsHeaders }); }
  if (req.method !== "POST") { return new Response("Method not allowed", { status: 405 }); }
  try {
    const signature = req.headers.get("stripe-signature");
    if (!signature) { return new Response("Missing stripe-signature header", { status: 400 }); }
    const body = await req.text();
    let event;
    try {
      event = await stripe.webhooks.constructEventAsync(body, signature, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      console.error("[WEBHOOK] Signature verification failed:", err);
      return new Response("Webhook signature verification failed", { status: 400 });
    }
    console.log("[WEBHOOK] Event received: " + event.type);
    if (event.type === "checkout.session.completed") {
      const session = event.data.object;
      const userId = session.metadata?.user_id;
      const appName = session.metadata?.app_name || "expenses";
      const themeKey = session.metadata?.theme_key;
      const plan = session.metadata?.plan;
      const durationMonths = parseInt(session.metadata?.duration_months || "12");
      if (!userId) { console.error("[WEBHOOK] Missing user_id"); return new Response("Missing user_id", { status: 400 }); }
      const customerEmail = session.customer_details?.email || session.customer_email || "";
      if (themeKey) {
        console.log("[WEBHOOK] Theme: user=" + userId + ", theme=" + themeKey);
        const result = await processThemePurchase(userId, appName, themeKey, session.id, session.amount_total || 99);
        if (result.success && customerEmail) { await sendThemePurchaseEmail(customerEmail, result.themeName || themeKey); }
        return new Response(JSON.stringify({ received: true, type: "theme", theme: themeKey, success: result.success }), { status: 200, headers: { "Content-Type": "application/json" } });
      }
      if (plan) {
        console.log("[WEBHOOK] Subscription: user=" + userId + ", plan=" + plan);
        const success = await processSubscriptionPurchase(userId, appName, plan, durationMonths, session.id);
        if (success && customerEmail) { await sendSubscriptionEmail(customerEmail, plan); }
        return new Response(JSON.stringify({ received: true, type: "subscription", plan, success }), { status: 200, headers: { "Content-Type": "application/json" } });
      }
      console.log("[WEBHOOK] No theme_key or plan in metadata");
      return new Response(JSON.stringify({ received: true, message: "No action needed" }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    if (event.type === "payment_intent.payment_failed") {
      console.log("[WEBHOOK] Payment failed: " + event.data.object.id);
    }
    console.log("[WEBHOOK] Unhandled event: " + event.type);
    return new Response(JSON.stringify({ received: true, unhandled: true }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (err) {
    console.error("[WEBHOOK] Error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
