import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/club_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/club_viewmodel.dart';

/// Gerenciar membros do motoclube.
/// - Dono: promove/rebaixa gerentes e expulsa qualquer um (menos ele mesmo).
/// - Gerente: expulsa apenas membros comuns.
class ManageMembersScreen extends StatefulWidget {
  final String clubId;
  const ManageMembersScreen({super.key, required this.clubId});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ClubViewModel>().refreshMembers());
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Confirmar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
    final club = vm.selected;
    final isOwner = club?.isOwner ?? false;
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
        title: Text('Gerenciar membros',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 24),
        itemCount: vm.members.length,
        separatorBuilder: (_, __) => Divider(color: AppColors.divider, height: 1),
        itemBuilder: (_, i) {
          final m = vm.members[i];
          return _ManageTile(
            member: m,
            isOwner: isOwner,
            onPromote: () async {
              await context
                  .read<ClubViewModel>()
                  .setMemberRole(m.userId, 'admin');
            },
            onDemote: () async {
              await context
                  .read<ClubViewModel>()
                  .setMemberRole(m.userId, 'member');
            },
            onExpel: () async {
              final name = m.user?.name ?? 'este membro';
              final ok = await _confirm('Expulsar membro',
                  'Remover $name do clube?');
              if (ok && context.mounted) {
                await context.read<ClubViewModel>().removeMember(m.userId);
              }
            },
          );
        },
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  final ClubMemberModel member;
  final bool isOwner;
  final Future<void> Function() onPromote;
  final Future<void> Function() onDemote;
  final Future<void> Function() onExpel;

  const _ManageTile({
    required this.member,
    required this.isOwner,
    required this.onPromote,
    required this.onDemote,
    required this.onExpel,
  });

  @override
  Widget build(BuildContext context) {
    final u = member.user;
    final name = u?.name ?? 'Membro';
    final isTargetOwner = member.isOwner;
    final isTargetManager = member.isAdmin; // owner ou gerente

    // Ações disponíveis conforme quem está vendo:
    // - Dono: promove/rebaixa gerentes (não o dono) e expulsa qualquer um menos o dono.
    // - Gerente: expulsa só membros comuns.
    final options = <_Action>[];
    if (!isTargetOwner) {
      if (isOwner) {
        if (isTargetManager) {
          options.add(_Action('demote', 'Remover gerente'));
        } else {
          options.add(_Action('promote', 'Tornar gerente'));
        }
        options.add(_Action('expel', 'Expulsar', danger: true));
      } else {
        // gerente: só expulsa membro comum (não outro gerente)
        if (!isTargetManager) {
          options.add(_Action('expel', 'Expulsar', danger: true));
        }
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.navy.withOpacity(0.1),
        backgroundImage: (u?.avatarUrl != null && u!.avatarUrl!.isNotEmpty)
            ? NetworkImage(u.avatarUrl!)
            : null,
        child: (u?.avatarUrl == null || (u?.avatarUrl?.isEmpty ?? true))
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.navy))
            : null,
      ),
      title: Text(name, style: AppTextStyles.bodyMedium),
      subtitle: member.isAdmin
          ? Text(member.isOwner ? 'Dono' : 'Gerente',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.navy, fontWeight: FontWeight.w700))
          : Text('Membro',
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
      trailing: options.isEmpty
          ? null
          : PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textMuted),
              onSelected: (v) {
                if (v == 'promote') onPromote();
                if (v == 'demote') onDemote();
                if (v == 'expel') onExpel();
              },
              itemBuilder: (_) => options
                  .map((a) => PopupMenuItem(
                        value: a.value,
                        child: Text(a.label,
                            style: a.danger
                                ? TextStyle(color: AppColors.error)
                                : null),
                      ))
                  .toList(),
            ),
    );
  }
}

class _Action {
  final String value;
  final String label;
  final bool danger;
  const _Action(this.value, this.label, {this.danger = false});
}
