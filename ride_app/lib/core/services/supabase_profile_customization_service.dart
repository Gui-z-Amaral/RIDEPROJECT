import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_customization.dart';
import '../utils/image_utils.dart';

class SupabaseProfileCustomizationService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  /// Busca a personalização de [userId]. Retorna vazia (padrão) se a linha
  /// não existir — usuário nunca customizou nada.
  static Future<ProfileCustomization> get(String userId) async {
    final row = await _db
        .from('profile_customizations')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return ProfileCustomization.empty(userId);
    return ProfileCustomization.fromMap(row);
  }

  /// Salva (upsert) a personalização do usuário logado.
  static Future<void> save(ProfileCustomization c) async {
    await _db.from('profile_customizations').upsert({
      ...c.toMap(),
      'user_id': _uid,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Restaura tudo para o padrão (remove a linha de customização).
  static Future<void> reset() async {
    await _db.from('profile_customizations').delete().eq('user_id', _uid);
  }

  /// Upload do banner pessoal (bucket 'avatars', comprimido ≤360KB).
  /// Nome fixo por usuário com cache-buster, mesmo padrão do avatar.
  static Future<String> uploadBanner(Uint8List bytes) async {
    final jpeg = await ImageUtils.compressToJpeg(bytes);
    final path = '$_uid/profile_banner.jpg';
    await _db.storage.from('avatars').uploadBinary(
          path,
          jpeg,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final url = _db.storage.from('avatars').getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }
}
