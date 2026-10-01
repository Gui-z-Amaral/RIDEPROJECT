import '../constants/text_limits.dart';

/// Traduz para português os erros de regra de texto que o banco devolve.
///
/// Desde a migration 045 um trigger recusa texto fora da regra com a mensagem
/// `texto_invalido:<motivo>:<campo>` — o mesmo par que a RPC `checar_texto`
/// devolve para o app avisar antes de salvar. Aqui os dois viram uma frase só.
class DbErrors {
  const DbErrors._();

  static final _padrao = RegExp(r'texto_invalido:([a-z]+):([a-z_]+)');

  static const _campos = <String, String>{
    'nome': 'O nome',
    'username': 'O @',
    'bio': 'A bio',
    'cidade': 'A cidade',
    'moto': 'O modelo da moto',
    'estilo': 'O estilo de viagem',
    'negocio': 'O nome do negócio',
    'negocio_desc': 'A descrição do negócio',
    'clube': 'O nome do motoclube',
    'clube_desc': 'A descrição do motoclube',
    'evento': 'O nome do evento',
    'evento_desc': 'A descrição do evento',
    'local': 'O nome do local',
    'viagem': 'O título da viagem',
    'viagem_desc': 'A descrição da viagem',
    'role': 'O título do rolê',
    'mensagem': 'A mensagem',
  };

  /// Frase para um [motivo] (vazio | curto | longo | formato | improprio) no
  /// [campo]. Motivo desconhecido cai numa frase genérica, nunca em código.
  static String textoMensagem(String motivo, String campo) {
    final nome = _campos[campo] ?? 'O texto';
    final regra = TextLimits.regras[campo];
    switch (motivo) {
      case 'vazio':
        return '$nome não pode ficar em branco.';
      case 'curto':
        return regra == null
            ? '$nome está curto demais.'
            : '$nome precisa ter pelo menos ${regra.$1} caracteres.';
      case 'longo':
        return regra == null
            ? '$nome está longo demais.'
            : '$nome pode ter no máximo ${regra.$2} caracteres.';
      case 'formato':
        return '$nome só pode ter letras minúsculas, números e _.';
      case 'improprio':
        // Não repete a palavra: a pessoa sabe qual escreveu, e o app não
        // precisa exibir palavrão na tela.
        return '$nome tem uma palavra que não é permitida no RideApp.';
      default:
        return '$nome não foi aceito. Revise e tente de novo.';
    }
  }

  /// Frase para um erro de regra de texto em [erro], ou `null` se não for um.
  static String? textoInvalido(Object erro) {
    final m = _padrao.firstMatch(erro.toString());
    if (m == null) return null;
    return textoMensagem(m.group(1)!, m.group(2)!);
  }

  /// Mensagem final para uma falha ao salvar: a regra de texto quando for o
  /// caso, senão [fallback]. Nunca devolve o texto cru do erro — ele traz nome
  /// de tabela e coluna.
  static String mensagem(Object erro, {required String fallback}) =>
      textoInvalido(erro) ?? fallback;
}
