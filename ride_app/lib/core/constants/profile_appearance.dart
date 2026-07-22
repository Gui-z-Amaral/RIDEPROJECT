import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Uma moldura de avatar: anel colorido/gradiente ao redor da foto.
/// Desenhada no app (sem asset de imagem) — leve e fácil de estender.
/// [isPremium] já vem pronto para quando a monetização for ativada: hoje
/// nenhuma moldura é bloqueada, mas o catálogo já carrega a informação.
class AvatarFrameStyle {
  final String id;
  final String label;
  final List<Color> colors; // 1 cor = anel sólido; 2+ = gradiente
  final bool isPremium;
  const AvatarFrameStyle({
    required this.id,
    required this.label,
    required this.colors,
    this.isPremium = false,
  });
}

const List<AvatarFrameStyle> avatarFrames = [
  AvatarFrameStyle(id: 'none', label: 'Sem moldura', colors: []),
  AvatarFrameStyle(
      id: 'teal_glow', label: 'Ciano', colors: [AppColors.teal]),
  AvatarFrameStyle(
      id: 'gold', label: 'Dourado', colors: [Color(0xFFD4AF37)]),
  AvatarFrameStyle(
      id: 'purple_neon', label: 'Roxo Neon', colors: [Color(0xFFB794F6)]),
  AvatarFrameStyle(
    id: 'sunset',
    label: 'Pôr do Sol',
    colors: [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
  ),
  AvatarFrameStyle(
    id: 'ocean',
    label: 'Oceano',
    colors: [AppColors.navy, AppColors.teal],
  ),
];

AvatarFrameStyle avatarFrameById(String? id) => avatarFrames.firstWhere(
      (f) => f.id == id,
      orElse: () => avatarFrames.first, // 'none'
    );

/// Uma cor selecionável da paleta de personalização (fundo ou texto).
class ProfilePaletteColor {
  final String id;
  final String label;
  final Color color;
  const ProfilePaletteColor(
      {required this.id, required this.label, required this.color});
}

/// Paleta única usada tanto para "cor de fundo" quanto para "cor de texto",
/// conforme pedido: Preto (Black Piano), Ciano, Verde Claro, Roxo Claro, Branco.
const List<ProfilePaletteColor> profileColorPalette = [
  ProfilePaletteColor(
      id: 'black', label: 'Preto', color: Color(0xFF0A0A0A)),
  ProfilePaletteColor(
      id: 'cyan', label: 'Ciano', color: Color(0xFF22D3EE)),
  ProfilePaletteColor(
      id: 'light_green', label: 'Verde Claro', color: Color(0xFF86EFAC)),
  ProfilePaletteColor(
      id: 'light_purple', label: 'Roxo Claro', color: Color(0xFFC4B5FD)),
  ProfilePaletteColor(id: 'white', label: 'Branco', color: Color(0xFFFFFFFF)),
];

/// Resolve o id da paleta para a Color; `null`/id desconhecido → [fallback]
/// (o padrão do app para aquele campo).
Color resolveProfileColor(String? id, Color fallback) {
  if (id == null) return fallback;
  for (final c in profileColorPalette) {
    if (c.id == id) return c.color;
  }
  return fallback;
}

/// `true` se [color] é clara o bastante para precisar de texto escuro sobre
/// ela (usado só para decidir contraste de elementos auxiliares, não bloqueia
/// escolhas do usuário).
bool isLightColor(Color color) => color.computeLuminance() > 0.5;
