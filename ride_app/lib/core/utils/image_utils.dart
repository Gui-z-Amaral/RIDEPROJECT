import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;

/// Utilitários de imagem para upload no Supabase.
///
/// Toda imagem enviada ao Supabase passa por [compressToJpeg], que:
///  - converte para JPEG
///  - reduz a dimensão máxima (lado maior) para [maxDimension]
///  - baixa a qualidade em degraus até caber em [maxBytes] (360KB por padrão)
///
/// A decodificação/encode roda em um isolate (`compute`) para não travar a UI.
class ImageUtils {
  /// Tamanho máximo do arquivo final (360 KB).
  static const int maxBytes = 360 * 1024;

  /// Maior lado permitido em pixels — acima disso a imagem é redimensionada.
  static const int maxDimension = 1600;

  /// Comprime [input] para JPEG com no máximo [limitBytes].
  /// Se os bytes não forem uma imagem decodificável, retorna o original.
  static Future<Uint8List> compressToJpeg(
    Uint8List input, {
    int limitBytes = maxBytes,
    int dimension = maxDimension,
  }) {
    return compute(
      _compressInIsolate,
      _CompressArgs(input, limitBytes, dimension),
    );
  }

  /// Pré-popula o cache em disco (usado por cached_network_image) com os
  /// [bytes] já em mãos, evitando que o remetente precise rebaixar a imagem
  /// que ele mesmo acabou de enviar. O destinatário cacheia ao visualizar.
  static Future<void> cacheBytes(String url, Uint8List bytes) async {
    try {
      await DefaultCacheManager()
          .putFile(url, bytes, fileExtension: 'jpg');
    } catch (_) {
      // best-effort: falha de cache não pode quebrar o envio
    }
  }
}

class _CompressArgs {
  final Uint8List bytes;
  final int limitBytes;
  final int dimension;
  const _CompressArgs(this.bytes, this.limitBytes, this.dimension);
}

/// Executado em isolate. Sem acesso a I/O do app — só processamento puro.
Uint8List _compressInIsolate(_CompressArgs a) {
  final decoded = img.decodeImage(a.bytes);
  if (decoded == null) return a.bytes; // não é imagem que sabemos tratar

  // Aplica a orientação EXIF (fotos de câmera vêm rotacionadas).
  var image = img.bakeOrientation(decoded);

  // Redimensiona se o maior lado ultrapassar o limite.
  if (image.width > a.dimension || image.height > a.dimension) {
    if (image.width >= image.height) {
      image = img.copyResize(image, width: a.dimension);
    } else {
      image = img.copyResize(image, height: a.dimension);
    }
  }

  // 1ª tentativa: qualidade alta, baixando em degraus de 10 até 40.
  var quality = 85;
  var out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  while (out.lengthInBytes > a.limitBytes && quality > 40) {
    quality -= 10;
    out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  // Ainda grande? reduz a dimensão progressivamente (mantém qualidade 40).
  while (out.lengthInBytes > a.limitBytes && image.width > 400) {
    final newWidth = (image.width * 0.8).round();
    image = img.copyResize(image, width: newWidth);
    out = Uint8List.fromList(img.encodeJpg(image, quality: 40));
  }

  return out;
}
