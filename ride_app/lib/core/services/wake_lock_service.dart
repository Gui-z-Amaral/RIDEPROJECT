import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// **Modo Rolê** — mantém a tela ligada enquanto um rolê/viagem está sendo
/// gravado.
///
/// Por que existe: na **web** o navegador não acompanha a localização com a
/// tela apagada. Se a tela dorme, a gravação do trajeto simplesmente para. O
/// wake lock segura a tela acesa durante a gravação (o `wakelock_plus` usa a
/// Screen Wake Lock API e, onde ela não existe — Safari antigo —, cai num
/// fallback de vídeo invisível).
///
/// No **nativo** isso não é necessário: o app já grava em segundo plano. Por
/// isso aqui é no-op de propósito — não mudamos o comportamento atual do
/// celular (a tela continua apagando normalmente).
///
/// É o degrau 4 da escada de paridade do CLAUDE.md: mesmo objetivo (não perder
/// a gravação), mecanismo diferente por plataforma.
class WakeLockService {
  WakeLockService._();

  static bool _active = false;

  /// `true` quando a tela está sendo mantida ligada por causa da gravação.
  ///
  /// A UI usa isto para avisar sobre o consumo de bateria. Repare que é uma
  /// pergunta sobre **capacidade** ("a tela está sendo segurada?"), não sobre
  /// plataforma — por isso o widget não precisa saber o que é web.
  static bool get isActive => _active;

  /// A plataforma precisa segurar a tela durante a gravação? Só a web.
  static bool get isSupported => kIsWeb;

  /// Liga o wake lock. Idempotente: pode ser chamado de novo quando o app volta
  /// do segundo plano (o navegador solta o lock ao esconder a aba).
  ///
  /// Tolerante a falha — se o navegador negar, a gravação continua; o usuário
  /// só precisa manter a tela acesa por conta própria.
  static Future<void> enable() async {
    if (!isSupported) return;
    try {
      await WakelockPlus.enable();
      _active = true;
    } catch (_) {
      _active = false;
    }
  }

  /// Desliga o wake lock — a tela volta a apagar normalmente.
  static Future<void> disable() async {
    if (!isSupported) return;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    _active = false;
  }
}
