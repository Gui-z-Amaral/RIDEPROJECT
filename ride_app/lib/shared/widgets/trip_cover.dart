import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';

import '../../core/models/location_model.dart';
import '../../core/models/trip_model.dart';
import '../../core/services/maps_proxy.dart';
import '../../core/services/places_service.dart';

/// Foto de capa de uma viagem (o banner do destino, vindo do Google Places).
///
/// Vive aqui — e não dentro de uma tela — porque a capa aparece em mais de um
/// lugar (card da home, cabeçalho do detalhe). Quando a lógica morava só no
/// detalhe, a home mostrava o gradiente mesmo havendo foto salva.
///
/// Ordem de resolução:
///  1. a capa salva na viagem (`trip.coverImage`);
///  2. se não houver — ou se for uma URL antiga, direto do Google, que quebra
///     na web por CORS — busca a foto do destino pelo nome/coordenada;
///  3. não achando nada, mostra [fallback].
class TripCover extends StatefulWidget {
  /// Viagem cuja capa será exibida.
  final TripModel trip;

  /// Exibido enquanto não há foto (e quando não existe nenhuma).
  final Widget fallback;

  /// Escurece o rodapé da foto, para texto sobreposto ficar legível.
  /// Só vale quando há foto — o [fallback] nunca é escurecido.
  final bool scrim;

  const TripCover({
    super.key,
    required this.trip,
    required this.fallback,
    this.scrim = false,
  });

  /// Capa salva que dá pra usar, ou `null` se não houver.
  ///
  /// URLs salvas antes do proxy `gmaps` apontam direto pro Google e quebram na
  /// web (o CanvasKit lê o pixel da imagem, o que exige CORS) — essas são
  /// descartadas para que a foto seja re-resolvida pelo proxy.
  @visibleForTesting
  static String? usableSavedCover(String? saved) {
    if (saved == null || saved.isEmpty) return null;
    if (MapsProxy.isLegacyGooglePhotoUrl(saved)) return null;
    return saved;
  }

  /// Texto usado para procurar a foto do destino: o nome do lugar quando
  /// existe, senão o endereço. Vazio significa "não dá pra procurar".
  @visibleForTesting
  static String coverQuery(LocationModel destination) {
    final label = destination.label;
    if (label != null && label.trim().isNotEmpty) return label.trim();
    return (destination.address ?? '').trim();
  }

  /// Fotos já resolvidas nesta sessão, por id de viagem. Sem isso a home e o
  /// detalhe fariam a MESMA busca no Places para a mesma viagem — chamada paga,
  /// e a capa piscaria a cada volta pra tela.
  static final Map<String, String> _resolved = {};

  @override
  State<TripCover> createState() => _TripCoverState();
}

class _TripCoverState extends State<TripCover> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(TripCover old) {
    super.didUpdateWidget(old);
    if (old.trip.id != widget.trip.id ||
        old.trip.coverImage != widget.trip.coverImage) {
      _url = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final trip = widget.trip;

    final saved = TripCover.usableSavedCover(trip.coverImage);
    if (saved != null) {
      setState(() => _url = saved);
      return;
    }

    final cached = TripCover._resolved[trip.id];
    if (cached != null) {
      setState(() => _url = cached);
      return;
    }

    final query = TripCover.coverQuery(trip.destination);
    if (query.isEmpty) return;

    try {
      final results = await PlacesService.searchPlaces(
        query: query,
        lat: trip.destination.lat,
        lng: trip.destination.lng,
        limit: 1,
      );
      final url = results.isNotEmpty ? results.first.photoUrl : '';
      if (url.isEmpty) return;
      TripCover._resolved[trip.id] = url;
      // A tela pode ter saído enquanto a busca ia e voltava.
      if (mounted) setState(() => _url = url);
    } catch (_) {
      // Sem foto a viagem continua utilizável — fica o fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null || url.isEmpty) return widget.fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          // Enquanto carrega mostra o fallback, em vez de um buraco cinza.
          placeholder: (_, __) => widget.fallback,
          errorWidget: (_, __, ___) => widget.fallback,
        ),
        if (widget.scrim)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
                stops: [0.5, 1.0],
              ),
            ),
          ),
      ],
    );
  }
}
