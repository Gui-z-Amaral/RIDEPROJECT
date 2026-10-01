import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/supabase_event_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/event_viewmodel.dart';
import '../../../shared/widgets/visibility_switch.dart';
import '../../../core/constants/text_limits.dart';
import '../../../core/utils/whatsapp_text.dart';

/// Tela de criação/edição de evento (perfil empresa). Form único com banner,
/// título, descrição, local (mapa), data/hora, programação, patrocinadores e
/// participantes extras. Em modo edição, salvar notifica quem tem interesse.
class CreateEventScreen extends StatefulWidget {
  /// Quando informado, a tela edita o evento com este ID.
  final String? eventId;

  /// Quando informado, cria um evento vinculado a este motoclube.
  final String? clubId;
  const CreateEventScreen({super.key, this.eventId, this.clubId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  bool get _isEditing => widget.eventId != null;
  bool _prefilled = false;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _bannerUrl;
  bool _uploadingBanner = false;
  /// Visibilidade do evento. Antes era herdada do motoclube; desde a
  /// migration 034 cada evento tem a sua.
  /// Definido no initState: evento criado DENTRO do motoclube nasce privado.
  /// Antes nascia público em todo caso, e quem criava pelo mural sem mexer no
  /// interruptor publicava na aba Eventos geral sem perceber.
  late bool _isPublic;

  /// Clube do evento: vem da rota ao criar, e do próprio evento ao editar (a
  /// rota de edição não traz o clube).
  String? _clubId;

  // ── Saída do rolê (migration 046, só evento de motoclube) ──
  DateTime? _departureAt;
  LocationModel? _meetingPoint;

  /// Como estava salvo, para saber na edição se a saída mudou: quando muda, o
  /// banco manda um aviso próprio ("Saída alterada") e o genérico "evento
  /// atualizado" viraria um segundo push sobre a mesma coisa.
  DateTime? _departureSalva;
  LocationModel? _meetingSalvo;

  /// Sugestão tirada da descrição colada do WhatsApp. Só sugere: quem
  /// confirma o horário e o lugar é a pessoa.
  ({int hora, int minuto})? _sugHora;
  String? _sugPonto;
  bool _sugDispensada = false;

  LocationModel? _location;
  String? _stateUf;
  String? _city;
  bool _resolvingState = false;

  DateTime? _startsAt;
  DateTime? _endsAt;

  final List<_ScheduleDraft> _schedule = [];
  final List<_SponsorDraft> _sponsors = [];

  // Participantes extras (usuários do app) — selecionados por id.
  final Map<String, UserModel> _selectedParticipants = {};
  final _participantSearchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<UserModel> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _clubId = widget.clubId;
    _isPublic = widget.clubId == null;
    _descCtrl.addListener(_lerSugestao);
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndPrefill());
    } else {
      _prefilled = true;
    }
  }

  Future<void> _loadAndPrefill() async {
    final vm = context.read<EventViewModel>();
    await vm.loadDetail(widget.eventId!);
    if (!mounted) return;
    final e = vm.selected;
    if (e != null && e.id == widget.eventId) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description ?? '';
      // Antes a edição abria sempre em "Público", mesmo com o evento privado.
      _isPublic = e.isPublic;
      _clubId = e.clubId;
      _departureAt = e.departureAt;
      _meetingPoint = e.meetingPoint;
      _departureSalva = e.departureAt;
      _meetingSalvo = e.meetingPoint;
      _bannerUrl = e.bannerUrl;
      _stateUf = e.stateUf;
      _city = e.city;
      _startsAt = e.startsAt;
      _endsAt = e.endsAt;
      if (e.hasLocation) {
        _location = LocationModel(
          lat: e.lat!,
          lng: e.lng!,
          address: e.address,
          label: e.locationLabel,
        );
      }
      for (final s in e.schedule) {
        _schedule.add(_ScheduleDraft(
          time: s.timeLabel ?? '',
          title: s.title,
          desc: s.description ?? '',
        ));
      }
      for (final sp in e.sponsors) {
        _sponsors.add(_SponsorDraft(name: sp.name, logoUrl: sp.logoUrl));
      }
      for (final p in e.participants) {
        _selectedParticipants[p.id] = p;
      }
    }
    setState(() => _prefilled = true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _participantSearchCtrl.dispose();
    _searchDebounce?.cancel();
    for (final s in _schedule) {
      s.dispose();
    }
    for (final s in _sponsors) {
      s.dispose();
    }
    super.dispose();
  }

  // Local é obrigatório: sem ele o evento não tem UF e não apareceria na home
  // de nenhum usuário (a home filtra eventos pela UF da localização atual).
  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty &&
      _startsAt != null &&
      _location != null;

  // ── Banner ───────────────────────────────────────────────────
  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploadingBanner = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await SupabaseEventService.uploadBanner(bytes);
      if (!mounted) return;
      setState(() => _bannerUrl = url);
    } catch (_) {
      if (mounted) context.showSnack('Erro ao enviar banner.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  // ── Local ────────────────────────────────────────────────────
  Future<void> _pickLocation() async {
    final result = await context.push<dynamic>('/map/select', extra: {
      'title': 'Local do evento',
      'onSelected': null,
    });
    if (result == null || !mounted) return;
    LocationModel? loc;
    if (result is Map) {
      loc = result['location'] as LocationModel?;
    } else if (result is LocationModel) {
      loc = result;
    }
    if (loc == null) return;
    final picked = loc;
    setState(() {
      _location = picked;
      _resolvingState = true;
      _city = _guessCity(picked.address) ?? picked.label;
    });
    final uf = await GeocodingService.getStateUf(picked.lat, picked.lng);
    if (!mounted) return;
    setState(() {
      _stateUf = uf;
      _resolvingState = false;
    });
  }

  String? _guessCity(String? address) {
    if (address == null || address.isEmpty) return null;
    final parts = address.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 2) return parts[parts.length - 2];
    return parts.isNotEmpty ? parts.first : null;
  }

  // ── Saída do rolê ────────────────────────────────────────────
  void _lerSugestao() {
    if (_clubId == null || _sugDispensada) return;
    final t = _descCtrl.text;
    final h = _departureAt == null ? WhatsAppText.horarioDeSaida(t) : null;
    final p = _meetingPoint == null ? WhatsAppText.pontoDeEncontro(t) : null;
    if (h != _sugHora || p != _sugPonto) {
      setState(() {
        _sugHora = h;
        _sugPonto = p;
      });
    }
  }

  /// Aplica a sugestão, sempre pedindo confirmação: o horário abre no seletor
  /// já preenchido (a data vem do início do evento), e o ponto de encontro
  /// abre a busca do mapa já com o nome digitado.
  Future<void> _usarSugestao() async {
    final h = _sugHora;
    final p = _sugPonto;
    setState(() => _sugDispensada = true);
    if (h != null) {
      final dia = _startsAt ?? DateTime.now().add(const Duration(days: 1));
      final dt = await _pickDateTime(
          DateTime(dia.year, dia.month, dia.day, h.hora, h.minuto));
      if (dt != null && mounted) setState(() => _departureAt = dt);
    }
    if (p != null && mounted) await _pickMeetingPoint(busca: p);
  }

  Future<void> _pickDeparture() async {
    final base = _departureAt ??
        (_startsAt ?? DateTime.now().add(const Duration(days: 1)))
            .subtract(const Duration(hours: 1));
    final dt = await _pickDateTime(base);
    if (dt != null) setState(() => _departureAt = dt);
  }

  Future<void> _pickMeetingPoint({String? busca}) async {
    final result = await context.push<dynamic>('/map/select', extra: {
      'title': 'Ponto de encontro',
      'onSelected': null,
      if (busca != null) 'initialQuery': busca,
    });
    if (result == null || !mounted) return;
    final loc = result is Map
        ? result['location'] as LocationModel?
        : result as LocationModel?;
    if (loc != null) setState(() => _meetingPoint = loc);
  }

  bool get _saidaMudou {
    final a = _departureAt, b = _departureSalva;
    final horaMudou =
        (a == null) != (b == null) || (a != null && !a.isAtSameMomentAs(b!));
    final m = _meetingPoint, n = _meetingSalvo;
    final pontoMudou = (m == null) != (n == null) ||
        (m != null &&
            (m.lat != n!.lat || m.lng != n.lng || m.label != n.label));
    return horaMudou || pontoMudou;
  }

  // ── Data/hora ────────────────────────────────────────────────
  Future<void> _pickStart() async {
    final dt = await _pickDateTime(_startsAt ??
        DateTime.now().add(const Duration(days: 1, hours: 1)));
    if (dt != null) setState(() => _startsAt = dt);
  }

  Future<void> _pickEnd() async {
    final base = _endsAt ??
        (_startsAt ?? DateTime.now()).add(const Duration(hours: 2));
    final dt = await _pickDateTime(base);
    if (dt != null) setState(() => _endsAt = dt);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    // Evento antigo em edição: o seletor não aceita abrir antes de hoje.
    final agora = DateTime.now();
    if (initial.isBefore(agora)) {
      initial = DateTime(agora.year, agora.month, agora.day, initial.hour,
          initial.minute);
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.navy,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.navy,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.navy,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.navy,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Programação ──────────────────────────────────────────────
  void _addScheduleItem() => setState(() => _schedule.add(_ScheduleDraft()));
  void _removeScheduleItem(int i) {
    _schedule.removeAt(i).dispose();
    setState(() {});
  }

  // ── Patrocinadores ───────────────────────────────────────────
  void _addSponsor() => setState(() => _sponsors.add(_SponsorDraft()));
  void _removeSponsor(int i) {
    _sponsors.removeAt(i).dispose();
    setState(() {});
  }

  Future<void> _pickSponsorLogo(_SponsorDraft sponsor) async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() => sponsor.uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await SupabaseEventService.uploadSponsorLogo(bytes);
      if (!mounted) return;
      setState(() => sponsor.logoUrl = url);
    } catch (_) {
      if (mounted) context.showSnack('Erro ao enviar logo.', isError: true);
    } finally {
      if (mounted) setState(() => sponsor.uploading = false);
    }
  }

  // ── Participantes ────────────────────────────────────────────
  void _onParticipantSearch(String v) {
    _searchDebounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await SupabaseEventService.searchUsers(q);
        if (!mounted) return;
        setState(() {
          _searchResults = res;
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _toggleParticipant(UserModel u) {
    setState(() {
      if (_selectedParticipants.containsKey(u.id)) {
        _selectedParticipants.remove(u.id);
      } else {
        _selectedParticipants[u.id] = u;
      }
    });
  }

  // ── Salvar ───────────────────────────────────────────────────
  Future<void> _save() async {
    final vm = context.read<EventViewModel>();

    // Garante a UF resolvida: se o geocode falhou ao escolher o local, tenta
    // de novo — sem UF o evento não apareceria na home de ninguém.
    if (_stateUf == null && _location != null) {
      final uf =
          await GeocodingService.getStateUf(_location!.lat, _location!.lng);
      if (!mounted) return;
      if (uf != null) _stateUf = uf;
    }

    final schedule = _schedule
        .where((s) => s.titleCtrl.text.trim().isNotEmpty)
        .map((s) => EventScheduleItem(
              timeLabel:
                  s.timeCtrl.text.trim().isEmpty ? null : s.timeCtrl.text.trim(),
              title: s.titleCtrl.text.trim(),
              description:
                  s.descCtrl.text.trim().isEmpty ? null : s.descCtrl.text.trim(),
            ))
        .toList();
    final sponsors = _sponsors
        .where((s) => s.nameCtrl.text.trim().isNotEmpty)
        .map((s) => EventSponsor(
              name: s.nameCtrl.text.trim(),
              logoUrl: s.logoUrl,
            ))
        .toList();
    final participantIds = _selectedParticipants.keys.toList();

    EventModel? event;
    if (_isEditing) {
      event = await vm.updateEvent(
        widget.eventId!,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        bannerUrl: _bannerUrl,
        lat: _location?.lat,
        lng: _location?.lng,
        address: _location?.address,
        locationLabel: _location?.label,
        stateUf: _stateUf,
        city: _city,
        startsAt: _startsAt,
        endsAt: _endsAt,
        isPublic: _isPublic,
        saida: _clubId == null
            ? null
            : EventDeparture(at: _departureAt, meetingPoint: _meetingPoint),
        schedule: schedule,
        sponsors: sponsors,
        participantIds: participantIds,
        // Se a saída mudou, o banco já avisa com "Saída alterada".
        notifyInterested: !(_clubId != null && _saidaMudou),
      );
    } else {
      event = await vm.createEvent(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        bannerUrl: _bannerUrl,
        lat: _location?.lat,
        lng: _location?.lng,
        address: _location?.address,
        locationLabel: _location?.label,
        stateUf: _stateUf,
        city: _city,
        startsAt: _startsAt!,
        endsAt: _endsAt,
        clubId: widget.clubId,
        isPublic: _isPublic,
        saida: _clubId == null
            ? null
            : EventDeparture(at: _departureAt, meetingPoint: _meetingPoint),
        schedule: schedule,
        sponsors: sponsors,
        participantIds: participantIds,
      );
    }
    if (!mounted) return;
    if (event != null) {
      context.showSnack(_isEditing
          ? 'Evento atualizado! Interessados foram notificados.'
          : 'Evento criado!');
      context.pushReplacement('/events/${event.id}');
    } else {
      context.showSnack(vm.saveError ?? 'Erro ao salvar evento', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (_isEditing && !_prefilled) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditing ? 'Editar evento' : 'Novo evento',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 100),
        children: [
          // ── Banner ───────────────────────────────────────────
          GestureDetector(
            onTap: _uploadingBanner ? null : _pickBanner,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
                image: _bannerUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_bannerUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: _uploadingBanner
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.navy))
                  : _bannerUrl == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: AppColors.navy.withOpacity(0.4),
                                  size: 36),
                              const SizedBox(height: 6),
                              Text('Adicionar banner do evento',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : null,
            ),
          ),
          const SizedBox(height: 24),

          // ── Título ───────────────────────────────────────────
          const _Label('NOME DO EVENTO'),
          _Input(
            controller: _titleCtrl,
            hint: 'Ex: Encontro de Motociclistas 2026',
            maxLength: TextLimits.evento,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // ── Descrição ────────────────────────────────────────
          const _Label('DESCRIÇÃO'),
          _Input(
              controller: _descCtrl,
              hint: 'Conte sobre o evento...',
              maxLines: 4,
              maxLength: TextLimits.eventoDesc),
          if (_clubId != null &&
              !_sugDispensada &&
              (_sugHora != null || _sugPonto != null)) ...[
            const SizedBox(height: 10),
            _SugestaoSaida(
              hora: _sugHora,
              ponto: _sugPonto,
              onUsar: _usarSugestao,
              onIgnorar: () => setState(() => _sugDispensada = true),
            ),
          ],
          const SizedBox(height: 20),

          // ── Cronograma ───────────────────────────────────────
          // Logo abaixo da descrição: no fim da tela, depois de "quem pode
          // ver", ninguém achava, e o horário ia parar na descrição.
          _SectionRow(label: 'CRONOGRAMA', onAdd: _addScheduleItem),
          const SizedBox(height: 4),
          if (_schedule.isEmpty)
            Text('Adicione os horários e atividades do evento (opcional).',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted)),
          ..._schedule.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ScheduleItemEditor(
                  draft: e.value,
                  onRemove: () => _removeScheduleItem(e.key),
                ),
              )),
          const SizedBox(height: 24),


          // ── Local ────────────────────────────────────────────
          const _Label('LOCAL'),
          GestureDetector(
            onTap: _pickLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _location != null
                    ? AppColors.navy.withOpacity(0.06)
                    : AppColors.inputFill,
                border: Border.all(
                    color:
                        _location != null ? AppColors.navy : AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: _location != null
                          ? AppColors.navy
                          : AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _location == null
                        ? Text('Selecionar local no mapa',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textMuted))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _location!.label?.isNotEmpty == true
                                      ? _location!.label!
                                      : 'Local selecionado',
                                  style: AppTextStyles.titleSmall
                                      .copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                _resolvingState
                                    ? 'Identificando estado...'
                                    : [
                                        if ((_location!.address ?? '')
                                            .isNotEmpty)
                                          _location!.address,
                                        if (_stateUf != null) 'UF: $_stateUf',
                                      ].whereType<String>().join(' · '),
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Data/hora ────────────────────────────────────────
          const _Label('INÍCIO'),
          _DateTimeBox(
              value: _startsAt, hint: 'Escolher data e hora', onTap: _pickStart),
          const SizedBox(height: 12),
          const _Label('TÉRMINO (OPCIONAL)'),
          _DateTimeBox(
            value: _endsAt,
            hint: 'Escolher data e hora',
            onTap: _pickEnd,
            onClear: _endsAt != null ? () => setState(() => _endsAt = null) : null,
          ),
          const SizedBox(height: 24),

          // ── Saída do rolê (só motoclube) ─────────────────────
          // Empresa não tem "saída"; o rolê do clube até o evento tem.
          if (_clubId != null) ...[
            const _Label('SAÍDA DO ROLÊ (OPCIONAL)'),
            _DateTimeBox(
              value: _departureAt,
              hint: 'Horário de saída',
              onTap: _pickDeparture,
              onClear: _departureAt != null
                  ? () => setState(() => _departureAt = null)
                  : null,
            ),
            const SizedBox(height: 12),
            _PontoDeEncontroBox(
              ponto: _meetingPoint,
              onTap: _pickMeetingPoint,
              onClear: _meetingPoint != null
                  ? () => setState(() => _meetingPoint = null)
                  : null,
            ),
            const SizedBox(height: 24),
          ],

          // ── Visibilidade ─────────────────────────────────────
          const _Label('QUEM PODE VER'),
          VisibilitySwitch(
            isPublic: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            // Evento de clube nunca vai para a aba Eventos: público, ele só
            // fica visível para quem visita a página do clube.
            publicHint: _clubId != null
                ? 'Quem visitar o motoclube vê, mesmo sem ser membro'
                : 'Aparece na aba Eventos e qualquer pessoa pode abrir o link',
            privateHint: _clubId != null
                ? 'Só membros do motoclube veem'
                : 'Só você e quem receber o convite',
          ),
          const SizedBox(height: 24),

          // ── Patrocinadores ───────────────────────────────────
          _SectionRow(label: 'PATROCINADORES', onAdd: _addSponsor),
          const SizedBox(height: 4),
          if (_sponsors.isEmpty)
            Text('Adicione marcas e apoiadores (nome + logo opcional).',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted)),
          ..._sponsors.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _SponsorEditor(
                  draft: e.value,
                  onRemove: () => _removeSponsor(e.key),
                  onPickLogo: () => _pickSponsorLogo(e.value),
                ),
              )),
          const SizedBox(height: 24),

          // ── Participantes extras ─────────────────────────────
          const _Label('PARTICIPANTES EXTRAS'),
          Text('Convide usuários do app para constar no evento.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          if (_selectedParticipants.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedParticipants.values
                  .map((u) => _ParticipantChip(
                        user: u,
                        onRemove: () => _toggleParticipant(u),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 10),
          _Input(
            controller: _participantSearchCtrl,
            hint: 'Buscar por nome ou @username',
            onChanged: _onParticipantSearch,
          ),
          if (_searching)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.navy))),
            )
          else if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _searchResults.map((u) {
                  final selected = _selectedParticipants.containsKey(u.id);
                  return InkWell(
                    onTap: () => _toggleParticipant(u),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          AppAvatar(
                              name: u.name, imageUrl: u.avatarUrl, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.name,
                                    style: AppTextStyles.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (u.username.isNotEmpty)
                                  Text('@${u.username}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                            color:
                                selected ? AppColors.teal : AppColors.navy,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 28),

          // ── Salvar ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_canSave && !vm.isSaving) ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                disabledBackgroundColor: AppColors.navy.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: vm.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'SALVAR ALTERAÇÕES' : 'CRIAR EVENTO',
                      style: AppTextStyles.labelLarge),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Drafts ──────────────────────────────────────────────────────────────────

class _ScheduleDraft {
  final TextEditingController timeCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  _ScheduleDraft({String time = '', String title = '', String desc = ''})
      : timeCtrl = TextEditingController(text: time),
        titleCtrl = TextEditingController(text: title),
        descCtrl = TextEditingController(text: desc);
  void dispose() {
    timeCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
  }
}

class _SponsorDraft {
  final TextEditingController nameCtrl;
  String? logoUrl;
  bool uploading = false;
  _SponsorDraft({String name = '', this.logoUrl})
      : nameCtrl = TextEditingController(text: name);
  void dispose() => nameCtrl.dispose();
}

// ─── Editors ─────────────────────────────────────────────────────────────────

class _ScheduleItemEditor extends StatelessWidget {
  final _ScheduleDraft draft;
  final VoidCallback onRemove;
  const _ScheduleItemEditor({required this.draft, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: _Input(controller: draft.timeCtrl, hint: '14:00'),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: _Input(controller: draft.titleCtrl, hint: 'Atividade')),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.error, size: 20),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Input(
              controller: draft.descCtrl,
              hint: 'Descrição (opcional)',
              maxLines: 2),
        ],
      ),
    );
  }
}

class _SponsorEditor extends StatelessWidget {
  final _SponsorDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onPickLogo;
  const _SponsorEditor({
    required this.draft,
    required this.onRemove,
    required this.onPickLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: draft.uploading ? null : onPickLogo,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
                image: draft.logoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(draft.logoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: draft.uploading
                  ? Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.navy)))
                  : draft.logoUrl == null
                      ? Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.navy.withOpacity(0.5), size: 22)
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Input(controller: draft.nameCtrl, hint: 'Nome do patrocinador'),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.error, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRemove;
  const _ParticipantChip({required this.user, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(name: user.name, imageUrl: user.avatarUrl, size: 24),
          const SizedBox(width: 6),
          Text(user.name.split(' ').first,
              style: AppTextStyles.labelMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers de UI ─────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String label;
  final VoidCallback onAdd;
  const _SectionRow({required this.label, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Label(label),
        GestureDetector(
          onTap: onAdd,
          child: Row(
            children: [
              Icon(Icons.add, color: AppColors.navy, size: 18),
              const SizedBox(width: 4),
              Text('Adicionar',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.navy)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final void Function(String)? onChanged;
  const _Input({
    required this.controller,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        maxLength: maxLength,
        buildCounter: maxLines > 1
            ? null
            : (_, {required currentLength, required isFocused, maxLength}) =>
                null,
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

class _DateTimeBox extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateTimeBox({
    required this.value,
    required this.hint,
    required this.onTap,
    this.onClear,
  });

  String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}  $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: value != null ? AppColors.navy : AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18,
                color: value != null ? Colors.white70 : AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value != null ? _fmt(value!) : hint,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: value != null ? Colors.white : AppColors.textMuted,
                    fontWeight:
                        value != null ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sugestão tirada da descrição ────────────────────────────────────────────

/// "Achamos no texto: saída às 13:30 · encontro em Posto Simon."
/// Aparece quando a descrição traz a saída e os campos próprios estão vazios.
class _SugestaoSaida extends StatelessWidget {
  final ({int hora, int minuto})? hora;
  final String? ponto;
  final VoidCallback onUsar;
  final VoidCallback onIgnorar;
  const _SugestaoSaida({
    required this.hora,
    required this.ponto,
    required this.onUsar,
    required this.onIgnorar,
  });

  @override
  Widget build(BuildContext context) {
    final h = hora;
    final partes = [
      if (h != null)
        'saída às ${h.hora.toString().padLeft(2, '0')}:'
            '${h.minuto.toString().padLeft(2, '0')}',
      if (ponto != null) 'encontro em $ponto',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Achamos no texto: ${partes.join(' · ')}. '
                  'Nos campos de saída, o ponto aparece no mapa e quem vai '
                  'é avisado se mudar.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onIgnorar, child: const Text('Agora não')),
              TextButton(
                onPressed: onUsar,
                child: Text('Usar',
                    style: TextStyle(
                        color: AppColors.navy, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Ponto de encontro ───────────────────────────────────────────────────────

class _PontoDeEncontroBox extends StatelessWidget {
  final LocationModel? ponto;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _PontoDeEncontroBox({
    required this.ponto,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = ponto;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: p != null
              ? AppColors.navy.withValues(alpha: 0.06)
              : AppColors.inputFill,
          border:
              Border.all(color: p != null ? AppColors.navy : AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_outlined,
                color: p != null ? AppColors.navy : AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: p == null
                  ? Text('Ponto de encontro',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textMuted))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            p.label?.isNotEmpty == true
                                ? p.label!
                                : 'Ponto de encontro',
                            style: AppTextStyles.titleSmall
                                .copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if ((p.address ?? '').isNotEmpty)
                          Text(p.address!,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
            ),
            if (onClear != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                tooltip: 'Tirar ponto de encontro',
                onPressed: onClear,
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
