// Edge Function: share
// Devolve as tags Open Graph de um evento, viagem ou rolê, para a prévia do
// link no WhatsApp, Telegram, Instagram, Discord...
//
// Por que existe: os robôs que montam a prévia do link **não executam
// JavaScript**. Eles leem o HTML cru. Como o RideApp é um app Flutter que só
// existe depois do JS rodar, nenhuma solução no Dart faria a foto do evento
// aparecer na prévia — tem que ser o servidor devolvendo HTML já pronto.
//
// Quem chama: só o Nginx, e **só quando o User-Agent é de robô**. Pessoas
// recebem o `index.html` normal, sem passar por aqui. Duas consequências boas:
// a abertura do app não fica dependendo desta função, e se ela cair o que se
// perde é a miniatura do link, não o app.
//
// ── SEGURANÇA ───────────────────────────────────────────────────────────────
// É pública de propósito: robô de rede social não tem como se autenticar.
// O que limita o estrago:
//  - só três tipos (`e`, `v`, `r`), nada mais é aceito;
//  - só colunas que já são legíveis sem login (`events_select`/`rides_select`
//    são `USING (true)`; trips libera viagem sem clube) — usa a chave ANÔNIMA,
//    nunca a service_role, então o banco continua sendo a última palavra;
//  - viagem e rolê devolvem só título, data e cidade. Ponto de partida,
//    endereço, paradas e rota NÃO saem daqui: num app de moto, dizer onde
//    alguém vai estar e a que horas é risco de verdade;
//  - todo valor é escapado antes de entrar no HTML (senão um título com aspas
//    fecharia a tag e injetaria markup).

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://kong:8000";
const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const APP = "https://app.ride.dev.br";
const FALLBACK_IMAGE = `${APP}/og-image.png?v=1`;

type Kind = "e" | "v" | "r";

const KIND_LABEL: Record<Kind, string> = {
  e: "Evento",
  v: "Viagem",
  r: "Rolê",
};

/// Escapa para uso dentro de um atributo HTML.
function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/// "Cidade - UF" de um endereço do Google, ou null. Mesma regra do app
/// (SharePreview.cityFromAddress): mostra a região sem entregar o ponto exato.
function cityFromAddress(address: string | null): string | null {
  if (!address) return null;
  for (const part of address.split(",")) {
    const m = part.trim().match(/^(.+?)\s*-\s*([A-Z]{2})$/);
    if (m && m[1].trim()) return `${m[1].trim()} - ${m[2]}`;
  }
  return null;
}

function formatDate(iso: string | null): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  // Horário de Brasília para a prévia: o robô não tem fuso do leitor.
  return d.toLocaleString("pt-BR", {
    timeZone: "America/Sao_Paulo",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

async function fetchRow(
  table: string,
  columns: string,
  id: string,
): Promise<Record<string, unknown> | null> {
  const url = `${SUPABASE_URL}/rest/v1/${table}` +
    `?select=${encodeURIComponent(columns)}&id=eq.${encodeURIComponent(id)}&limit=1`;
  const res = await fetch(url, {
    headers: { apikey: ANON, Authorization: `Bearer ${ANON}` },
  });
  if (!res.ok) return null;
  const rows = await res.json();
  return Array.isArray(rows) && rows.length ? rows[0] : null;
}

type Meta = { title: string; description: string; image: string };

async function metaFor(kind: Kind, id: string): Promise<Meta | null> {
  if (kind === "e") {
    const r = await fetchRow(
      "events",
      "title,description,banner_url,starts_at,city,state_uf",
      id,
    );
    if (!r) return null;
    const place = [r.city, r.state_uf].filter(Boolean).join(" - ");
    const when = formatDate(r.starts_at as string | null);
    return {
      title: `${r.title ?? "Evento"} · RideApp`,
      // Evento é público por natureza: mostra a descrição inteira.
      description: (r.description as string | null)?.trim() ||
        [place, when].filter(Boolean).join(" · ") ||
        "Evento no RideApp",
      image: (r.banner_url as string | null) || FALLBACK_IMAGE,
    };
  }

  if (kind === "v") {
    const r = await fetchRow(
      "trips",
      "title,cover_image,scheduled_at,destination_address",
      id,
    );
    if (!r) return null;
    const city = cityFromAddress(r.destination_address as string | null);
    const when = formatDate(r.scheduled_at as string | null);
    return {
      title: `${r.title ?? "Viagem"} · RideApp`,
      description: ["Viagem de moto", city, when].filter(Boolean).join(" · "),
      image: (r.cover_image as string | null) || FALLBACK_IMAGE,
    };
  }

  const r = await fetchRow("rides", "title,scheduled_at,meeting_address", id);
  if (!r) return null;
  const city = cityFromAddress(r.meeting_address as string | null);
  const when = formatDate(r.scheduled_at as string | null);
  return {
    title: `${r.title ?? "Rolê"} · RideApp`,
    description: ["Rolê de moto", city, when].filter(Boolean).join(" · "),
    image: FALLBACK_IMAGE,
  };
}

function page(meta: Meta, url: string): string {
  const t = esc(meta.title);
  const d = esc(meta.description);
  const img = esc(meta.image);
  const u = esc(url);
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>${t}</title>
<meta name="description" content="${d}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="RideApp">
<meta property="og:locale" content="pt_BR">
<meta property="og:title" content="${t}">
<meta property="og:description" content="${d}">
<meta property="og:url" content="${u}">
<meta property="og:image" content="${img}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${t}">
<meta name="twitter:description" content="${d}">
<meta name="twitter:image" content="${img}">
<link rel="canonical" href="${u}">
</head>
<body>
<h1>${t}</h1>
<p>${d}</p>
<p><a href="${u}">Abrir no RideApp</a></p>
</body>
</html>`;
}

Deno.serve(async (req) => {
  const u = new URL(req.url);
  const kind = u.searchParams.get("kind") as Kind | null;
  const id = u.searchParams.get("id") ?? "";

  const headers = { "content-type": "text/html; charset=utf-8" };

  if (!kind || !["e", "v", "r"].includes(kind) || !id) {
    return new Response("not found", { status: 404, headers });
  }

  const canonical = `${APP}/${kind}/${id}`;

  try {
    const meta = await metaFor(kind, id);
    if (!meta) {
      // Link morto: devolve algo apresentável, sem inventar dados.
      return new Response(
        page({
          title: "RideApp",
          description: `${KIND_LABEL[kind]} não encontrado.`,
          image: FALLBACK_IMAGE,
        }, canonical),
        { status: 404, headers },
      );
    }
    return new Response(page(meta, canonical), {
      status: 200,
      headers: {
        ...headers,
        // Prévia de link é reconsultada muito; 5 min alivia o banco sem
        // segurar dado velho por tempo relevante.
        "cache-control": "public, max-age=300",
      },
    });
  } catch {
    return new Response(
      page({
        title: "RideApp",
        description: "Rolês e viagens de moto.",
        image: FALLBACK_IMAGE,
      }, canonical),
      { status: 200, headers },
    );
  }
});
