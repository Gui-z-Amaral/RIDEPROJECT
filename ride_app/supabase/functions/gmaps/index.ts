// Edge Function: gmaps
// Proxy para os web services do Google Maps (Places, Geocoding, Directions).
//
// Por quê: o navegador bloqueia chamadas diretas ao Google por CORS; e em
// qualquer plataforma isto mantém a chave da API só no servidor. O cliente
// chama <SUPABASE_URL>/functions/v1/gmaps?path=<api>&<params...> e esta função
// injeta a chave (secret GOOGLE_MAPS_API_KEY) e repassa a resposta.
//
// ── AUTENTICAÇÃO ────────────────────────────────────────────────────────────
// A função valida o JWT por conta própria porque o VERIFY_JWT do Supabase
// self-hosted é GLOBAL (ver "# TODO: Allow configuring VERIFY_JWT per function"
// no docker-compose) — não dá para exigir token numa função e liberar noutra.
//
// Busca, geocoding e rotas exigem um usuário LOGADO. Sem isso o proxy seria
// uma API do Google Maps gratuita para qualquer um, faturada no nosso cartão.
//
// `place/photo` fica aberta por necessidade: a imagem é carregada por <img>
// (e pelo CanvasKit no Flutter web), que não envia cabeçalho de autenticação.
// O risco é contido porque a foto exige um `photo_reference` — um código opaco
// que só se obtém fazendo uma busca. Trancando a busca, acaba a matéria-prima
// para pedir fotos novas.
//
// Evolução futura: cachear as fotos no Supabase Storage. A foto viraria uma URL
// pública comum (sem proxy, sem CORS) e o Google seria cobrado uma vez por foto
// em vez de por visualização — mais seguro E mais barato. Fica para depois
// porque hoje o `photoUrl` é síncrono e é lido por ~7 telas.

const GOOGLE = "https://maps.googleapis.com/maps/api";
const KEY = Deno.env.get("GOOGLE_MAPS_API_KEY") ?? "";
const JWT_SECRET = Deno.env.get("JWT_SECRET") ?? "";

// Só permitimos estes prefixos — evita que a função vire proxy aberto para
// qualquer API na nossa chave/faturamento.
const ALLOWED_PREFIXES = ["place/", "geocode/", "directions/"];

// Caminhos que dispensam token (a tag <img> não manda cabeçalho).
const PUBLIC_PREFIXES = ["place/photo"];

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

function b64urlToBytes(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/")
    .padEnd(s.length + ((4 - (s.length % 4)) % 4), "=");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

/// Verifica um JWT HS256 do Supabase e devolve o payload, ou null se o token
/// for inválido, expirado ou assinado com outro segredo.
async function verifyJwt(token: string): Promise<Record<string, unknown> | null> {
  try {
    const [h, p, s] = token.split(".");
    if (!h || !p || !s) return null;

    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(JWT_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"],
    );
    const ok = await crypto.subtle.verify(
      "HMAC",
      key,
      b64urlToBytes(s),
      new TextEncoder().encode(`${h}.${p}`),
    );
    if (!ok) return null;

    const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(p)));
    // Token vencido não vale.
    if (typeof payload.exp === "number" && Date.now() / 1000 > payload.exp) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
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

  // ── Autorização ──────────────────────────────────────────────────────────
  if (!PUBLIC_PREFIXES.some((p) => path.startsWith(p))) {
    if (!JWT_SECRET) return json({ error: "JWT_SECRET não configurada" }, 500);

    const auth = req.headers.get("authorization") ?? "";
    const token = auth.toLowerCase().startsWith("bearer ")
      ? auth.slice(7).trim()
      : "";
    const payload = token ? await verifyJwt(token) : null;

    // Exige usuário LOGADO: a chave anônima é pública (vai no app), então
    // aceitar role "anon" deixaria o proxy aberto na prática.
    if (!payload || payload.role !== "authenticated") {
      return json({ error: "não autorizado" }, 401);
    }
  }

  // Repassa todos os params, exceto os de controle.
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
