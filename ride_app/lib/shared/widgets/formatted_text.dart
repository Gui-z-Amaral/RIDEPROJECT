import 'package:flutter/material.dart';
import '../../core/utils/whatsapp_text.dart';

/// Texto com a formatação do WhatsApp (`*negrito*`, `_itálico_`, `~riscado~`,
/// listas com "* " ou "- ").
///
/// Descrição de evento e de motoclube costuma ser o aviso do grupo colado no
/// app; sem isto a tela mostrava os asteriscos crus.
class FormattedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const FormattedText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final t in WhatsAppText.trechos(text))
            TextSpan(
              text: t.texto,
              style: TextStyle(
                fontWeight: t.negrito ? FontWeight.w700 : null,
                fontStyle: t.italico ? FontStyle.italic : null,
                decoration: t.riscado ? TextDecoration.lineThrough : null,
              ),
            ),
        ],
      ),
    );
  }
}
