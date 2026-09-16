# RideApp — Instruções do projeto

App Flutter de rolês e viagens de moto, com backend **Supabase self-hosted**
(Docker numa VPS Hostinger). O código do app vive em `ride_app/`.

O **mesmo código-fonte** gera o **app nativo** (Android/iOS, futuramente nas lojas)
e o **PWA web** (`app.ride.dev.br`). Ver **Paridade App ↔ Web** abaixo.

> Edite este arquivo livremente. Tudo aqui é tratado como regra do projeto.

---

## Stack
- **Flutter** (Dart SDK ^3.11.3), gerenciamento de estado com **Provider** (ChangeNotifier).
- **GoRouter** para navegação — rotas centralizadas em `ride_app/lib/app/routes.dart`.
- **Supabase** (self-hosted) — auth, Postgres + RLS, Storage, Realtime.
- Maps: `google_maps_flutter` (na web o federated `google_maps_flutter_web`).
  Places/Geocoding/Directions vão **sempre** pela Edge Function `gmaps` via
  `MapsProxy` (`lib/core/services/maps_proxy.dart`) — **nunca** direto do cliente:
  o servidor injeta a chave e devolve o CORS.
  A função **valida o JWT por conta própria** (o `VERIFY_JWT` do self-hosted é
  global, não dá pra configurar por função): busca/geocoding/rotas exigem usuário
  logado — `MapsProxy.headers` manda o token da sessão, não a chave anônima.
  Só `place/photo` fica aberto, porque `<img>`/CanvasKit não manda cabeçalho;
  o risco é contido porque a foto exige um `photo_reference`, que só sai de uma
  busca autenticada.
  **A fazer no futuro:** cachear as fotos de Places no **Supabase Storage** — a
  foto vira URL pública comum (sem proxy, sem CORS, nada aberto) e o Google
  passa a ser cobrado uma vez por foto em vez de por visualização. Hoje não dá
  porque `MapsProxy.photoUrl` é síncrono e é usado por ~7 telas.
- Imagens: `image` (compressão) + `cached_network_image` / `flutter_cache_manager`.
- Web/PWA: pasta `web/` (manifest + `env.js` com a chave do Maps, git-ignored).

## Estrutura
- `lib/core/models/` — models com `fromMap`/`toMap` (ponte snake_case ↔ camelCase).
- `lib/core/services/` — services Supabase com **métodos estáticos** (`Supabase*Service`).
- `lib/features/<feature>/{screens,viewmodels}/` — UI + ViewModels por feature.
- `lib/shared/widgets/` — widgets reutilizáveis.
- `lib/theme/` — `AppColors`, `AppTextStyles`, `AppSpacing`.
- `supabase/migrations/` — SQL versionado; `_BUNDLE.sql` reúne tudo.

## Convenções
- **Cores:** `AppColors.navy` é a cor **primária** (botões, cards, bolhas próprias);
  `AppColors.teal` é só **acento** (ex: indicador online). Fundo = `AppColors.background`.
- **AppBar padrão:** `backgroundColor: AppColors.background`, `surfaceTintColor: Colors.transparent`,
  ícone de voltar `Icons.arrow_back_ios` em `AppColors.navy`, título peso `w800`.
- Models toleram campos nulos/ausentes no `fromMap` (nunca explodir em parsing parcial).
- ViewModels expõem `reset()` para o logout zerar o estado.
- Toda imagem enviada ao Supabase passa por `ImageUtils.compressToJpeg` (≤360KB, JPEG).

## Paridade App ↔ Web
O mesmo código serve o app nativo e o PWA. **Toda mudança — design, layout ou
feature nova — tem que valer para os dois.** Se a web tiver limitação, a gente
acha um caminho alternativo; não se entrega feature que só funciona num lado.

### Escada de decisão (quando a web limita)
Tentar sempre do 1 para o 5, nessa ordem:
1. **Funciona igual** — a maioria dos casos.
2. **Troca o mecanismo, mantém a feature** — `kIsWeb` **dentro do service**.
   Ex.: login Google (nativo `google_sign_in` / web OAuth redirect do Supabase);
   câmera do mapa (`newLatLngBounds` no mobile, `newLatLngZoom` na web).
3. **Empurra pro servidor** — resolve as duas plataformas de uma vez.
   Ex.: Edge Function `gmaps` (proxy de Places/Geocoding/Directions) matou o CORS
   da web **e** tirou a chave do Google do cliente no mobile.
   **Preferir este degrau sempre que der** — costuma melhorar a arquitetura.
4. **Degrada com equivalente honesto** — mesmo objetivo, outro caminho, avisando
   o usuário. Ex.: localização em background não existe na web → "Modo Rolê" com
   Wake Lock (mantém a tela ligada durante a gravação).
5. **Esconde na web** — último recurso, só se não for funcionalidade central.

### Regras
- **`kIsWeb` mora em service, nunca dentro de `Widget`.** As telas ficam
  agnósticas — assim mudança de design/layout vale para os dois automaticamente.
- **Responsivo por largura, não por plataforma.** Usar `LayoutBuilder`/breakpoints;
  nunca "se for web, layout X". Layout largo na web = layout de tablet no nativo.
- **Imagem só de origem com CORS.** O CanvasKit (Flutter web) lê o pixel da
  imagem, então **toda imagem externa precisa de CORS**: usar Supabase Storage ou
  o proxy `gmaps`. URL de terceiro direto em `Image.network`/`CachedNetworkImage`
  quebra na web (foi o que derrubou a foto de capa das viagens).
- **Antes de dar por pronto: testar no celular E no navegador.** Enquanto se
  testa só um lado, a divergência entra sem ninguém perceber.

### Limitações web conhecidas
- **Background**: localização com tela apagada é impossível na web → "Modo Rolê"
  via `WakeLockService` (`lib/core/services/wake_lock_service.dart`, usa
  `wakelock_plus`). Segura a tela ligada durante a gravação; **no nativo é
  no-op** de propósito (lá já existe background). A UI pergunta
  `ActiveSessionViewModel.screenKeptOn` — capacidade, não plataforma.
- **Push**: FCM e `flutter_local_notifications` não rodam na web (isolados com
  `kIsWeb`); web push exige config própria e, no iOS, só com o PWA instalado na
  tela de início.
- **Mapa** (`google_maps_flutter_web`): `newLatLngBounds` abre no mundo todo;
  redimensionar o mapa faz os tiles sumirem (usar altura fixa).
- **CORS**: web services do Google e imagens externas → sempre pelo proxy.
- **Deep links**: web usa a própria URL; nativo usa App Links.

## Comandos
```bash
cd ride_app
flutter analyze            # deve ficar sem unused_*/dead_code
flutter test               # suíte de testes unitários
flutter build apk --release
flutter build web --release   # saída em build/web
```
Deploy web: `scp -r build/web/* root@2.24.114.7:/var/www/app-ride/`
(Nginx na VPS, atrás do Cloudflare). Uma **Cache Rule** no Cloudflare já faz
bypass dos arquivos de nome fixo que mudam a cada build (`/`, `index.html`,
`main.dart.js`, `flutter_bootstrap.js`, `flutter_service_worker.js`,
`version.json`, `/assets/*`), então **não é preciso purgar o cache** —
só o `/canvaskit/` fica cacheado (muda só com a versão do Flutter).

## Cache: o que nunca cachear
O cache offline do PWA existe para o **app shell** (HTML, JS, CanvasKit, fontes,
ícones) — é o que faz o app abrir sem sinal.

**Nunca cachear resposta de API nem conteúdo patrocinado.** O app vai ter
anúncios/mini-marketplace, e ali cache quebra o negócio, não só a UX:
- anúncio cacheado segue aparecendo depois do fim da campanha (exibição que o
  lojista não pagou);
- se a requisição não chega ao servidor, a **impressão não é contada** — e em
  marketplace impressão e clique são o produto;
- "personalizado" e "cacheado" são contraditórios por definição.

Arquivo estático que muda de vez em quando (ícone, og-image): **versionar a URL**
(`favicon.png?v=2`) em vez de tirar do cache. Atualiza na hora e mantém o
desempenho. Purgar CDN é remédio pontual, não solução.

## Datas e horários
**Guarda em UTC, mostra na hora do aparelho.** No Brasil isso dá o horário de
Brasília sozinho, e quem está no Acre, Amazonas ou Fernando de Noronha vê a hora
certa do lugar onde está — sem depender de UF cadastrada.

Toda data que atravessa o Supabase passa por `DbTime`
(`lib/core/utils/db_time.dart`) — **nunca** `DateTime.parse`/`toIso8601String`
direto:
- lendo: `DbTime.tryParse(row['campo'])` (ou `DbTime.parse` para campo obrigatório);
- gravando: `DbTime.toDb(data)`;
- comparando com coluna (`.gte('starts_at', ...)`): `DbTime.nowForDb()`.

Por que a regra existe: os dois lados estavam errados e os erros se cancelavam
**na tela**, escondendo o problema. `toIso8601String()` num `DateTime` local gera
string sem fuso, e o Postgres (em UTC) lia o horário como se já fosse UTC —
gravando 3h adiantado. Na leitura o valor voltava UTC e o `DateFormat` imprimia o
relógio UTC. Parecia certo no app e estava errado para o worker de push, para
`NOW()` e para qualquer um em outro fuso.

O formato (`dd/MM/yyyy HH:mm`, 24h, em `DateTimeExt`) já é o brasileiro — o que
faltava era o fuso.

## Banco de dados / Migrations
- Migrations ficam em `ride_app/supabase/migrations/NNN_*.sql` e **também** são
  acrescentadas a `_BUNDLE.sql`.
- Ao criar uma migration nova: rodar no **SQL Editor do Studio** do Supabase
  self-hosted (não há `supabase db push` automático aqui).
- RLS está ligada em quase todas as tabelas — lembrar de policies em features novas.

## Segurança — vale para TODA alteração
**Antes de dar qualquer mudança por pronta, perguntar: isso abre alguma falha?**
E, se abrir, apresentar o meio de contornar junto com a mudança — não depois.
Vale para código, config de servidor, migration, cache e dependência nova.

### Perguntas obrigatórias
1. **Quem consegue chamar isso?** Endpoint novo (Edge Function, rota, storage)
   nasce **fechado**. Se precisar ficar aberto, dizer por quê e o que limita o
   estrago. Ex.: o proxy `gmaps` exige usuário logado; `place/photo` é a exceção
   (a tag `<img>` não manda cabeçalho) e só se sustenta porque a foto depende de
   um `photo_reference`, que só sai de uma busca autenticada.
2. **Quem consegue ler/escrever essa linha?** Tabela nova = **policy de RLS na
   mesma migration**. Conferir SELECT, INSERT, UPDATE e DELETE separadamente —
   `USING (auth.uid() IS NOT NULL)` não é filtro, é "qualquer logado"; foi assim
   que as mensagens de todo mundo ficaram legíveis por qualquer conta.
3. **Esse segredo pode ir pro cliente?** Chave de API, token de serviço e senha
   ficam **no servidor**. A `anon key` é pública (vai dentro do app), então não
   serve como autenticação de nada.
4. **Isso gasta dinheiro de quem?** Rota que chama API paga (Google Maps, push,
   storage) sem autenticação vira conta aberta na nossa fatura.
5. **O que acontece se o campo vier nulo, gigante ou malicioso?** Entrada de
   usuário que vira query, caminho de arquivo, HTML ou URL precisa ser validada.
6. **Cache pode vazar ou congelar algo?** Não cachear resposta de API nem
   conteúdo por usuário (ver "Cache: o que nunca cachear"). `add_header ...
   always` no Nginx cacheia até resposta de erro.

### Regras
- Mudança em **config de servidor** (Nginx, Docker, firewall, SSH): revisar a
  própria proposta procurando o efeito colateral antes de aplicar.
- **Nunca** afrouxar autenticação para "fazer funcionar". Se travou, procurar o
  caminho que mantém fechado — quase sempre existe (ver a escada de decisão).
- Ao encontrar uma falha em código que já está no ar, **avisar na hora**, mesmo
  que esteja no meio de outra tarefa.
- Segredo que nunca deve ser colado no chat nem commitado: Service Account do
  Firebase, `service_role` do Supabase, senha de root da VPS, chave SSH privada,
  `GOOGLE_SECRET` do OAuth.

## Testes
- Foco em **funções puras**: models (`fromMap`/getters), helpers, lógica sem rede.
- Lógica que depende de Supabase/isolate: extrair a parte pura e marcar
  `@visibleForTesting` (ex: `ImageUtils.compressJpegSync`).

---

## Minhas preferências (edite aqui)
<!-- Ex.: "Sempre responda em português." / "Não rode build sem eu pedir." /
     "Antes de mexer em migration, me mostre o SQL primeiro." -->
- Sempre responda em português.
- Não gere APK sem eu pedir explicitamente.
- Antes de criar/alterar migration, me mostre o SQL e espere meu OK.
- Não commite nada automaticamente.
- Prefira editar arquivos existentes a criar novos.
- Sempre faça testes unitários para novas funcões.
- antes de criar uma função veja se já existe uma no código e reaproveite, isso evita codigo duplicado.
- Evite: engenharia especulativa,implementações alucinatórias,efeitos colaterais ocultos,mudanças de comportamento silenciosas e complexidade desnecessária.
