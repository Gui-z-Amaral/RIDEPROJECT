import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Em telas largas (navegador no desktop, tablet em paisagem) renderiza o app
/// numa **coluna central** com largura máxima, em vez de esticar os
/// componentes por 1900px.
///
/// O critério é **largura, nunca plataforma** (regra do CLAUDE.md): uma janela
/// de navegador estreita se comporta como celular, e um tablet nativo ganha o
/// mesmo tratamento de graça.
///
/// Aplicado uma única vez no `MaterialApp.builder`, então vale para todas as
/// telas — inclusive as empurradas por cima do shell.
class ResponsiveShell extends StatelessWidget {
  final Widget child;

  /// Acima disso, o app é centralizado. Abaixo, ocupa tudo (celular).
  static const double breakpoint = 720;

  /// Fração da janela ocupada pela coluna. Como é **proporcional**, a coluna
  /// acompanha o redimensionamento da janela em vez de ficar numa largura fixa.
  static const double widthFactor = 0.92;

  /// Teto para monitores ultrawide — sem ele, uma linha de texto atravessaria
  /// 2500px e ficaria impossível de ler.
  static const double maxContentWidth = 1400;

  /// Largura da coluna para uma janela de [available] pixels.
  ///
  /// Nunca passa da janela (senão estoura) nem do teto de leitura.
  static double columnWidth(double available) {
    final fluid = available * widthFactor;
    return fluid < maxContentWidth ? fluid : maxContentWidth;
  }

  const ResponsiveShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= breakpoint) return child;

        final width = columnWidth(constraints.maxWidth);
        return ColoredBox(
          color: AppColors.surfaceVariant,
          child: Center(
            child: ClipRect(
              child: SizedBox(
                width: width,
                // Sem isto, quem lê MediaQuery.size.width continuaria vendo a
                // largura da janela inteira e calcularia layout errado dentro
                // da coluna.
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(width, constraints.maxHeight),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
