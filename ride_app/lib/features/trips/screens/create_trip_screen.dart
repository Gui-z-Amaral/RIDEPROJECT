import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/geocoding_service.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/app_avatar.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  int _step = 0; // 0=destino, 1=tempo+pessoas, 2=paradas+rota, 3=resumo

  // Step 0 – Destino
  final _ruaCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  String _destinoLabel = '';
  double? _destLat;
  double? _destLng;
  bool _lookingUpCep = false;
  PlaceInfo? _destInfo; // info extra do destino (foto, horários, etc.)

  // Ponto de partida/encontro (opcional — padrão = localização atual)
  LocationModel? _departurePoint;

  // Localização atual (origem da viagem — default)
  double? _originLat;
  double? _originLng;

  // Step 1 – Tempo + Pessoas
  DateTime? _departureDate;
  final _peoplSearchCtrl = TextEditingController();

  // Step 2 – Paradas
  final List<String> _stopNames = [];

  @override
  void initState() {
    super.initState();
    context.read<TripViewModel>().resetForm();
    Future.microtask(
        () => context.read<SocialViewModel>().loadFriends());
    _fetchOriginLocation();
  }

  Future<void> _fetchOriginLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) setState(() {
        _originLat = pos.latitude;
        _originLng = pos.longitude;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ruaCtrl.dispose();
    _numCtrl.dispose();
    _bairroCtrl.dispose();
    _cepCtrl.dispose();
    _peoplSearchCtrl.dispose();
    super.dispose();
  }

  // ── Selecionar ponto de partida/encontro (opcional) ─────────
  Future<void> _pickDepartureFromMap() async {
    final result = await context.push<dynamic>('/map/select', extra: {
      'title': 'Ponto de partida / encontro',
      'onSelected': null,
    });
    if (result == null || !mounted) return;
    LocationModel? loc;
    if (result is Map) loc = result['location'] as LocationModel?;
    else if (result is LocationModel) loc = result;
    if (loc != null) setState(() => _departurePoint = loc);
  }

  // ── CEP lookup via ViaCEP (grátis) ──────────────────────────
  Future<void> _lookupCep(String cep) async {
    final clean = cep.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 8) return;
    if (!mounted) return;
    setState(() => _lookingUpCep = true);
    try {
      final res = await http
          .get(Uri.parse('https://viacep.com.br/ws/$clean/json/'))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['erro'] != true) {
          setState(() {
            _ruaCtrl.text = data['logradouro'] ?? _ruaCtrl.text;
            _bairroCtrl.text = data['bairro'] ?? _bairroCtrl.text;
            final city = data['localidade'] ?? '';
            final uf = data['uf'] ?? '';
            if (_destinoLabel.isEmpty && city.isNotEmpty) {
              _destinoLabel = '$city, $uf - BRASIL';
            }
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _lookingUpCep = false);
  }

  // ── Navigation ───────────────────────────────────────────────
  void _back() {
    if (_step > 0) setState(() => _step--);
    else context.pop();
  }

  void _advance() {
    if (_step < 3) {
      setState(() => _step++);
    }
  }

  // ── Save ─────────────────────────────────────────────────────
  Future<void> _confirm() async {
    final vm = context.read<TripViewModel>();

    final address =
        '${_ruaCtrl.text.trim()}, ${_numCtrl.text.trim()}, ${_bairroCtrl.text.trim()}, CEP ${_cepCtrl.text.trim()}';

    vm.setTitle(_destinoLabel.isNotEmpty ? _destinoLabel : 'Minha Viagem');
    // Usa o ponto de partida definido pelo usuário, ou a localização atual
    vm.setOrigin(_departurePoint ?? LocationModel(
      lat: _originLat ?? -27.5954,
      lng: _originLng ?? -48.5480,
      label: 'Localização atual',
    ));
    vm.setDestination(LocationModel(
      lat: _destLat ?? -27.5954,
      lng: _destLng ?? -48.5480,
      address: address,
      label: _destinoLabel,
    ));
    vm.setScheduledAt(_departureDate);

    final trip = await vm.saveTrip();
    if (!mounted) return;
    if (trip != null) {
      context.showSnack('Viagem criada com sucesso!');
      context.pushReplacement('/trips/${trip.id}');
    } else {
      context.showSnack(
        vm.saveError != null
            ? 'Erro ao criar viagem: ${vm.saveError}'
            : 'Erro ao criar viagem. Tente novamente.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TripViewModel>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: _step, onBack: _back),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 8),
                child: [
                  _buildStep0(),
                  _buildStep1(vm),
                  _buildStep2(vm),
                  _buildStep3(vm),
                ][_step],
              ),
            ),
            _BottomButtons(
              step: _step,
              isSaving: vm.isSaving,
              canAdvance: _canAdvance,
              onAdvance: _step == 3 ? _confirm : _advance,
            ),
          ],
        ),
      ),
    );
  }

  bool get _canAdvance {
    if (_step == 0) {
      return _destinoLabel.isNotEmpty;
    }
    return true;
  }

  // ── STEP 0: PARA ONDE VOCÊ VAI? ─────────────────────────────
  Widget _buildStep0() {
    final photoUrl = _destInfo?.photoUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'EDITAR VIAGEM',
          subtitle:
              'Altere os dados da viagem. Destino, Paradas, rotas, pessoas o tempo de viagem',
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'PARA ONDE VOCÊ VAI?'),
        Text(
          'Adicione o endereço ou selecione no mapa o destino de sua viagem',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 20),

        // ── Foto do destino ──────────────────────────────────────
        if (photoUrl != null) ...[
          GestureDetector(
            onTap: () => _pickDestinationFromMap(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: photoUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: AppColors.inputFill,
                      child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.navy),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  // Gradient overlay with place name
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 32, 14, 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _destInfo!.name,
                            style: AppTextStyles.labelLarge.copyWith(
                                color: Colors.white, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((_destInfo!.category ?? '').isNotEmpty)
                            Text(
                              _destInfo!.category!,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Tap to change label
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Trocar destino',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Destino button
        _LabelSection(label: 'DESTINO'),
        GestureDetector(
          onTap: () => _pickDestinationFromMap(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _destinoLabel.isNotEmpty
                  ? AppColors.navy
                  : AppColors.inputFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _destinoLabel.isNotEmpty
                  ? _destinoLabel.toUpperCase()
                  : 'SELECIONAR DESTINO',
              style: AppTextStyles.labelLarge.copyWith(
                color: _destinoLabel.isNotEmpty
                    ? Colors.white
                    : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Endereço completo
        _LabelSection(label: 'ENDEREÇO COMPLETO'),
        Text('Ou adicione o CEP para puxar os dados',
            style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: _FormField(
                  controller: _ruaCtrl, hint: 'Rua'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FormField(
                  controller: _numCtrl, hint: 'N°'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FormField(controller: _bairroCtrl, hint: 'Bairro'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FormField(
                controller: _cepCtrl,
                hint: 'CEP',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  if (v.length >= 8) _lookupCep(v);
                },
                suffix: _lookingUpCep
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.navy),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _lookupCep(_cepCtrl.text),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('SALVAR DESTINO',
                      style: AppTextStyles.labelLarge
                          .copyWith(fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Mini map preview / BUSCAR NO MAPA
        _MapPreviewBox(
          lat: _destLat,
          lng: _destLng,
          onTap: () => _pickDestinationFromMap(),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => _pickDestinationFromMap(),
            child: Text('BUSCAR NO MAPA',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.navy)),
          ),
        ),
        const SizedBox(height: 24),

        // ── Ponto de partida / encontro (opcional) ───────────────
        _LabelSection(label: 'PONTO DE PARTIDA'),
        Text(
          'Defina um ponto de encontro ou use sua localização atual',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 12),

        if (_departurePoint != null) ...[
          // Card showing the selected departure point
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.navy.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trip_origin,
                    color: AppColors.navy, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _departurePoint!.label?.isNotEmpty == true
                            ? _departurePoint!.label!
                            : 'Ponto selecionado',
                        style: AppTextStyles.labelLarge
                            .copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((_departurePoint!.address ?? '').isNotEmpty)
                        Text(
                          _departurePoint!.address!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _departurePoint = null),
                  child: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickDepartureFromMap,
            icon: const Icon(Icons.edit_location_alt_outlined,
                size: 18),
            label: const Text('Trocar ponto'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.navy,
              padding:
                  const EdgeInsets.symmetric(horizontal: 0),
            ),
          ),
        ] else ...[
          // Default: current device location
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location,
                    color: AppColors.textMuted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Localização atual (padrão)',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _pickDepartureFromMap,
              icon: const Icon(Icons.add_location_alt_outlined,
                  size: 18),
              label: Text(
                'DEFINIR PONTO DE ENCONTRO',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.navy, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side:
                    const BorderSide(color: AppColors.navy),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _pickDestinationFromMap() async {
    final result = await context.push<dynamic>('/map/select', extra: {
      'title': 'Busque o destino no mapa',
      'onSelected': null,
    });
    if (result == null || !mounted) return;

    LocationModel? loc;
    PlaceInfo? info;
    if (result is Map) {
      loc = result['location'] as LocationModel?;
      info = result['info'] as PlaceInfo?;
    } else if (result is LocationModel) {
      loc = result;
    }
    if (loc == null) return;

    setState(() {
      _destLat = loc!.lat;
      _destLng = loc.lng;
      final name = loc.label?.trim();
      final addr = loc.address?.trim();
      _destinoLabel =
          (name != null && name.isNotEmpty) ? name : (addr ?? _destinoLabel);
      _destInfo = info;

      // Auto-preenche campos de endereço com dados estruturados da API
      if (info != null) {
        if ((info.streetName ?? '').isNotEmpty) {
          _ruaCtrl.text = info.streetName!;
          _numCtrl.text = info.streetNumber ?? '';
        } else if (addr != null && addr.isNotEmpty) {
          _ruaCtrl.text = addr.split(',').first.trim();
        }
        if ((info.neighborhood ?? '').isNotEmpty) {
          _bairroCtrl.text = info.neighborhood!;
        }
        if ((info.postalCode ?? '').isNotEmpty) {
          final cep = info.postalCode!;
          _cepCtrl.text =
              cep.length == 8 ? '${cep.substring(0, 5)}-${cep.substring(5)}' : cep;
        }
      } else if (addr != null && addr.isNotEmpty) {
        _ruaCtrl.text = addr.split(',').first.trim();
      }
    });
  }

  // ── STEP 1: QUANTO TEMPO + PESSOAS ──────────────────────────
  Widget _buildStep1(TripViewModel vm) {
    final socialVm = context.watch<SocialViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'EDITAR VIAGEM',
          subtitle:
              'Altere os dados da viagem. Destino, Paradas, rotas, pessoas o tempo de viagem',
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'QUANTO TEMPO DE VIAGEM?'),
        Text('Qual o dia de Partida e o dia de volta?',
            style: AppTextStyles.bodyMedium),
        const SizedBox(height: 20),

        _LabelSection(label: 'Data de partida'),
        _DatePickerBox(
          selectedDate: _departureDate,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _departureDate ??
                  DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate:
                  DateTime.now().add(const Duration(days: 730)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.navy,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.navy,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() => _departureDate = picked);
              vm.setScheduledAt(picked);
            }
          },
        ),
        const SizedBox(height: 24),

        _LabelSection(label: 'Pessoas que viajarão com você'),
        Text('Busque por nome ou @username para convidar',
            style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),

        // ── Selected chips ──────────────────────────────────────
        if (vm.participants.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: vm.participants
                  .map((p) => _PersonChip(
                        user: p,
                        selected: true,
                        onTap: () => vm.toggleParticipant(p),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Search bar ──────────────────────────────────────────
        _ParticipantSearchBar(
          controller: _peoplSearchCtrl,
          onChanged: (q) {
            if (q.isEmpty) {
              context.read<SocialViewModel>().search('');
            } else {
              context.read<SocialViewModel>().search(q);
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 8),

        // ── List: friends or search results ─────────────────────
        _ParticipantList(
          isSearching: socialVm.isSearching,
          query: _peoplSearchCtrl.text,
          users: _peoplSearchCtrl.text.isEmpty
              ? socialVm.friends
              : socialVm.searchResults,
          isLoadingFriends: socialVm.isLoading,
          isSelected: vm.isParticipant,
          onToggle: vm.toggleParticipant,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── STEP 2: PARADAS + ROTAS ──────────────────────────────────
  Widget _buildStep2(TripViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'EDITAR VIAGEM',
          subtitle:
              'Altere os dados da viagem. Destino, Paradas, rotas, pessoas o tempo de viagem',
        ),
        const SizedBox(height: 24),

        _LabelSection(label: 'PARADAS'),
        Text(
            'Essa seção é opcional, se não houver paradas até o destino apenas avance para a próxima sessão',
            style: AppTextStyles.bodySmall),
        const SizedBox(height: 16),

        // Suggested stop card
        _SuggestedStopCard(
          name: 'Parada sugerida',
          category: 'RESTAURANTE',
          location: _destinoLabel.isNotEmpty ? _destinoLabel : 'Destino',
          onAdd: () => setState(() => _stopNames.add('Parada sugerida')),
        ),
        const SizedBox(height: 12),

        // Added stops
        ..._stopNames.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place,
                              color: AppColors.navy, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(e.value,
                                  style: AppTextStyles.titleMedium)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.error, size: 18),
                    onPressed: () =>
                        setState(() => _stopNames.removeAt(e.key)),
                  ),
                ],
              ),
            )),

        // Search bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Pesquise por paradas',
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textMuted, size: 18),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 12),
            ),
            onSubmitted: (v) {
              if (v.isNotEmpty)
                setState(() => _stopNames.add(v));
            },
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── STEP 3: RESUMO ───────────────────────────────────────────
  Widget _buildStep3(TripViewModel vm) {
    final address =
        '${_ruaCtrl.text.trim()}, ${_numCtrl.text.trim()}\n${_bairroCtrl.text.trim()}\nCEP: ${_cepCtrl.text.trim()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'RESUMO',
          subtitle: 'Confira todas as informações da viagem',
        ),
        const SizedBox(height: 24),

        // Destino
        _LabelSection(label: 'DESTINO DA VIAGEM'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _destinoLabel.toUpperCase(),
            style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        if (_ruaCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Mini map placeholder
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: AppColors.teal, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(address,
                      style: AppTextStyles.bodySmall
                          .copyWith(height: 1.5)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Data
        _LabelSection(label: 'DATA DA VIAGEM'),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Text(
                _departureDate != null
                    ? _formatDate(_departureDate!)
                    : 'Data não definida',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Viajantes
        if (vm.participants.isNotEmpty) ...[
          _LabelSection(
              label: 'VIAJANTES (${vm.participants.length})'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: vm.participants
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Column(
                          children: [
                            AppAvatar(
                                name: p.name,
                                imageUrl: p.avatarUrl,
                                size: 44),
                            const SizedBox(height: 4),
                            Text(p.name.split(' ').first,
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Paradas
        if (_stopNames.isNotEmpty) ...[
          _LabelSection(
              label: 'PARADAS (${_stopNames.length})'),
          ..._stopNames.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.place,
                        color: AppColors.navy, size: 16),
                    const SizedBox(width: 6),
                    Text(s, style: AppTextStyles.titleMedium),
                  ],
                ),
              )),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${d.day.toString().padLeft(2, '0')} de ${months[d.month]} de ${d.year}';
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  const _TopBar({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // App bar row
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.inputFill,
                  child: Icon(Icons.person,
                      color: AppColors.navy, size: 20),
                ),
              ),
              const Spacer(),
              Text('HOME',
                  style: AppTextStyles.headlineMedium
                      .copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.navy),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onBack,
            child:
                const Align(alignment: Alignment.centerLeft, child: Icon(Icons.arrow_back, color: AppColors.navy, size: 24)),
          ),
        ],
      ),
    );
  }
}

class _BottomButtons extends StatelessWidget {
  final int step;
  final bool isSaving;
  final bool canAdvance;
  final VoidCallback onAdvance;

  const _BottomButtons({
    required this.step,
    required this.isSaving,
    required this.canAdvance,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (canAdvance && !isSaving) ? onAdvance : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            disabledBackgroundColor: AppColors.navy.withOpacity(0.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(step == 3 ? 'CONFIRMAR' : 'AVANÇAR',
                  style: AppTextStyles.labelLarge),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeading(
      {required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: AppTextStyles.headlineMedium
            .copyWith(fontWeight: FontWeight.w800, fontSize: 18),
      ),
    );
  }
}

class _LabelSection extends StatelessWidget {
  final String label;
  const _LabelSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: AppTextStyles.titleLarge
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final Widget? suffix;

  const _FormField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium
          .copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: suffix)
            : null,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _MapPreviewBox extends StatelessWidget {
  final double? lat;
  final double? lng;
  final VoidCallback onTap;

  const _MapPreviewBox(
      {required this.lat, required this.lng, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: lat != null
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.location_on,
                      color: AppColors.navy, size: 40),
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Text(
                      '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.navy),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined,
                      color: AppColors.textMuted, size: 36),
                  const SizedBox(height: 8),
                  Text('Toque para selecionar no mapa',
                      style: AppTextStyles.bodySmall),
                ],
              ),
      ),
    );
  }
}

class _DatePickerBox extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;
  const _DatePickerBox(
      {required this.selectedDate, required this.onTap});

  static const months = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (selectedDate == null)
              const Expanded(
                child: Center(
                  child: Icon(Icons.calendar_month,
                      color: Colors.white30, size: 60),
                ),
              )
            else
              const Expanded(child: SizedBox()),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    selectedDate != null
                        ? '${selectedDate!.day.toString().padLeft(2, '0')} de ${months[selectedDate!.month]} de ${selectedDate!.year}'
                        : 'Toque para escolher a data',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Participant search bar ───────────────────────────────────────────────────

class _ParticipantSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _ParticipantSearchBar(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Buscar por nome ou @username',
          hintStyle:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// ─── Participant list ─────────────────────────────────────────────────────────

class _ParticipantList extends StatelessWidget {
  final bool isSearching;
  final bool isLoadingFriends;
  final String query;
  final List<UserModel> users;
  final bool Function(UserModel) isSelected;
  final void Function(UserModel) onToggle;
  const _ParticipantList({
    required this.isSearching,
    required this.isLoadingFriends,
    required this.query,
    required this.users,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching || (isLoadingFriends && query.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            query.isEmpty
                ? 'Você ainda não tem amigos adicionados'
                : 'Nenhum usuário encontrado',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: users.map((u) {
          final selected = isSelected(u);
          return Column(
            children: [
              InkWell(
                onTap: () => onToggle(u),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Avatar com foto real
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            AppColors.navy.withOpacity(0.1),
                        backgroundImage: u.avatarUrl != null
                            ? NetworkImage(u.avatarUrl!)
                            : null,
                        child: u.avatarUrl == null
                            ? Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.titleMedium
                                    .copyWith(color: AppColors.navy),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name,
                                style: AppTextStyles.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (u.username.isNotEmpty)
                              Text('@${u.username}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // Checkbox visual
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.navy
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? AppColors.navy
                                : AppColors.divider,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (u != users.last)
                const Divider(height: 1, indent: 58),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  final UserModel user;
  final bool selected;
  final VoidCallback onTap;
  const _PersonChip(
      {required this.user,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                AppAvatar(
                    name: user.name,
                    imageUrl: user.avatarUrl,
                    size: 46),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.name.split(' ').first,
              style: AppTextStyles.bodySmall
                  .copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedStopCard extends StatelessWidget {
  final String name;
  final String category;
  final String location;
  final VoidCallback onAdd;
  const _SuggestedStopCard(
      {required this.name,
      required this.category,
      required this.location,
      required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10)),
            child: Container(
              width: 80,
              height: 80,
              color: AppColors.teal.withOpacity(0.2),
              child: const Icon(Icons.restaurant,
                  color: AppColors.teal, size: 32),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.navy,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(name, style: AppTextStyles.titleMedium),
                  Text(location,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('ADICIONAR PARADA',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        letterSpacing: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RouteOption(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.navy.withOpacity(0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected ? AppColors.navy : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.route,
              color: selected
                  ? AppColors.navy
                  : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(label,
                style: AppTextStyles.titleMedium.copyWith(
                    color: selected
                        ? AppColors.navy
                        : AppColors.textSecondary)),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.navy, size: 18),
          ],
        ),
      ),
    );
  }
}
