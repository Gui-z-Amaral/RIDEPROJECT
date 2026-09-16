/// Ponte entre os `TIMESTAMPTZ` do Postgres e o `DateTime` do app.
///
/// Regra do projeto: **guarda em UTC, mostra na hora do aparelho.** No Brasil
/// isso dá o horário de Brasília sozinho, e quem estiver no Acre, Amazonas ou
/// Fernando de Noronha vê a hora certa do lugar onde está — sem depender de
/// nenhum cadastro de UF.
///
/// Existe porque os dois lados estavam errados e os erros se cancelavam na
/// tela, escondendo o problema:
///  - **Gravando**: `toIso8601String()` num `DateTime` local gera string SEM
///    fuso (`2026-09-17T08:00:00.000`). O Postgres, em UTC, lia isso como
///    08:00 UTC — 3h adiantado em relação ao que a pessoa digitou.
///  - **Lendo**: o valor volta com `+00:00`, o Dart monta um `DateTime` UTC e
///    o `DateFormat` imprime o relógio UTC, não o local.
///
/// Passar por aqui nas duas pontas é o que mantém o horário correto para o
/// worker de push, para comparações com `NOW()` e para quem está em outro fuso.
class DbTime {
  const DbTime._();

  /// Lê um `TIMESTAMPTZ` vindo do Supabase já na hora local do aparelho.
  ///
  /// Aceita o que o PostgREST devolve ([String]) ou um [DateTime] já pronto.
  /// Devolve `null` para nulo, tipo inesperado ou data inválida — nenhum
  /// `fromMap` deve explodir por causa de um campo de data estranho.
  static DateTime? tryParse(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Igual a [tryParse], mas com um valor de reserva para campos obrigatórios
  /// (`created_at` e afins, que na prática nunca vêm nulos).
  static DateTime parse(Object? raw, {DateTime? fallback}) =>
      tryParse(raw) ?? fallback ?? DateTime.now();

  /// Prepara um [DateTime] para gravar num `TIMESTAMPTZ`.
  ///
  /// Converte para UTC antes de serializar, então a string sai com o `Z` e o
  /// Postgres não precisa adivinhar o fuso.
  static String? toDb(DateTime? value) => value?.toUtc().toIso8601String();

  /// "Agora" pronto para gravar ou para comparar com uma coluna `TIMESTAMPTZ`
  /// (`.gte('starts_at', ...)`). Filtrar com a hora local compararia relógios
  /// de fusos diferentes.
  static String nowForDb() => DateTime.now().toUtc().toIso8601String();
}
