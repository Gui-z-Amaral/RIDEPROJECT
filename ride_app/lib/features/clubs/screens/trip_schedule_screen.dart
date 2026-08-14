import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Roteiro de uma viagem do clube (reusa EventScheduleItem). Admins editam;
/// os demais visualizam.
class TripScheduleScreen extends StatefulWidget {
  final String tripId;
  final String title;
  final bool canEdit;

  const TripScheduleScreen({
    super.key,
    required this.tripId,
    required this.title,
    required this.canEdit,
  });

  @override
  State<TripScheduleScreen> createState() => _TripScheduleScreenState();
}

class _TripScheduleScreenState extends State<TripScheduleScreen> {
  bool _loading = true;
  bool _saving = false;
  final List<_Item> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await SupabaseTripService.getSchedule(widget.tripId);
      _items
        ..clear()
        ..addAll(items.map((e) => _Item(
              time: e.timeLabel ?? '',
              title: e.title,
              desc: e.description ?? '',
            )));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _add() => setState(() => _items.add(_Item()));
  void _remove(int i) => setState(() => _items.removeAt(i));

  Future<void> _save() async {
    setState(() => _saving = true);
    final schedule = _items
        .where((i) => i.title.trim().isNotEmpty)
        .map((i) => EventScheduleItem(
              timeLabel: i.time.trim().isEmpty ? null : i.time.trim(),
              title: i.title.trim(),
              description: i.desc.trim().isEmpty ? null : i.desc.trim(),
            ))
        .toList();
    try {
      await SupabaseTripService.replaceSchedule(widget.tripId, schedule);
      if (mounted) {
        context.showSnack('Roteiro salvo!');
        context.pop();
      }
    } catch (_) {
      if (mounted) context.showSnack('Erro ao salvar roteiro.', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Roteiro',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.navy))
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 24),
              children: [
                Text(widget.title,
                    style: AppTextStyles.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                if (_items.isEmpty && !widget.canEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Roteiro ainda não definido',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textMuted)),
                    ),
                  ),
                ..._items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return widget.canEdit
                      ? _EditRow(
                          item: item,
                          onRemove: () => _remove(i),
                        )
                      : _ViewRow(item: item);
                }),
                if (widget.canEdit) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar parada'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: BorderSide(color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('SALVAR ROTEIRO',
                              style: AppTextStyles.labelLarge),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Item {
  String time;
  String title;
  String desc;
  _Item({this.time = '', this.title = '', this.desc = ''});
}

class _ViewRow extends StatelessWidget {
  final _Item item;
  const _ViewRow({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.time.isNotEmpty) ...[
            Text(item.time,
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.navy, fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                if (item.desc.isNotEmpty)
                  Text(item.desc,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final _Item item;
  final VoidCallback onRemove;
  const _EditRow({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: item.time,
                  onChanged: (v) => item.time = v,
                  style: AppTextStyles.bodyMedium,
                  decoration: _dec('14:00'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: item.title,
                  onChanged: (v) => item.title = v,
                  style: AppTextStyles.bodyMedium,
                  decoration: _dec('Parada / atividade'),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textMuted, size: 20),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: item.desc,
            onChanged: (v) => item.desc = v,
            style: AppTextStyles.bodyMedium,
            decoration: _dec('Detalhe (opcional)'),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );
}
