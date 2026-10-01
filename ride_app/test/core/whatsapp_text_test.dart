import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/utils/whatsapp_text.dart';

/// O aviso real que um usuário colou no evento do MR. FOX.
const avisoReal = '''*ROLÊ  1° MR MOTOR SHOW BALNEÁRIO GAIVOTA*

*  Domingo, 20/09

* Saída: 13:30h
* Retorno: A Combinar

* Ponto de encontro: Posto Simon Passo de Torres(BR 101)''';

String plano(List<Trecho> t) => t.map((e) => e.texto).join();

void main() {
  group('WhatsAppText.trechos — formatação', () {
    test('negrito, itálico e riscado', () {
      expect(WhatsAppText.trechos('*oi*').single.negrito, isTrue);
      expect(WhatsAppText.trechos('_oi_').single.italico, isTrue);
      expect(WhatsAppText.trechos('~oi~').single.riscado, isTrue);
    });

    test('o asterisco some da tela', () {
      expect(plano(WhatsAppText.trechos('um *rolê* bom')), 'um rolê bom');
    });

    test('aninhado soma os estilos', () {
      final t = WhatsAppText.trechos('*_forte_*').single;
      expect(t.negrito && t.italico, isTrue);
      expect(t.texto, 'forte');
    });

    test('marcador colado em letra não formata', () {
      expect(plano(WhatsAppText.trechos('2*3*4')), '2*3*4');
      expect(plano(WhatsAppText.trechos('arquivo_de_teste')), 'arquivo_de_teste');
    });

    test('espaço do lado de dentro não formata', () {
      expect(WhatsAppText.trechos('* nada *').any((t) => t.negrito), isFalse);
    });

    test('linha começando com "* " ou "- " vira item de lista', () {
      expect(plano(WhatsAppText.trechos('* Saída\n- Retorno')), '• Saída\n• Retorno');
    });

    test('o aviso real: título em negrito, itens como lista, sem asterisco', () {
      final t = WhatsAppText.trechos(avisoReal);
      expect(t.first.negrito, isTrue);
      expect(t.first.texto, 'ROLÊ  1° MR MOTOR SHOW BALNEÁRIO GAIVOTA');
      expect(plano(t).contains('*'), isFalse);
      expect(plano(t), contains('• Saída: 13:30h'));
    });

    test('texto sem marcador passa igual', () {
      expect(plano(WhatsAppText.trechos('Encontro de motos')), 'Encontro de motos');
    });
  });

  group('WhatsAppText.horarioDeSaida', () {
    test('acha no aviso real', () {
      expect(WhatsAppText.horarioDeSaida(avisoReal), (hora: 13, minuto: 30));
    });

    test('formatos comuns', () {
      expect(WhatsAppText.horarioDeSaida('saída 7h30'), (hora: 7, minuto: 30));
      expect(WhatsAppText.horarioDeSaida('Saida às 14h'), (hora: 14, minuto: 0));
      expect(WhatsAppText.horarioDeSaida('SAÍDA: 06:00'), (hora: 6, minuto: 0));
    });

    test('data na mesma linha não vira horário', () {
      expect(WhatsAppText.horarioDeSaida('Saída dia 20/09 às 13:30'),
          (hora: 13, minuto: 30));
      expect(WhatsAppText.horarioDeSaida('Saída dia 20/09'), isNull);
    });

    test('horário impossível é ignorado', () {
      expect(WhatsAppText.horarioDeSaida('saída 25:00'), isNull);
    });

    test('sem a palavra "saída" não sugere nada', () {
      expect(WhatsAppText.horarioDeSaida('Início 13:30'), isNull);
    });
  });

  group('WhatsAppText.pontoDeEncontro', () {
    test('acha no aviso real', () {
      expect(WhatsAppText.pontoDeEncontro(avisoReal),
          'Posto Simon Passo de Torres(BR 101)');
    });

    test('variações que motoclube usa', () {
      expect(WhatsAppText.pontoDeEncontro('Concentração: Praça Central.'),
          'Praça Central');
      expect(WhatsAppText.pontoDeEncontro('local de saída - Posto Ipiranga'),
          'Posto Ipiranga');
    });

    test('sem o rótulo não sugere nada', () {
      expect(WhatsAppText.pontoDeEncontro('Vamos no Posto Simon'), isNull);
    });
  });
}
