
/// URLs públicas do RideApp usadas em compartilhamento e deep links.
///
/// [base] é o **próprio PWA**. Assim o link compartilhado abre o app: o Nginx
/// faz fallback de SPA, então `/e/<id>` carrega o `index.html` e o GoRouter
/// resolve a rota. No Android, com o PWA instalado, o sistema abre o app
/// instalado em vez do navegador.
///
/// Antes apontava para `redirect.ride.dev.br` (o site de apresentação antigo),
/// e era por isso que o link caía fora do app.
///
/// **Limitação do iOS:** o Safari não entrega links para PWA instalado —
/// mesmo com o app na tela de início, o link abre numa aba. É limitação do
/// sistema, não tem contorno no nosso lado.
///
/// Para trocar o domínio depois: basta alterar [base].
class AppLinks {
  AppLinks._();

  /// Domínio do PWA.
  static const String base = 'https://app.ride.dev.br';

  /// Para onde mandar a pessoa depois de entrar, quando ela chegou por um link
  /// compartilhado (`/login?next=/e/<id>`).
  ///
  /// **Só aceita caminho interno.** Sem esta checagem, um link
  /// `/login?next=https://site-falso/...` levaria a pessoa recém-logada para
  /// fora do app — é o clássico *open redirect*, usado para phishing.
  /// URL absoluta para onde o Google deve devolver a pessoa depois do login.
  ///
  /// Na web o login com Google é um **redirect de página inteira**: o app é
  /// descarregado e recarregado no endereço que voltar daqui. Mandar só a
  /// origem (era o que acontecia) descartava o caminho, e quem clicou no link
  /// de uma viagem caía na home depois de entrar.
  ///
  /// Passa por [safeNext], então um `next` forjado não vira redirect para fora.
  static String oauthReturnUrl(String origin, String? next) =>
      '$origin${safeNext(next)}';

  static String safeNext(String? next, {String fallback = '/home'}) {
    if (next == null || next.isEmpty) return fallback;
    // '//host' é URL protocol-relative: sai do domínio. '/\' idem em alguns
    // navegadores.
    if (!next.startsWith('/') ||
        next.startsWith('//') ||
        next.startsWith('/\\')) {
      return fallback;
    }
    return next;
  }

  static String event(String id) => '$base/e/$id';
  static String trip(String id) => '$base/v/$id';
  static String ride(String id) => '$base/r/$id';
  static String club(String id) => '$base/c/$id';

  /// Convite para entrar num motoclube. O token é a credencial: quem tem o
  /// link entra, então ele nunca deve ser exposto fora do compartilhamento.
  static String clubInvite(String token) => '$base/ci/$token';
  static String profile(String id) => '$base/u/$id';
}
