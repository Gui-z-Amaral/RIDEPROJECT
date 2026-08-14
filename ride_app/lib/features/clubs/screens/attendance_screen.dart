import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/club_model.dart';
import '../../../core/services/supabase_event_service.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Lista de presença de um evento ou viagem do clube. Mostra quem marcou
/// Vou / Talvez / Não vou; o líder (canCheckIn) pode marcar o check-in no dia.
class AttendanceScreen extends StatefulWidget {
  final bool isTrip;
  final String id;
  final String title;
  final bool canCheckIn;

  const AttendanceScreen({
    super.key,
    required this.isTrip,
    required this.id,
    required this.title,
    required this.canCheckIn,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  List<AttendanceEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = widget.isTrip
          ? await SupabaseTripService.getAttendance(widget.id)
          : await SupabaseEventService.getAttendance(widget.id);
      _entries = rows.map((r) => AttendanceEntry.fromMap(r)).toList();
    } catch (_) {
      _entries = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleCheckIn(AttendanceEntry e) async {
    final value = !e.checkedIn;
    setState(() {
      _entries = _entries
          .map((x) => x.userId == e.userId
              ? AttendanceEntry(
                  userId: x.userId,
                  rsvp: x.rsvp,
                  checkedIn: value,
                  user: x.user)
              : x)
          .toList();
    });
    try {
      if (widget.isTrip) {
        await SupabaseTripService.setCheckIn(widget.id, e.userId, value);
      } else {
        await SupabaseEventService.setCheckIn(widget.id, e.userId, value);
      }
    } catch (_) {
      if (mounted) _load(); // recarrega se falhar
    }
  }

  @override
  Widget build(BuildContext context) {
    final going = _entries.where((e) => e.rsvp == 'going').toList();
    final maybe = _entries.where((e) => e.rsvp == 'maybe').toList();
    final declined = _entries.where((e) => e.rsvp == 'declined').toList();
    final checkedIn = going.where((e) => e.checkedIn).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Presença',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.navy))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 40 + MediaQuery.of(context).padding.bottom),
              children: [
                Text(widget.title,
                    style: AppTextStyles.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${going.length} confirmados · $checkedIn presentes · '
                  '${maybe.length} talvez',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                if (_entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Ninguém marcou presença ainda',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textMuted)),
                    ),
                  ),
                _Group(
                    label: 'VÃO (${going.length})',
                    entries: going,
                    canCheckIn: widget.canCheckIn,
                    onToggle: _toggleCheckIn),
                _Group(
                    label: 'TALVEZ (${maybe.length})',
                    entries: maybe,
                    canCheckIn: false,
                    onToggle: _toggleCheckIn),
                _Group(
                    label: 'NÃO VÃO (${declined.length})',
                    entries: declined,
                    canCheckIn: false,
                    onToggle: _toggleCheckIn),
              ],
            ),
    );
  }
}

class _Group extends StatelessWidget {
  final String label;
  final List<AttendanceEntry> entries;
  final bool canCheckIn;
  final ValueChanged<AttendanceEntry> onToggle;
  const _Group({
    required this.label,
    required this.entries,
    required this.canCheckIn,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              )),
        ),
        ...entries.map((e) {
          final name = e.user?.name ?? 'Membro';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.navy.withOpacity(0.1),
              backgroundImage:
                  (e.user?.avatarUrl != null && e.user!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(e.user!.avatarUrl!)
                      : null,
              child: (e.user?.avatarUrl == null ||
                      (e.user?.avatarUrl?.isEmpty ?? true))
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.navy))
                  : null,
            ),
            title: Text(name, style: AppTextStyles.bodyMedium),
            trailing: canCheckIn
                ? IconButton(
                    icon: Icon(
                      e.checkedIn
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: e.checkedIn ? AppColors.success : AppColors.textMuted,
                    ),
                    tooltip: e.checkedIn ? 'Presente' : 'Marcar presença',
                    onPressed: () => onToggle(e),
                  )
                : (e.checkedIn
                    ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
                    : null),
          );
        }),
      ],
    );
  }
}
