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
- **Background**: localização com tela apagada é impossível → Wake Lock.
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
(Nginx + Cloudflare). Depois de cada deploy, **purgar o cache do Cloudflare**,
senão o `main.dart.js` antigo continua sendo servido.

## Banco de dados / Migrations
- Migrations ficam em `ride_app/supabase/migrations/NNN_*.sql` e **também** são
  acrescentadas a `_BUNDLE.sql`.
- Ao criar uma migration nova: rodar no **SQL Editor do Studio** do Supabase
  self-hosted (não há `supabase db push` automático aqui).
- RLS está ligada em quase todas as tabelas — lembrar de policies em features novas.

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
