import 'package:supabase_flutter/supabase_flutter.dart';

/// Um rider próximo (retornado pela RPC nearby_riders). Traz só dados
/// públicos + a distância — nunca a coordenada da pessoa.
class NearbyRider {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? motoModel;
  final String? tripStyle;
  final double distanceKm;

  const NearbyRider({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.motoModel,
    this.tripStyle,
    required this.distanceKm,
  });

  factory NearbyRider.fromMap(Map<String, dynamic> map) => NearbyRider(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        username: map['username'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String?,
        motoModel: map['moto_model'] as String?,
        tripStyle: map['trip_style'] as String?,
        distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
      );

  /// Distância formatada (ex: "820 m", "3,2 km").
  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}

/// Descoberta de riders próximos + localização + privacidade.
class SupabaseRiderService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  /// Atualiza a localização do usuário (usada só quando ele é "descoberto").
  static Future<void> updateMyLocation(double lat, double lng) async {
    await _db.from('rider_locations').upsert({
      'user_id': _uid,
      'lat': lat,
      'lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Remove a localização (ao desligar a descoberta).
  static Future<void> clearMyLocation() async {
    await _db.from('rider_locations').delete().eq('user_id', _uid);
  }

  /// Lista os riders próximos, do mais perto pro mais longe.
  static Future<List<NearbyRider>> getNearby(double lat, double lng) async {
    final rows = await _db.rpc('nearby_riders', params: {
      'p_lat': lat,
      'p_lng': lng,
    });
    return (rows as List)
        .map((r) => NearbyRider.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Atualiza as flags de privacidade do perfil.
  static Future<void> setPrivacy({bool? discoverable, bool? isPrivate}) async {
    final updates = <String, dynamic>{};
    if (discoverable != null) updates['discoverable'] = discoverable;
    if (isPrivate != null) updates['is_private'] = isPrivate;
    if (updates.isEmpty) return;
    await _db.from('profiles').update(updates).eq('id', _uid);
  }
}
