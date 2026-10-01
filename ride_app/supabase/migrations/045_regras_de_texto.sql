-- 045 — Regras de texto no SERVIDOR: @ único, tamanhos e palavras bloqueadas
--
-- Até aqui nenhuma tabela tinha regra de texto. Toda validação estava só no
-- app, e quem chamasse a API direto gravava qualquer coisa: título de 1 MB,
-- nome só com espaços, palavrão no nome do motoclube — e esse texto aparecia
-- no perfil, na busca, na prévia do link compartilhado e no PUSH.
--
-- Três partes:
--   1. @ gerado sem colisão: "João Silva" e "João Silva" não travam mais o
--      segundo cadastro (o @ é UNIQUE e era só o nome em minúsculas).
--   2. Tamanho mínimo e máximo por campo.
--   3. Palavras bloqueadas, comparadas por PALAVRA INTEIRA depois de
--      normalizar (sem acento, "p0rr4" → "porra", "p o r r a" → "porra").
--      Por trecho seria inviável aqui: "rola" pegaria "Rolê" e "rolando",
--      "cu" pegaria "curva", "pau" pegaria "São Paulo".
--
-- As regras valem só quando o campo MUDA. Dado antigo fora da regra continua
-- lá e não trava a edição de outro campo da mesma linha.
--
-- Chat fica de fora do filtro: conversa privada; ali a ferramenta certa é
-- bloquear e denunciar, não censurar. Só ganha limite de tamanho.

-- ══ Normalização ═════════════════════════════════════════════════════════════

-- Tira caracteres invisíveis e de controle — espaço de largura zero e
-- inversão de direção (U+202E) servem para imitar o nome de outra pessoa.
CREATE OR REPLACE FUNCTION public.limpa_invisiveis(t TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT regexp_replace(COALESCE(t, ''),
    '[\x01-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]', '', 'g');
$$;

-- Para comparar com a lista: minúsculas, sem acento, "leet" desfeito e letra
-- repetida colapsada ("porraaa" → "pora"). A lista passa pela MESMA função,
-- então "porra" também vira "pora" e as duas batem.
CREATE OR REPLACE FUNCTION public.normaliza_texto(t TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT regexp_replace(
    translate(lower(public.limpa_invisiveis(t)),
      'áàâãäéèêëíìîïóòôõöúùûüçñ4@310!$57',
      'aaaaaeeeeiiiiooooouuuucnaaeioisst'),
    '(.)\1+', '\1', 'g');
$$;

-- ══ Palavras bloqueadas ══════════════════════════════════════════════════════
-- Editável no Studio, sem publicar nada. RLS ligada e sem policy: o app não lê
-- a lista (não há por que entregá-la), só as funções abaixo.
CREATE TABLE IF NOT EXISTS palavras_bloqueadas (
  palavra TEXT PRIMARY KEY
);
ALTER TABLE palavras_bloqueadas ENABLE ROW LEVEL SECURITY;

-- Lista inicial conservadora: só termos sem sentido inocente comum. Ficaram de
-- fora de propósito, por serem palavras normais também: pau, pinto, saco,
-- rola, piranha, veado, macaco, bicha, puto (= bravo), kkk (= risada).
INSERT INTO palavras_bloqueadas (palavra) VALUES
  ('caralho'), ('krl'), ('porra'), ('puta'), ('putaria'), ('foda'), ('foder'),
  ('fodido'), ('fodida'), ('fdp'), ('pqp'), ('vsf'), ('vtnc'), ('tnc'),
  ('buceta'), ('boceta'), ('xoxota'), ('xereca'), ('piroca'), ('punheta'),
  ('cu'), ('cuzao'), ('arrombado'), ('arrombada'), ('merda'), ('bosta'),
  ('viado'), ('sapatao'), ('traveco'), ('retardado'), ('retardada'),
  ('vagabunda'), ('escroto'), ('escrota'), ('porno'),
  ('nazi'), ('nazista'), ('hitler')
ON CONFLICT (palavra) DO NOTHING;

-- Devolve a palavra encontrada, ou NULL. Também junta letras soltas em
-- sequência ("p o r r a", "p.o.r.r.a") antes de comparar.
CREATE OR REPLACE FUNCTION public.texto_improprio(t TEXT)
RETURNS TEXT LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  tok TEXT;
  soltas TEXT := '';
  achou TEXT;
  candidatos TEXT[] := '{}';
BEGIN
  IF t IS NULL OR btrim(t) = '' THEN RETURN NULL; END IF;

  FOREACH tok IN ARRAY regexp_split_to_array(public.normaliza_texto(t), '[^a-z]+') LOOP
    IF tok = '' THEN CONTINUE; END IF;
    IF length(tok) = 1 THEN
      soltas := soltas || tok;
      CONTINUE;
    END IF;
    IF length(soltas) >= 2 THEN candidatos := candidatos || soltas; END IF;
    soltas := '';
    candidatos := candidatos || tok;
  END LOOP;
  IF length(soltas) >= 2 THEN candidatos := candidatos || soltas; END IF;

  -- O `soltas` passa pela normalização de novo: juntar "p o r r a" dá
  -- "porra", que ainda precisa colapsar para "pora".
  SELECT b.palavra INTO achou
    FROM palavras_bloqueadas b
   WHERE public.normaliza_texto(b.palavra) = ANY (
           SELECT public.normaliza_texto(c) FROM unnest(candidatos) c)
   LIMIT 1;
  RETURN achou;
END; $$;
REVOKE ALL ON FUNCTION public.texto_improprio(TEXT) FROM PUBLIC, anon, authenticated;

-- ══ Regras por campo — o único lugar onde os números moram ══════════════════
-- O app espelha estes limites em `TextLimits` só para avisar antes de salvar.
CREATE OR REPLACE FUNCTION public.regra_do_campo(p_campo TEXT,
  OUT minimo INT, OUT maximo INT, OUT filtrar BOOLEAN)
LANGUAGE sql IMMUTABLE AS $$
  SELECT r.mi, r.ma, r.fi FROM (VALUES
    ('nome',            2,    60, true),
    ('username',        3,    30, true),
    ('bio',             0,   500, true),
    ('cidade',          0,    80, false),
    ('moto',            0,    60, true),
    ('estilo',          0,    40, true),
    ('negocio',         0,    80, true),
    ('negocio_desc',    0,  1000, true),
    ('clube',           3,    60, true),
    ('clube_desc',      0,  1000, true),
    ('evento',          3,   100, true),
    ('evento_desc',     0,  3000, true),
    ('local',           0,   120, true),
    ('viagem',          3,   100, true),
    ('viagem_desc',     0,  3000, true),
    ('role',            3,   100, true),
    ('mensagem',        0, 40000, false)  -- envelope cifrado, não o texto
  ) AS r(campo, mi, ma, fi)
  WHERE r.campo = p_campo;
$$;

-- NULL = ok; senão o motivo: vazio | curto | longo | formato | improprio.
CREATE OR REPLACE FUNCTION public.problema_no_texto(p_campo TEXT, p_valor TEXT)
RETURNS TEXT LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r RECORD; v TEXT;
BEGIN
  SELECT * INTO r FROM public.regra_do_campo(p_campo);
  IF r.maximo IS NULL THEN RETURN NULL; END IF;  -- campo sem regra
  v := btrim(public.limpa_invisiveis(p_valor));

  IF r.minimo > 0 AND v = '' THEN RETURN 'vazio'; END IF;
  IF v <> '' AND char_length(v) < r.minimo THEN RETURN 'curto'; END IF;
  IF char_length(v) > r.maximo THEN RETURN 'longo'; END IF;
  IF p_campo = 'username' AND v !~ '^[a-z0-9_]+$' THEN RETURN 'formato'; END IF;
  IF r.filtrar AND public.texto_improprio(v) IS NOT NULL THEN RETURN 'improprio'; END IF;
  RETURN NULL;
END; $$;
REVOKE ALL ON FUNCTION public.problema_no_texto(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- Para o app avisar ANTES de salvar — e no cadastro, onde o GoTrue esconde o
-- erro do trigger atrás de "Database error saving new user". Aberta ao anônimo
-- por isso; só diz se o texto passa, não expõe a lista nem dado de ninguém.
CREATE OR REPLACE FUNCTION public.checar_texto(p_campo TEXT, p_valor TEXT)
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.problema_no_texto(p_campo, left(p_valor, 50000));
$$;
REVOKE ALL ON FUNCTION public.checar_texto(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.checar_texto(TEXT, TEXT) TO anon, authenticated;

-- Levanta o erro num formato que o app sabe ler: "texto_invalido:<motivo>:<campo>".
CREATE OR REPLACE FUNCTION public.exige_texto(p_campo TEXT, p_valor TEXT)
RETURNS VOID LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE p TEXT := public.problema_no_texto(p_campo, p_valor);
BEGIN
  IF p IS NOT NULL THEN
    RAISE EXCEPTION 'texto_invalido:%:%', p, p_campo USING ERRCODE = 'check_violation';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION public.exige_texto(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- ══ Aplicação nas tabelas ════════════════════════════════════════════════════
-- Duas travas para não quebrar o que já existe:
--  - só checa o campo que MUDOU: linha antiga fora da regra não trava a edição
--    de outro campo;
--  - só checa escrita vinda da API (`authenticated`/`anon`). As funções
--    internas rodam como dono do banco e ficam de fora — importante para a
--    REATIVAÇÃO, que grava de volta nome, @ e bio de antes das regras (um @
--    antigo como "joão_silva" seria barrado e a pessoa não conseguiria entrar).
--    Por isso estes triggers NÃO são SECURITY DEFINER: `current_user` precisa
--    ser quem escreveu. A leitura da lista acontece dentro de `exige_texto`,
--    que é.

CREATE OR REPLACE FUNCTION public.valida_texto_profiles()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' OR NEW.name IS DISTINCT FROM OLD.name THEN
    NEW.name := btrim(public.limpa_invisiveis(NEW.name));
    PERFORM public.exige_texto('nome', NEW.name);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.username IS DISTINCT FROM OLD.username THEN
    PERFORM public.exige_texto('username', NEW.username);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.business_name IS DISTINCT FROM OLD.business_name THEN
    PERFORM public.exige_texto('negocio', NEW.business_name);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.business_description IS DISTINCT FROM OLD.business_description THEN
    PERFORM public.exige_texto('negocio_desc', NEW.business_description);
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_valida_texto_profiles ON profiles;
CREATE TRIGGER trg_valida_texto_profiles BEFORE INSERT OR UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.valida_texto_profiles();

CREATE OR REPLACE FUNCTION public.valida_texto_profile_details()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' OR NEW.bio IS DISTINCT FROM OLD.bio THEN
    PERFORM public.exige_texto('bio', NEW.bio);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.city IS DISTINCT FROM OLD.city THEN
    PERFORM public.exige_texto('cidade', NEW.city);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.moto_model IS DISTINCT FROM OLD.moto_model THEN
    PERFORM public.exige_texto('moto', NEW.moto_model);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.trip_style IS DISTINCT FROM OLD.trip_style THEN
    PERFORM public.exige_texto('estilo', NEW.trip_style);
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_valida_texto_profile_details ON profile_details;
CREATE TRIGGER trg_valida_texto_profile_details BEFORE INSERT OR UPDATE ON profile_details
  FOR EACH ROW EXECUTE FUNCTION public.valida_texto_profile_details();

CREATE OR REPLACE FUNCTION public.valida_texto_clubs()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' OR NEW.name IS DISTINCT FROM OLD.name THEN
    NEW.name := btrim(public.limpa_invisiveis(NEW.name));
    PERFORM public.exige_texto('clube', NEW.name);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.description IS DISTINCT FROM OLD.description THEN
    PERFORM public.exige_texto('clube_desc', NEW.description);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.city IS DISTINCT FROM OLD.city THEN
    PERFORM public.exige_texto('cidade', NEW.city);
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_valida_texto_clubs ON clubs;
CREATE TRIGGER trg_valida_texto_clubs BEFORE INSERT OR UPDATE ON clubs
  FOR EACH ROW EXECUTE FUNCTION public.valida_texto_clubs();

CREATE OR REPLACE FUNCTION public.valida_texto_events()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' OR NEW.title IS DISTINCT FROM OLD.title THEN
    NEW.title := btrim(public.limpa_invisiveis(NEW.title));
    PERFORM public.exige_texto('evento', NEW.title);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.description IS DISTINCT FROM OLD.description THEN
    PERFORM public.exige_texto('evento_desc', NEW.description);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.location_label IS DISTINCT FROM OLD.location_label THEN
    PERFORM public.exige_texto('local', NEW.location_label);
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_valida_texto_events ON events;
CREATE TRIGGER trg_valida_texto_events BEFORE INSERT OR UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION public.valida_texto_events();

CREATE OR REPLACE FUNCTION public.valida_texto_trips()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' OR NEW.title IS DISTINCT FROM OLD.title THEN
    NEW.title := btrim(public.limpa_invisiveis(NEW.title));
    PERFORM public.exige_texto('viagem', NEW.title);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.description IS DISTINCT FROM OLD.description THEN
    PERFORM public.exige_texto('viagem_desc', NEW.description);
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_valida_texto_trips ON trips;
CREATE TRIGGER trg_valida_texto_trips BEFORE INSERT OR UPDATE ON trips
  FOR EACH ROW EXECUTE FUNCTION public.valida_texto_trips();

CREATE OR REPLACE FUNCTION public.valida_texto_rides()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' OR NEW.title IS DISTINCT FROM OLD.title THEN
    NEW.title := btrim(public.limpa_invisiveis(NEW.title));
    PERFORM public.exige_texto('role', NEW.title);
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_valida_texto_rides ON rides;
CREATE TRIGGER trg_valida_texto_rides BEFORE INSERT OR UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION public.valida_texto_rides();

CREATE OR REPLACE FUNCTION public.valida_texto_messages()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  PERFORM public.exige_texto('mensagem', NEW.content);
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_valida_texto_messages ON messages;
CREATE TRIGGER trg_valida_texto_messages BEFORE INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION public.valida_texto_messages();

-- ══ @ único no cadastro ══════════════════════════════════════════════════════
-- Base do @: minúsculas, sem acento, só a-z 0-9 _, até 20 caracteres.
CREATE OR REPLACE FUNCTION public.slug_username(t TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT left(btrim(regexp_replace(
           translate(lower(public.limpa_invisiveis(t)),
             'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'),
           '[^a-z0-9]+', '_', 'g'), '_'), 20);
$$;

-- Antes: o @ era o nome em minúsculas, UNIQUE, sem tratar repetição — a
-- segunda "João Silva" não conseguia criar conta nem entrar com o Google.
-- Agora, se já existe, ganha um sufixo; nunca falha por nome repetido.
-- Nome impróprio vindo do Google não barra o login: vira "Rider" e a pessoa
-- troca depois (barrar ali daria só o erro genérico do GoTrue).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  nome TEXT;
  base TEXT;
  cand TEXT;
  tentativas INT := 0;
BEGIN
  nome := left(btrim(public.limpa_invisiveis(COALESCE(
            NULLIF(btrim(NEW.raw_user_meta_data->>'name'), ''),
            NULLIF(btrim(NEW.raw_user_meta_data->>'full_name'), ''),
            split_part(NEW.email, '@', 1)))), 60);
  IF char_length(nome) < 2 OR public.texto_improprio(nome) IS NOT NULL THEN
    nome := 'Rider';
  END IF;

  base := public.slug_username(COALESCE(
            NULLIF(NEW.raw_user_meta_data->>'username', ''), nome));
  IF char_length(base) < 3 OR public.texto_improprio(base) IS NOT NULL THEN
    base := 'rider';
  END IF;

  cand := base;
  WHILE EXISTS (SELECT 1 FROM profiles WHERE username = cand) LOOP
    tentativas := tentativas + 1;
    cand := base || '_' || CASE
      WHEN tentativas <= 20 THEN lpad(floor(random() * 10000)::int::text, 4, '0')
      ELSE substr(md5(random()::text), 1, 8) END;
  END LOOP;

  INSERT INTO public.profiles (id, username, name, avatar_url)
  VALUES (NEW.id, cand, nome, NEW.raw_user_meta_data->>'avatar_url')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END; $$;
