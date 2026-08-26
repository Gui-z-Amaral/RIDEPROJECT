/// URLs públicas do RideApp usadas em compartilhamento e deep links.
///
/// [base] deve apontar para o site oficial. Quando o site estiver no ar com
/// App Links (Android) / Universal Links (iOS) configurados, esses links
/// abrirão direto no app quando ele estiver instalado; caso contrário, caem
/// numa página web. Enquanto isso, o link já é compartilhável.
///
/// Para trocar o domínio depois: basta alterar [base].
class AppLinks {
  AppLinks._();

  /// Domínio oficial do site.
  static const String base = 'https://ride.dev.br';

  static String event(String id) => '$base/e/$id';
  static String trip(String id) => '$base/v/$id';
  static String ride(String id) => '$base/r/$id';
  static String club(String id) => '$base/c/$id';
  static String profile(String id) => '$base/u/$id';
}
