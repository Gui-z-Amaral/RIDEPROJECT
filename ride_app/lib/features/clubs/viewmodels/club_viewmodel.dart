import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../../core/models/club_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/services/supabase_club_service.dart';
import '../../../core/services/supabase_event_service.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../core/utils/db_errors.dart';

class ClubViewModel extends ChangeNotifier {
  // Aba Clubes
  List<ClubModel> _myClubs = [];
  List<ClubModel> _invites = [];
  List<ClubModel> _discover = [];
  bool _isLoading = false;

  // Detalhe
  ClubModel? _selected;
  List<ClubMemberModel> _members = [];
  bool _isLoadingDetail = false;

  bool _isSaving = false;
  String? _saveError;

  // Murais do clube (eventos e viagens) + presença do usuário
  List<EventModel> _clubEvents = [];
  List<TripModel> _clubTrips = [];
  Map<String, String> _myEventRsvp = {};
  Map<String, String> _myTripRsvp = {};
  bool _isLoadingEvents = false;
  bool _isLoadingTrips = false;

  List<EventModel> get clubEvents => _clubEvents;
  List<TripModel> get clubTrips => _clubTrips;
  Map<String, String> get myEventRsvp => _myEventRsvp;
  Map<String, String> get myTripRsvp => _myTripRsvp;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isLoadingTrips => _isLoadingTrips;

  List<ClubModel> get myClubs => _myClubs;
  List<ClubModel> get invites => _invites;
  List<ClubModel> get discover => _discover;
  bool get isLoading => _isLoading;
  ClubModel? get selected => _selected;
  List<ClubMemberModel> get members => _members;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  // ── Aba Clubes ───────────────────────────────────────────────
  Future<void> loadMine({String? discoverUf}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _myClubs = await SupabaseClubService.getMyClubs();
      _invites = await SupabaseClubService.getPendingInvites();
      _discover = await SupabaseClubService.discoverClubs(stateUf: discoverUf);
    } catch (_) {
      _myClubs = [];
      _invites = [];
      _discover = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Detalhe ──────────────────────────────────────────────────
  Future<void> loadDetail(String id) async {
    _isLoadingDetail = true;
    _selected = null;
    _members = [];
    notifyListeners();
    try {
      _selected = await SupabaseClubService.getClubById(id);
    } catch (_) {
      _selected = null;
    }
    // Carrega os membros à parte: uma falha aqui não pode esconder o clube.
    try {
      _members = await SupabaseClubService.getMembers(id);
    } catch (_) {
      _members = [];
    }
    _isLoadingDetail = false;
    notifyListeners();
  }

  Future<void> refreshMembers() async {
    final id = _selected?.id;
    if (id == null) return;
    try {
      _members = await SupabaseClubService.getMembers(id);
      _selected = _selected?.copyWith(membersCount: _members.length);
      notifyListeners();
    } catch (_) {}
  }

  /// Gerentes ativos (dono + admins) do clube selecionado.
  List<ClubMemberModel> get managers =>
      _members.where((m) => m.isAdmin).toList();

  // ── Editar clube (configurações) ─────────────────────────────
  Future<bool> updateClub(
    String clubId, {
    String? name,
    String? description,
    String? city,
    String? stateUf,
    String? bannerUrl,
    String? avatarUrl,
    bool? eventsPublic,
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      await SupabaseClubService.updateClub(
        clubId,
        name: name,
        description: description,
        city: city,
        stateUf: stateUf,
        bannerUrl: bannerUrl,
        avatarUrl: avatarUrl,
        eventsPublic: eventsPublic,
      );
    } catch (e) {
      debugPrint('❌ ClubViewModel.updateClub: $e');
      _saveError = mensagemDeErro(e);
      _isSaving = false;
      notifyListeners();
      return false;
    }

    // Daqui pra baixo o salvamento JÁ aconteceu no servidor. Reler é só para
    // a tela refletir o novo estado — se falhar (rede caindo, timeout), não é
    // erro de salvar, e dizer que foi seria mentira. Era esse o motivo de
    // aparecer "Não foi possível salvar" logo depois de salvar de verdade.
    try {
      final updated = await SupabaseClubService.getClubById(clubId);
      if (updated != null) {
        _selected = updated;
        _myClubs = _myClubs.map((c) => c.id == clubId ? updated : c).toList();
      }
    } catch (e) {
      debugPrint('⚠️ ClubViewModel.updateClub (releitura): $e');
    }

    _isSaving = false;
    notifyListeners();
    return true;
  }

  /// Mensagem amigável, com o código do Postgres junto.
  ///
  /// O código vai para a tela de propósito: sem ele, toda falha vira o mesmo
  /// "tente novamente" e não há como saber se foi permissão (42501), conflito
  /// ou rede. A mensagem crua do banco não vai — ela descreve tabela e coluna.
  @visibleForTesting
  static String mensagemDeErro(Object e) {
    // Regra de texto do banco (migration 045) vem antes: ela diz exatamente o
    // que corrigir, e o código genérico não.
    final texto = DbErrors.textoInvalido(e);
    if (texto != null) return texto;
    if (e is PostgrestException) {
      final code = e.code;
      if (code == '42501') {
        return 'Você não tem permissão para alterar este motoclube.';
      }
      return 'Não foi possível salvar.'
          '${code == null ? '' : ' (código $code)'}';
    }
    return 'Não foi possível salvar. Verifique sua conexão e tente de novo.';
  }

  // ── Gerenciar membros ────────────────────────────────────────
  /// Muda o papel de um membro ('admin' = gerente | 'member'). Só o dono
  /// tem permissão (garantido pelo RLS); a UI só expõe isso pro dono.
  Future<void> setMemberRole(String userId, String role) async {
    final id = _selected?.id;
    if (id == null) return;
    final prev = _members;
    _members = _members
        .map((m) => m.userId == userId
            ? ClubMemberModel(
                clubId: m.clubId,
                userId: m.userId,
                role: role,
                status: m.status,
                joinedAt: m.joinedAt,
                user: m.user)
            : m)
        .toList();
    notifyListeners();
    try {
      await SupabaseClubService.setRole(id, userId, role);
    } catch (_) {
      _members = prev;
      notifyListeners();
    }
  }

  // ── Murais: eventos e viagens do clube ───────────────────────
  Future<void> loadClubEvents(String clubId) async {
    _isLoadingEvents = true;
    notifyListeners();
    try {
      _clubEvents = await SupabaseEventService.getEventsByClub(clubId);
      _myEventRsvp = await SupabaseEventService.getMyRsvps(
          _clubEvents.map((e) => e.id).toList());
    } catch (_) {
      _clubEvents = [];
      _myEventRsvp = {};
    }
    _isLoadingEvents = false;
    notifyListeners();
  }

  Future<void> loadClubTrips(String clubId) async {
    _isLoadingTrips = true;
    notifyListeners();
    try {
      _clubTrips = await SupabaseTripService.getTripsByClub(clubId);
      _myTripRsvp = await SupabaseTripService.getMyRsvps(
          _clubTrips.map((t) => t.id).toList());
    } catch (_) {
      _clubTrips = [];
      _myTripRsvp = {};
    }
    _isLoadingTrips = false;
    notifyListeners();
  }

  /// Conclui ou reabre um evento do clube (migration 041).
  ///
  /// Otimista como o RSVP: troca na lista e reverte se o servidor recusar —
  /// quem recusa é a RLS, quando quem tocou não é gerente nem criador.
  Future<bool> setEventCompleted(String eventId, bool concluido) async {
    final antes = _clubEvents;
    _clubEvents = _clubEvents
        .map((e) => e.id == eventId
            ? e.copyWith(completedAt: concluido ? DateTime.now() : null)
            : e)
        .toList();
    notifyListeners();
    try {
      final quando =
          await SupabaseEventService.setCompleted(eventId, concluido);
      // Regrava com a data que o servidor devolveu, em vez do relógio local.
      _clubEvents = _clubEvents
          .map((e) => e.id == eventId ? e.copyWith(completedAt: quando) : e)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ClubViewModel.setEventCompleted: $e');
      _clubEvents = antes;
      notifyListeners();
      return false;
    }
  }

  Future<void> setEventRsvp(String eventId, String rsvp) async {
    final prev = _myEventRsvp[eventId];
    _myEventRsvp = {..._myEventRsvp, eventId: rsvp};
    notifyListeners();
    try {
      await SupabaseEventService.setMyRsvp(eventId, rsvp);
    } catch (_) {
      _myEventRsvp = {..._myEventRsvp};
      if (prev == null) {
        _myEventRsvp.remove(eventId);
      } else {
        _myEventRsvp[eventId] = prev;
      }
      notifyListeners();
    }
  }

  Future<void> setTripRsvp(String tripId, String rsvp) async {
    final prev = _myTripRsvp[tripId];
    _myTripRsvp = {..._myTripRsvp, tripId: rsvp};
    notifyListeners();
    try {
      await SupabaseTripService.setMyRsvp(tripId, rsvp);
    } catch (_) {
      _myTripRsvp = {..._myTripRsvp};
      if (prev == null) {
        _myTripRsvp.remove(tripId);
      } else {
        _myTripRsvp[tripId] = prev;
      }
      notifyListeners();
    }
  }

  // ── Criar ────────────────────────────────────────────────────
  Future<ClubModel?> create({
    required String name,
    String? description,
    String? city,
    String? stateUf,
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final club = await SupabaseClubService.createClub(
        name: name,
        description: description,
        city: city,
        stateUf: stateUf,
      );
      _myClubs = [club, ..._myClubs];
      _isSaving = false;
      notifyListeners();
      return club;
    } catch (e) {
      debugPrint('❌ ClubViewModel.create: $e');
      _saveError = DbErrors.mensagem(e,
          fallback: 'Não foi possível criar o motoclube. Tente novamente.');
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  // ── Convites ─────────────────────────────────────────────────
  Future<void> acceptInvite(String clubId) async {
    try {
      await SupabaseClubService.acceptInvite(clubId);
      _invites = _invites.where((c) => c.id != clubId).toList();
      await loadMine();
    } catch (_) {}
  }

  Future<void> declineInvite(String clubId) async {
    _invites = _invites.where((c) => c.id != clubId).toList();
    notifyListeners();
    try {
      await SupabaseClubService.declineInvite(clubId);
    } catch (_) {}
  }

  Future<bool> inviteUser(String clubId, String userId, String clubName) async {
    try {
      await SupabaseClubService.inviteUser(clubId, userId, clubName);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> leave(String clubId) async {
    try {
      await SupabaseClubService.leaveClub(clubId);
      _myClubs = _myClubs.where((c) => c.id != clubId).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeMember(String userId) async {
    final id = _selected?.id;
    if (id == null) return;
    try {
      await SupabaseClubService.removeMember(id, userId);
      _members = _members.where((m) => m.userId != userId).toList();
      _selected = _selected?.copyWith(membersCount: _members.length);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> deleteClub(String clubId) async {
    try {
      await SupabaseClubService.deleteClub(clubId);
      _myClubs = _myClubs.where((c) => c.id != clubId).toList();
      if (_selected?.id == clubId) _selected = null;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    _myClubs = [];
    _invites = [];
    _discover = [];
    _selected = null;
    _members = [];
    _clubEvents = [];
    _clubTrips = [];
    _myEventRsvp = {};
    _myTripRsvp = {};
    _isLoading = false;
    _isLoadingDetail = false;
    _isSaving = false;
    _saveError = null;
    notifyListeners();
  }
}
