# RideApp — Handoff

Estado em **01/10/2026**, commit `c2caece` (tag `v1-pausado` = mesmo código).
Para quem vai assumir o projeto: o que ele é, o que funciona, onde mora cada
coisa, e o que ficou pendente. Complementa o [CLAUDE.md](CLAUDE.md) (regras do
projeto) e o [COMO-RETOMAR.md](COMO-RETOMAR.md) (subir tudo do backup).

---

## 1. Contexto

**O que é:** app social de rolês e viagens de moto — motoclubes, eventos,
viagens com rota e paradas, rolê com mapa ao vivo, chat e notificações. Feito
por Guilherme Zeferino Amaral e Mateus Zeferino Januário, polo Araranguá/SC.

**Situação do produto:**
- **41 usuários**, 4 motoclubes; 28 contas novas só em setembro/2026, sem
  marketing pago.
- Apresentado no **Programa Nascer 2026** e **não aprovado**: a banca avaliou
  que o app não se sustenta só com anúncio (o modelo era anúncio do comércio
  da rota + assinatura opcional).
- Conversas com presidentes de motoclube: **não viram necessidade** de trocar
  o WhatsApp pelo app.
- Ideias de pivô avaliadas e descartadas: gestão de motoclube (mesma objeção),
  "Strava da moto" (REVER e Riser foram vendidos, não viraram empresa
  sozinhos) e gravador de rota com vídeo (o Relive já faz).
- Decisão de **pausar** em 01/10/2026. A pausa foi **revertida no mesmo dia**
  para um teste — o app está **no ar** neste momento (ver seção 6).

**Onde está o aprendizado:** as três ideias nasceram de uma solução, não de
uma dor. O próximo passo recomendado é achar um problema que alguém já paga
para resolver, antes de escrever código.

---

## 2. Arquitetura

| Camada | Tecnologia |
|---|---|
| App | Flutter (Dart ^3.11), Provider, GoRouter. **Um código** gera APK e PWA |
| Backend | Supabase self-hosted (Docker) numa VPS Hostinger `2.24.114.7` |
| API pública | `https://api.ride.dev.br` (atrás da Cloudflare) |
| PWA | `https://app.ride.dev.br` (Nginx na VPS) |
| Mapas | Google Maps no app; Places/Geocoding/Directions **só** pela Edge Function `gmaps` |
| Push | Firebase Cloud Messaging + container `rideapp-push-worker` na VPS |
| Email | Resend (confirmação de conta) |

**Edge Functions** (`ride_app/supabase/functions/`):
- `gmaps` — proxy do Google (exige usuário logado; `place/photo` aberto).
- `share` — tags Open Graph para prévia de link no WhatsApp/Instagram.
- `quarentena` — desativar/reativar conta movendo as fotos para um bucket
  privado; apagar em definitivo no fim da retenção.

**Estrutura do código** (`ride_app/lib/`): `core/models`, `core/services`
(métodos estáticos `Supabase*Service`), `features/<feature>/{screens,viewmodels}`,
`shared/widgets`, `theme`. Detalhes e convenções no CLAUDE.md.

---

## 3. Funcionalidades

### Conta e perfil
- Cadastro por email (código de 6 dígitos via Resend) e login com Google.
  Email repetido entre Google e senha **vincula** a mesma conta.
- `@` gerado no servidor, com sufixo quando repete (045).
- Perfil com foto, banner, bio, cidade, moto, estilo de viagem, fotos e
  aparência customizável. Perfil comercial (`business_*`) para empresas.
- **Perfil privado de verdade** (042): bio, cidade, moto e fotos ficam em
  `profile_details`, liberados só para o dono, perfis públicos e amigos.
- Perfil de outra pessoa mostra motoclubes e viagens concluídas.
- **Desativar conta** (LGPD): anonimiza, move fotos para quarentena, reativa
  no próximo login, apaga em definitivo após 6 meses (timer diário na VPS).

### Social
- Amigos, pedidos de amizade, amigos em comum, busca de usuários.
- **Riders próximos**: mostra distância, nunca coordenada; opt-out em
  "Aparecer na descoberta".
- **Chat** 1:1 com texto e imagem. Mensagens **cifradas em repouso** com chave
  por conta guardada no servidor (036/037) — **não é ponta a ponta**, nunca
  divulgar como tal. Imagens em bucket privado com URL assinada (043).

### Motoclubes
- Criar clube, papéis dono/gerente/membro, gerenciar membros, configurações.
- **Convite por link** em três tipos: permanente, individual, expira em 1 h (038).
- Mural com eventos e viagens do clube, RSVP (Vou/Talvez/Não), lista de
  presença com check-in, histórico "Concluídas" (041).
- Evento e viagem de clube **nascem privados** e **nunca vão para a aba
  Eventos geral** — público = visível a quem visita o clube.

### Eventos
- Banner, local no mapa, início/término, cronograma, patrocinadores,
  participantes, visibilidade.
- "Tenho interesse" (contador público) + "Você vai?" (presença).
- **Saída do rolê** (046, só clube): horário e ponto de encontro próprios, com
  push "Saída alterada". Sugestão automática ao colar o aviso do WhatsApp.
- Descrição mostra formatação do WhatsApp (`*negrito*`, listas).
- Aba Eventos: só eventos sem clube (vitrine de empresas/prefeituras), por UF.

### Viagens
- Origem, destino, waypoints, paradas sugeridas (Places), cronograma, capa.
- Convidados (convite funciona desde a 040), sessão ativa com mapa.

### Rolês
- Imediato ou agendado, ponto de encontro, convite de amigos.
- **Sessão ativa** com mapa ao vivo dos participantes (Realtime). GPS legível
  só por quem está no rolê e apagado ao encerrar (043).
- Na web, "Modo Rolê" segura a tela ligada (Wake Lock).

### Notificações
- Push no Android e no PWA. **Criadas só pelo servidor** (044), por trigger:
  convite de viagem/rolê/clube, pedido de amizade, mensagem, evento e saída
  alterados. Toque abre a tela certa (rota `/n` + `notification_router.dart`).

### Compartilhamento
- Links curtos `/e/`, `/v/`, `/r/`, `/ci/` com prévia (Edge Function `share`)
  e tela pública para quem não tem conta.

### Regras de texto (045)
- Limites de tamanho por campo, palavras bloqueadas (tabela editável no
  Studio, comparação por palavra inteira) e busca com texto escapado.

### O que existe só como esqueleto
- **Chamada de voz** (`features/calls`): telas usam `mock_data.dart`, sem
  áudio real.
- **Tela de empresas** (`features/businesses`): listagem básica.

---

## 4. Banco de dados

- Migrations **001 a 046** em `ride_app/supabase/migrations/`, todas aplicadas
  em produção. `_BUNDLE.sql` reúne tudo.
- Aplicadas manualmente (SSH + `psql`, ou SQL Editor do Studio). Não há
  `supabase db push`.
- RLS ligada em praticamente tudo. Regra do projeto: **toda tabela nova nasce
  com policy na mesma migration**.
- Armadilha conhecida: o Supabase dá `EXECUTE` direto a `anon` e
  `authenticated` em toda função nova — `REVOKE FROM PUBLIC` não basta.

---

## 5. Segurança e LGPD

Auditoria completa em `privacidade/lgpd-auditoria.md` (**git-ignored de
propósito** — lista falhas com arquivo e linha).

**Corrigido:** L-01 (GPS legível por todos), L-02 (perfil privado
cosmético), L-04 (imagem do chat pública), L-05 (fotos de conta desativada
acessíveis), notificação forjável, foto de perfil alheia sobrescrevível,
auto-inscrição em viagem privada.

**Ainda aberto:**
- **L-03 — sem política de privacidade nem termos.** Bloqueia publicação na
  Play Store. O Guilherme tem um rascunho.
- L-07 — listas de participantes/membros legíveis por qualquer conta logada.
- L-08 (idade mínima), L-10 (encarregado/DPO), L-11 (exportar dados),
  L-12 (retenção de log do Nginx), L-13/L-14 (registro e plano de incidente).

**Segredos que nunca vão para o Git nem para o chat:** `pgsodium_root.key`
(sem ela o chat fica ilegível para sempre), `service_role`, `.env` da VPS,
Service Account do Firebase, `GOOGLE_SECRET`, chaves do Maps, senha e chave
SSH da VPS. Cópias no backup descrito no COMO-RETOMAR.md.

---

## 6. Estado operacional agora

| Item | Estado |
|---|---|
| VPS e Supabase | **no ar** (13 containers) |
| PWA `app.ride.dev.br` | **no ar** (pausa revertida em 01/10 para teste) |
| Página de "pausado" | pronta em `infra/pausado/` e em `/var/www/app-ride.pausado` na VPS |
| Backup completo | `Desktop\RideApp-backup-2026-10-01` (conferido por SHA-256) |
| Timer de limpeza | ativo (`purge-contas.timer`: contas vencidas + GPS parado) |
| APK | assinado com chave de **debug** — não publicável |

**Para pausar de novo:** na VPS, trocar `/var/www/app-ride` por
`/var/www/app-ride.pausado`. Para a página sobreviver ao desligamento da VPS,
ela precisa ir para a Cloudflare Pages (instruções enviadas ao sócio, que
administra a Cloudflare). **Guarda dos dados prometida até 01/04/2027.**

---

## 7. Pendências conhecidas

**Bloqueiam publicar na Play Store**
- Keystore de release (depende do CNPJ) — passo a passo em
  `Desktop\RideApp - Keystore e publicacao.md`. Ao criar, atualizar o
  `assetlinks.json` e o SHA-1 da chave Android do Maps.
- Política de privacidade e termos (L-03).
- Declaração de uso de localização na Play Console.

**Bugs registrados e não corrigidos**
- Mapa ao vivo de **viagem** não mostra os outros participantes: a posição é
  gravada numa tabela que só aceita rolê.
- `flutter_01.png` e `flutter_02.png` (screenshots soltos) ainda no Git.

**Nunca validado por uma pessoa**
- Chat entre duas contas depois da mudança para chave por conta.
- Desativar e reativar conta com fotos (quarentena).
- Push de "Saída alterada" e a sugestão a partir do texto do WhatsApp.

**Ideias registradas**
- Lembrete "a saída é daqui a 1 hora" (precisa de tarefa periódica na VPS).
- Cache das fotos do Google Places no Storage (hoje passam pelo proxy).

---

## 8. Comandos

```bash
cd ride_app
flutter analyze                 # sem error/warning
flutter test                    # 393 testes passando em 01/10/2026
flutter build apk --release
flutter build web --release     # deploy: scp -r build/web/* root@2.24.114.7:/var/www/app-ride/
```

Migration nova: escrever em `supabase/migrations/NNN_*.sql`, ensaiar dentro de
`BEGIN; ... ROLLBACK;`, aplicar com `--single-transaction`, acrescentar ao
`_BUNDLE.sql`.
