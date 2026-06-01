// Testes da compressão de imagem usada antes de todo upload no Supabase.
// Exercita a lógica síncrona (compressJpegSync) — a versão de produção
// (compressToJpeg) só embrulha isto num isolate via compute().
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ride_app/core/utils/image_utils.dart';

/// PNG sólido WxH — comprime para pouquíssimos bytes (testa caminho feliz).
Uint8List _solidPng(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(30, 48, 88));
  return Uint8List.fromList(img.encodePng(image));
}

/// PNG em gradiente WxH — comprime como uma foto real (não é incompressível
/// como ruído puro), exercitando os laços de redução de qualidade/dimensão
/// e ainda conseguindo cair abaixo de um limite apertado.
Uint8List _gradientPng(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final r = (x * 255 ~/ w);
      final g = (y * 255 ~/ h);
      final b = ((x + y) * 255 ~/ (w + h));
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

bool _isJpeg(Uint8List bytes) =>
    bytes.length > 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

void main() {
  group('ImageUtils.compressJpegSync', () {
    test('converte PNG para JPEG válido e decodificável', () {
      final png = _solidPng(200, 200);
      expect(_isJpeg(png), isFalse, reason: 'entrada é PNG');

      final out = ImageUtils.compressJpegSync(png);

      expect(_isJpeg(out), isTrue, reason: 'saída deve ser JPEG');
      expect(img.decodeImage(out), isNotNull, reason: 'JPEG decodificável');
    });

    test('redimensiona quando o maior lado passa de maxDimension', () {
      // 2000x1000 → maior lado deve cair para 1600.
      final png = _solidPng(2000, 1000);
      final out = ImageUtils.compressJpegSync(png);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, lessThanOrEqualTo(ImageUtils.maxDimension));
      expect(decoded.height, lessThanOrEqualTo(ImageUtils.maxDimension));
      // Mantém proporção: o maior lado vira exatamente 1600.
      expect(decoded.width, ImageUtils.maxDimension);
    });

    test('imagem pequena não é ampliada', () {
      final png = _solidPng(300, 150);
      final decoded = img.decodeImage(ImageUtils.compressJpegSync(png))!;
      expect(decoded.width, 300);
      expect(decoded.height, 150);
    });

    test('respeita um limite de bytes pequeno em imagem grande', () {
      // Imagem grande + limite apertado força quality-down + downscale.
      final png = _gradientPng(1500, 1500);
      const limit = 60 * 1024; // 60KB
      final out = ImageUtils.compressJpegSync(png, limitBytes: limit);
      expect(_isJpeg(out), isTrue);
      expect(out.lengthInBytes, lessThanOrEqualTo(limit));
    });

    test('limite padrão de 360KB é respeitado', () {
      final png = _gradientPng(1800, 1800);
      final out = ImageUtils.compressJpegSync(png);
      expect(out.lengthInBytes, lessThanOrEqualTo(ImageUtils.maxBytes));
    });

    test('bytes que não são imagem retornam o original inalterado', () {
      final notAnImage = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final out = ImageUtils.compressJpegSync(notAnImage);
      expect(out, equals(notAnImage));
    });

    test('maxBytes e maxDimension têm os valores esperados', () {
      expect(ImageUtils.maxBytes, 360 * 1024);
      expect(ImageUtils.maxDimension, 1600);
    });
  });
}
