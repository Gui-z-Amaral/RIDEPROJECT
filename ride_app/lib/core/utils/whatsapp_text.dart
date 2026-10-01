/// Texto que chega colado do WhatsApp.
///
/// Motociclista organiza rolê no grupo do WhatsApp; quando vai para o app, cola
/// o mesmo aviso. Foi o que aconteceu no evento do MR. FOX:
///
///     *ROLÊ 1° MR MOTOR SHOW BALNEÁRIO GAIVOTA*
///     * Saída: 13:30h
///     * Ponto de encontro: Posto Simon Passo de Torres (BR 101)
///
/// Aqui ficam as duas leituras desse texto: a formatação (para a tela não
/// mostrar asterisco cru) e a saída/ponto de encontro (para sugerir os campos
/// próprios em vez de a informação ficar solta na descrição).
class WhatsAppText {
  const WhatsAppText._();

  // ── Formatação ────────────────────────────────────────────────────────────

  /// Marcador do WhatsApp colado na palavra: `*negrito*`, `_itálico_`,
  /// `~riscado~`. Não vale se houver letra/número colado do lado de fora
  /// (`2*3*4` não é negrito) nem espaço do lado de dentro (`* item *`).
  static final _marcador = RegExp(
    r'(?<![\p{L}\p{N}])([*_~])(?!\s)([^\n]+?)(?<!\s)\1(?![\p{L}\p{N}])',
    unicode: true,
  );

  /// Lista do WhatsApp: linha começando com "* " ou "- ".
  static final _itemDeLista = RegExp(r'^[ \t]*[*-][ \t]+', multiLine: true);

  /// Quebra [texto] em trechos com o estilo de cada um. Um nível de aninhamento
  /// (`*_negrito e itálico_*`) é suportado, como no WhatsApp.
  static List<Trecho> trechos(String texto) =>
      _partir(texto.replaceAll(_itemDeLista, '• '), const Trecho(''));

  static List<Trecho> _partir(String texto, Trecho base) {
    final out = <Trecho>[];
    var i = 0;
    for (final m in _marcador.allMatches(texto)) {
      if (m.start > i) out.add(base.com(texto.substring(i, m.start)));
      final estilo = switch (m.group(1)) {
        '*' => base.com('', negrito: true),
        '_' => base.com('', italico: true),
        _ => base.com('', riscado: true),
      };
      out.addAll(_partir(m.group(2)!, estilo));
      i = m.end;
    }
    if (i < texto.length) out.add(base.com(texto.substring(i)));
    return out;
  }

  // ── Saída e ponto de encontro ─────────────────────────────────────────────

  /// Horário na mesma linha de "saída": `13:30`, `13h`, `13h30`, `13 h`.
  /// Exige `:` ou `h` depois do número — senão "saída dia 20/09" viraria 20h.
  static final _saida = RegExp(
    r'sa[ií]da[^\n]*?(?<!\d)(\d{1,2})\s*(?::|h)\s*(\d{2})?(?!\d)',
    caseSensitive: false,
    unicode: true,
  );

  static final _ponto = RegExp(
    r'(?:ponto\s+de\s+encontro|local\s+de\s+(?:encontro|sa[ií]da)|concentra[çc][ãa]o)'
    r'\s*[:\-–]\s*([^\n]+)',
    caseSensitive: false,
    unicode: true,
  );

  /// Procura, no texto colado, o horário de saída e o ponto de encontro.
  /// Devolve `null` no que não achar. É só SUGESTÃO: quem confirma é a pessoa.
  static ({int hora, int minuto})? horarioDeSaida(String texto) {
    final m = _saida.firstMatch(_semMarcadores(texto));
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    if (h > 23 || min > 59) return null;
    return (hora: h, minuto: min);
  }

  static String? pontoDeEncontro(String texto) {
    final m = _ponto.firstMatch(_semMarcadores(texto));
    if (m == null) return null;
    var p = m.group(1)!.trim().replaceAll(RegExp(r'[.;,]+$'), '').trim();
    if (p.length < 3) return null;
    if (p.length > 120) p = p.substring(0, 120).trim();
    return p;
  }

  static String _semMarcadores(String t) => t.replaceAll(RegExp(r'[*_~]'), '');
}

/// Um pedaço de texto com o estilo que o WhatsApp daria a ele.
class Trecho {
  final String texto;
  final bool negrito;
  final bool italico;
  final bool riscado;
  const Trecho(this.texto,
      {this.negrito = false, this.italico = false, this.riscado = false});

  /// Mesmo estilo, somando o que vier — é assim que o aninhamento acumula.
  Trecho com(String texto,
          {bool negrito = false, bool italico = false, bool riscado = false}) =>
      Trecho(texto,
          negrito: this.negrito || negrito,
          italico: this.italico || italico,
          riscado: this.riscado || riscado);

  @override
  String toString() =>
      '${negrito ? 'N' : ''}${italico ? 'I' : ''}${riscado ? 'R' : ''}[$texto]';
}
