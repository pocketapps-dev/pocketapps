import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const BACKUPS_BUCKET = "backups";
const RETENTION_DAYS = 30;

function utcDateStamp(d = new Date()): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`;
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

async function cleanupOldBackups(admin: any, userId: string): Promise<number> {
  const cutoff = Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
  const { data: files } = await admin.storage.from(BACKUPS_BUCKET).list(userId, { limit: 1000 });
  const stale = (files || []).filter((f: any) => {
    const m = /^(\d{4}-\d{2}-\d{2})\.json$/.exec(f.name || "");
    if (!m) return false;
    return new Date(`${m[1]}T00:00:00Z`).getTime() < cutoff;
  });
  if (stale.length === 0) return 0;
  const paths = stale.map((f: any) => `${userId}/${f.name}`);
  const { error } = await admin.storage.from(BACKUPS_BUCKET).remove(paths);
  if (error) throw error;
  return paths.length;
}

async function backupUser(admin: any, userId: string): Promise<string> {
  const [catsRes, expRes, msRes] = await Promise.all([
    admin.from("categories").select("*").eq("user_id", userId),
    admin.from("expenses").select("*").eq("user_id", userId),
    admin.from("monthly_status").select("*").eq("user_id", userId),
  ]);
  if (catsRes.error) throw catsRes.error;
  if (expRes.error) throw expRes.error;
  if (msRes.error && msRes.error.code !== "PGRST205") throw msRes.error;

  const payload = {
    version: 1,
    app: "pocketexpenses",
    generated_at: new Date().toISOString(),
    counts: {
      categories: catsRes.data?.length || 0,
      expenses: expRes.data?.length || 0,
      monthly_status: msRes.data?.length || 0,
    },
    data: {
      categories: catsRes.data || [],
      expenses: expRes.data || [],
      monthly_status: msRes.data || [],
    },
  };

  const path = `${userId}/${utcDateStamp()}.json`;
  const { error } = await admin.storage
    .from(BACKUPS_BUCKET)
    .upload(path, JSON.stringify(payload), {
      contentType: "application/json",
      upsert: true,
    });
  if (error) throw error;

  const removed = await cleanupOldBackups(admin, userId);
  console.log(`[BACKUP] ${path} ok (removidos ${removed} antigos)`);
  return path;
}

async function hasActivePremium(admin: any, userId: string): Promise<boolean> {
  const now = new Date().toISOString();
  const { data } = await admin
    .from("subscriptions")
    .select("id")
    .eq("user_id", userId)
    .eq("status", "active")
    .neq("plan", "free")
    .or(`ends_at.is.null,ends_at.gt.${now}`)
    .limit(1);
  return (data || []).length > 0;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    const jwt = authHeader ? authHeader.replace(/^Bearer\s+/i, "").trim() : "";
    const apikey = req.headers.get("apikey") || "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const bearerIsServiceRole = !!jwt && (jwt === serviceRole || isLegacyServiceRoleJwt(jwt));
    const isServiceRole = bearerIsServiceRole || (!jwt && apikey === serviceRole);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRole,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    if (isServiceRole) {
      const now = new Date().toISOString();
      const { data: subs } = await admin
        .from("subscriptions")
        .select("user_id")
        .eq("status", "active")
        .neq("plan", "free")
        .or(`ends_at.is.null,ends_at.gt.${now}`);
      const users = [...new Set((subs || []).map((s: any) => s.user_id))];
      console.log(`[BACKUP] Cron: ${users.length} utilizadores premium`);

      const done: string[] = [];
      const errors: string[] = [];
      for (const userId of users) {
        try {
          done.push(await backupUser(admin, userId));
        } catch (e) {
          console.error(`[BACKUP] Falhou ${userId}:`, e);
          errors.push(`${userId}: ${(e as Error)?.message || String(e)}`);
        }
      }
      return new Response(
        JSON.stringify({ success: true, backed_up: done.length, errors }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

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
      if (error || !data?.user) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const premium = await hasActivePremium(admin, data.user.id);
      if (!premium) {
        return new Response(JSON.stringify({ error: "Premium necessário" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const path = await backupUser(admin, data.user.id);
      return new Response(JSON.stringify({ success: true, snapshot: path }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("create-daily-backups error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
