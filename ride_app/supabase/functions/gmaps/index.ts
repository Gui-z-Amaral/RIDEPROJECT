// Edge Function: gmaps
// Proxy para os web services do Google Maps (Places, Geocoding, Directions).
//
// Por quê: o navegador bloqueia chamadas diretas ao Google por CORS; e em
// qualquer plataforma isto mantém a chave da API só no servidor. O cliente
// chama <SUPABASE_URL>/functions/v1/gmaps?path=<api>&<params...> e esta função
// injeta a chave (secret GOOGLE_MAPS_API_KEY) e repassa a resposta.
//
// Deploy (self-hosted): colocar esta pasta em
//   /root/supabase/docker/volumes/functions/gmaps/
// definir o secret GOOGLE_MAPS_API_KEY (ver instruções) e reiniciar o
// container `functions`.

const GOOGLE = "https://maps.googleapis.com/maps/api";
const KEY = Deno.env.get("GOOGLE_MAPS_API_KEY") ?? "";

// Só permitimos estes prefixos de path — evita que a função vire um proxy
// aberto pra qualquer API na sua chave/faturamento.
const ALLOWED_PREFIXES = ["place/", "geocode/", "directions/"];

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  if (!KEY) return json({ error: "GOOGLE_MAPS_API_KEY não configurada" }, 500);

  const reqUrl = new URL(req.url);
  const path = reqUrl.searchParams.get("path");
  if (!path) return json({ error: "parâmetro 'path' ausente" }, 400);

  if (!ALLOWED_PREFIXES.some((p) => path.startsWith(p))) {
    return json({ error: `path não permitido: ${path}` }, 403);
  }

  // Repassa todos os params, exceto os de controle (path) e os do gateway
  // (apikey/Authorization chegam como header, mas apikey também pode vir na
  // query no caso das fotos via <img>).
  const params = new URLSearchParams();
  for (const [k, v] of reqUrl.searchParams) {
    if (k === "path" || k === "apikey") continue;
    params.append(k, v);
  }
  params.set("key", KEY);

  const target = `${GOOGLE}/${path}?${params.toString()}`;

  try {
    const upstream = await fetch(target, { redirect: "follow" });
    const contentType =
      upstream.headers.get("content-type") ?? "application/octet-stream";
    // Repassa o corpo como veio (JSON dos web services ou bytes da foto).
    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        ...CORS,
        "content-type": contentType,
        "cache-control": "public, max-age=86400",
      },
    });
  } catch (e) {
    return json({ error: "falha ao consultar o Google Maps", detail: `${e}` }, 502);
  }
});
