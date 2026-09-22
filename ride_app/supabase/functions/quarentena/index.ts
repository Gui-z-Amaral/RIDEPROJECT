// Edge Function: quarentena
// Desativar, reativar e apagar em definitivo a conta — levando as FOTOS junto.
//
// Por que existe: bucket público do Storage ignora RLS na leitura. Anonimizar o
// perfil (migration 034) tirava a foto da tela, mas o arquivo continuava no
// mesmo endereço público, e quem tivesse o link seguia abrindo. A única forma
// de uma foto ficar inacessível SEM ser apagada é sair do bucket público.
//
// Ações (POST, corpo JSON { acao }):
//   guardar    usuário logado → desativa a conta e move as fotos dele para o
//              bucket privado `quarentena`
//   restaurar  usuário logado → reativa a conta e devolve as fotos
//   apagar     SÓ service_role (timer da VPS) → apaga as fotos da quarentena
//              das contas vencidas e depois as próprias contas
//
// ── SEGURANÇA ───────────────────────────────────────────────────────────────
//  - Valida o JWT por conta própria (o VERIFY_JWT do self-hosted é global),
//    no mesmo padrão da `gmaps`.
//  - `guardar`/`restaurar` agem só sobre o `sub` do token: não há parâmetro de
//    usuário, então ninguém mexe nos arquivos de outra pessoa.
//  - As funções de banco rodam com o token DO USUÁRIO (`auth.uid()` vale
//    dentro delas); só a movimentação de arquivo usa a service_role.
//  - Na volta, o upload usa o token do usuário: o arquivo volta com o dono
//    certo e a policy de caminho do bucket continua sendo checada.
//  - `apagar` recusa qualquer token que não seja service_role.
//  - Tudo é idempotente: repetir depois de uma falha no meio só termina o que
//    faltou.

const URL_BASE = Deno.env.get("SUPABASE_URL") ?? "http://kong:8000";
const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const JWT_SECRET = Deno.env.get("JWT_SECRET") ?? "";

const QUARENTENA = "quarentena";

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

/// Mesmo verificador da `gmaps`: HS256 com o segredo do projeto, e vencido
/// não vale.
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
    if (typeof payload.exp === "number" && Date.now() / 1000 > payload.exp) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

// ── Banco ───────────────────────────────────────────────────────────────────

async function rpc(
  fn: string,
  token: string,
  apikey: string,
  body: unknown = {},
): Promise<unknown> {
  const r = await fetch(`${URL_BASE}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      apikey,
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`rpc ${fn}: ${r.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

// ── Storage ─────────────────────────────────────────────────────────────────

/// Nomes vêm do próprio Storage (uuid, "_", dígitos, "/", "."), mas cada
/// segmento é codificado assim mesmo: o caminho entra numa URL.
const enc = (path: string) => path.split("/").map(encodeURIComponent).join("/");

async function baixar(bucket: string, name: string) {
  const r = await fetch(
    `${URL_BASE}/storage/v1/object/authenticated/${bucket}/${enc(name)}`,
    { headers: { apikey: SERVICE, authorization: `Bearer ${SERVICE}` } },
  );
  if (!r.ok) throw new Error(`baixar ${bucket}/${name}: ${r.status}`);
  return {
    bytes: new Uint8Array(await r.arrayBuffer()),
    type: r.headers.get("content-type") ?? "application/octet-stream",
  };
}

/// Devolve false quando o arquivo já existe no destino (409) — para a volta
/// da quarentena, isso significa "já restaurado numa tentativa anterior".
async function subir(
  bucket: string,
  name: string,
  file: { bytes: Uint8Array; type: string },
  token: string,
  apikey: string,
  upsert: boolean,
): Promise<boolean> {
  const r = await fetch(`${URL_BASE}/storage/v1/object/${bucket}/${enc(name)}`, {
    method: "POST",
    headers: {
      apikey,
      authorization: `Bearer ${token}`,
      "content-type": file.type,
      "x-upsert": upsert ? "true" : "false",
    },
    body: file.bytes,
  });
  if (r.ok) return true;
  const t = await r.text();
  // Versões do Storage respondem "já existe" como 409 ou como 400 com o
  // texto no corpo.
  if (!upsert && (r.status === 409 || /already exists|duplicate/i.test(t))) {
    return false;
  }
  throw new Error(`subir ${bucket}/${name}: ${r.status} ${t}`);
}

async function apagarArquivos(bucket: string, names: string[]) {
  if (names.length === 0) return;
  const r = await fetch(`${URL_BASE}/storage/v1/object/${bucket}`, {
    method: "DELETE",
    headers: {
      apikey: SERVICE,
      authorization: `Bearer ${SERVICE}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ prefixes: names }),
  });
  if (!r.ok) throw new Error(`apagar em ${bucket}: ${r.status} ${await r.text()}`);
}

// ── Ações ───────────────────────────────────────────────────────────────────

async function guardar(uid: string, token: string) {
  // Primeiro o perfil: se isso falhar, nenhuma foto sai do lugar.
  await rpc("deactivate_my_account", token, ANON);

  const arquivos = await rpc("arquivos_publicos_de", SERVICE, SERVICE, {
    p_uid: uid,
  }) as { bucket_id: string; name: string }[];

  let movidos = 0;
  for (const a of arquivos) {
    const file = await baixar(a.bucket_id, a.name);
    // Copia antes de apagar: se cair no meio, o arquivo existe em algum lugar.
    await subir(QUARENTENA, `${uid}/${a.bucket_id}/${a.name}`, file, SERVICE, SERVICE, true);
    await apagarArquivos(a.bucket_id, [a.name]);
    movidos++;
  }
  return { movidos };
}

async function restaurar(uid: string, token: string) {
  await rpc("reactivate_my_account", token, ANON);

  const arquivos = await rpc("arquivos_em_quarentena", SERVICE, SERVICE, {
    p_uid: uid,
  }) as { name: string }[];

  let devolvidos = 0;
  for (const { name } of arquivos) {
    // <uid>/<bucket>/<caminho original>
    const [, bucket, ...resto] = name.split("/");
    if (!bucket || resto.length === 0) continue;
    const file = await baixar(QUARENTENA, name);
    // Token do USUÁRIO na volta: o dono do arquivo fica certo, e a policy de
    // caminho do bucket decide se ele pode gravar ali.
    await subir(bucket, resto.join("/"), file, token, ANON, false);
    await apagarArquivos(QUARENTENA, [name]);
    devolvidos++;
  }
  return { devolvidos };
}

async function apagar() {
  const contas = await rpc("contas_para_apagar", SERVICE, SERVICE) as { id: string }[];
  let arquivos = 0;
  for (const { id } of contas) {
    const nomes = (await rpc("arquivos_em_quarentena", SERVICE, SERVICE, {
      p_uid: id,
    }) as { name: string }[]).map((a) => a.name);
    await apagarArquivos(QUARENTENA, nomes);
    arquivos += nomes.length;
  }
  // Só depois dos arquivos: apagar a conta antes deixaria arquivo órfão.
  const contasApagadas = await rpc("purge_deactivated_accounts", SERVICE, SERVICE);
  return { contas: contasApagadas, arquivos };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "use POST" }, 405);
  if (!JWT_SECRET || !SERVICE || !ANON) {
    return json({ error: "função sem configuração" }, 500);
  }

  const auth = req.headers.get("authorization") ?? "";
  const token = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7).trim() : "";
  const payload = token ? await verifyJwt(token) : null;
  if (!payload) return json({ error: "não autorizado" }, 401);

  let acao = "";
  try {
    acao = String((await req.json())?.acao ?? "");
  } catch {
    return json({ error: "corpo inválido" }, 400);
  }

  try {
    if (acao === "apagar") {
      if (payload.role !== "service_role") return json({ error: "não autorizado" }, 403);
      return json(await apagar());
    }

    // As outras duas exigem usuário logado, e agem só sobre ele.
    const uid = typeof payload.sub === "string" ? payload.sub : "";
    if (payload.role !== "authenticated" || !uid) {
      return json({ error: "não autorizado" }, 401);
    }
    if (acao === "guardar") return json(await guardar(uid, token));
    if (acao === "restaurar") return json(await restaurar(uid, token));
    return json({ error: `ação desconhecida: ${acao}` }, 400);
  } catch (e) {
    // O detalhe vai para o log do container, não para a resposta: ele traz
    // nome de bucket e caminho de arquivo.
    console.error(`quarentena/${acao}:`, e);
    return json({ error: "falha ao processar, tente de novo" }, 500);
  }
});
