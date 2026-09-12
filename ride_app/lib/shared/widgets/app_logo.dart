import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Logo do RideApp (a marca "R"). Recolore a imagem para a cor da marca, que
/// adapta ao modo claro/escuro (navy no claro, azul mais claro no escuro) —
/// mantendo contraste em qualquer fundo.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  const AppLogo({super.key, this.size = 96, this.color});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color ?? AppColors.navy, BlendMode.srcIn),
      child: Image.asset(
        'assets/logo/logo_sem_fundo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
