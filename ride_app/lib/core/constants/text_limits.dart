/// Limites de tamanho dos campos de texto.
///
/// **Quem manda é o banco** (`regra_do_campo`, migration 045): um trigger
/// recusa o que passar daqui mesmo que o app deixe. Estes números existem só
/// para o campo parar de aceitar letra na hora certa e a mensagem de erro
/// dizer o limite — se mudar lá, mudar aqui.
///
/// As chaves são as mesmas que o banco usa no erro
/// `texto_invalido:<motivo>:<campo>`.
class TextLimits {
  const TextLimits._();

  static const nome = 60;
  static const username = 30;
  static const bio = 500;
  static const cidade = 80;
  static const moto = 60;
  static const estilo = 40;
  static const negocio = 80;
  static const negocioDesc = 1000;
  static const clube = 60;
  static const clubeDesc = 1000;
  static const evento = 100;
  static const eventoDesc = 3000;
  static const local = 120;
  static const viagem = 100;
  static const viagemDesc = 3000;
  static const role = 100;

  /// Texto digitado no chat. No banco o limite é do envelope cifrado (40 000),
  /// que ocupa bem mais que o texto; 2 000 caracteres cabem com folga.
  static const mensagem = 2000;

  /// (mínimo, máximo) por campo, na mesma forma do banco.
  static const regras = <String, (int, int)>{
    'nome': (2, nome),
    'username': (3, username),
    'bio': (0, bio),
    'cidade': (0, cidade),
    'moto': (0, moto),
    'estilo': (0, estilo),
    'negocio': (0, negocio),
    'negocio_desc': (0, negocioDesc),
    'clube': (3, clube),
    'clube_desc': (0, clubeDesc),
    'evento': (3, evento),
    'evento_desc': (0, eventoDesc),
    'local': (0, local),
    'viagem': (3, viagem),
    'viagem_desc': (0, viagemDesc),
    'role': (3, role),
    'mensagem': (0, mensagem),
  };
}
