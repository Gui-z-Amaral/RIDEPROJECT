import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_utils.dart';

/// Helpers de upload de imagem para o Storage do Supabase.
class StorageUtils {
  /// Sobe uma imagem (comprimida ≤360KB JPEG) para [bucket] com nome ÚNICO
  /// (`<uid>/<prefix>_<timestamp>.jpg`) e retorna a URL pública.
  ///
  /// Usa INSERT (nome novo a cada vez), NÃO upsert de nome fixo: no Storage
  /// self-hosted, o upsert de um arquivo que já existe bate no RLS e falha com
  /// 403. Nome único é sempre um INSERT novo, que funciona. Se [previousUrl]
  /// for informado, o arquivo anterior é apagado em best-effort para não
  /// acumular órfãos.
  static Future<String> uploadImageUnique({
    required String bucket,
    required String uid,
    required String prefix,
    required Uint8List bytes,
    String? previousUrl,
  }) async {
    final db = Supabase.instance.client;
    final jpeg = await ImageUtils.compressToJpeg(bytes);
    final path = '$uid/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await db.storage.from(bucket).uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    if (previousUrl != null) {
      final old = pathFromPublicUrl(previousUrl, bucket);
      if (old != null) {
        try {
          await db.storage.from(bucket).remove([old]);
        } catch (_) {
          // best-effort: falha ao limpar o antigo não pode quebrar o upload
        }
      }
    }
    return db.storage.from(bucket).getPublicUrl(path);
  }

  /// Extrai o caminho de storage (`<uid>/arquivo.jpg`) de uma URL pública do
  /// Supabase para o [bucket] informado. Retorna `null` se a URL não pertencer
  /// a esse bucket (ex.: veio de outro lugar ou está vazia). Ignora a query
  /// (`?t=...`) usada como cache-buster.
  @visibleForTesting
  static String? pathFromPublicUrl(String url, String bucket) {
    final marker = '/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    var path = url.substring(i + marker.length);
    final q = path.indexOf('?');
    if (q >= 0) path = path.substring(0, q);
    return path.isEmpty ? null : path;
  }
}
