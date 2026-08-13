import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { initWasm, Resvg } from "npm:@resvg/resvg-wasm@2.6.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const WASM_URL = "https://cdn.jsdelivr.net/npm/@resvg/resvg-wasm@2.6.2/index_bg.wasm";
const FONT_URL =
  "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/nanumgothic/NanumGothic-Regular.ttf";

let wasmReady: Promise<void> | null = null;
let fontBytes: Uint8Array | null = null;

function ensureWasm(): Promise<void> {
  if (!wasmReady) {
    wasmReady = (async () => {
      const wasm = await fetch(WASM_URL);
      if (!wasm.ok) throw new Error(`Falha ao obter wasm: ${wasm.status}`);
      await initWasm(await wasm.arrayBuffer());

      const fontRes = await fetch(FONT_URL);
      if (!fontRes.ok) throw new Error(`Falha ao obter fonte: ${fontRes.status}`);
      fontBytes = new Uint8Array(await fontRes.arrayBuffer());
    })();
  }
  return wasmReady;
}

interface SvgToPngPayload {
  svg: string;
  width?: number;
  height?: number;
}

function svgToPngBytes(svg: string, width?: number, height?: number): Uint8Array {
  const options: Record<string, unknown> = {
    fitTo: { mode: "zoom", value: 2 },
    font: {
      loadSystemFonts: false,
      defaultFontFamily: "NanumGothic",
      fontBuffers: fontBytes ? [fontBytes] : [],
    },
  };

  if (width && height) {
    options.fitTo = { mode: "width", value: width };
  }

  const resvg = new Resvg(svg, options);
  const png = resvg.render().asPng();
  resvg.free();

  if (!png || png.length === 0) {
    throw new Error("Resvg nao produziu imagem");
  }

  return png;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: SvgToPngPayload = await req.json();
    const { svg, width, height } = payload;

    if (!svg) {
      return new Response(
        JSON.stringify({ error: "Missing svg" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (svg.length > 200_000) {
      return new Response(
        JSON.stringify({ error: "SVG demasiado grande (max 200KB)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await ensureWasm();

    const png = svgToPngBytes(svg, width, height);

    return new Response(png, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "image/png",
        "Content-Length": String(png.byteLength),
        "Cache-Control": "public, max-age=3600",
      },
    });
  } catch (err) {
    console.error("svg-to-png error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
