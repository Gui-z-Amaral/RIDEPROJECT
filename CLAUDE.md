# RideApp — Instruções do projeto

App Flutter de rolês e viagens de moto, com backend **Supabase self-hosted**
(Docker numa VPS Hostinger). O código do app vive em `ride_app/`.

> Edite este arquivo livremente. Tudo aqui é tratado como regra do projeto.

---

## Stack
- **Flutter** (Dart SDK ^3.11.3), gerenciamento de estado com **Provider** (ChangeNotifier).
- **GoRouter** para navegação — rotas centralizadas em `ride_app/lib/app/routes.dart`.
- **Supabase** (self-hosted) — auth, Postgres + RLS, Storage, Realtime.
- Maps: `google_maps_flutter` + Google Places/Geocoding via HTTP.
- Imagens: `image` (compressão) + `cached_network_image` / `flutter_cache_manager`.

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

## Comandos
```bash
cd ride_app
flutter analyze            # deve ficar sem unused_*/dead_code
flutter test               # suíte de testes unitários
flutter build apk --release
```

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
