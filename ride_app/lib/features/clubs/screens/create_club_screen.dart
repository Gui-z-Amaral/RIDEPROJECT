import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/club_viewmodel.dart';
import '../../../core/constants/text_limits.dart';

/// Cadastro de motoclube (qualquer usuário pode criar e vira dono).
class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _ufCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    final vm = context.read<ClubViewModel>();
    final club = await vm.create(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      stateUf: _ufCtrl.text.trim().isEmpty
          ? null
          : _ufCtrl.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    if (club != null) {
      context.showSnack('Motoclube criado!');
      context.pushReplacement('/clubs/${club.id}');
    } else {
      context.showSnack(vm.saveError ?? 'Erro ao criar clube', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
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
        title: Text('Novo Motoclube',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 24),
        children: [
          const _Label('NOME DO CLUBE'),
          _Input(
              controller: _nameCtrl,
              hint: 'Ex: Águias da Estrada',
              maxLength: TextLimits.clube),
          const SizedBox(height: 20),
          const _Label('DESCRIÇÃO'),
          _Input(
            controller: _descCtrl,
            hint: 'Sobre o clube, valores, região de atuação...',
            maxLines: 4,
            maxLength: TextLimits.clubeDesc,
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('CIDADE'),
                    _Input(
                        controller: _cityCtrl,
                        hint: 'Cidade',
                        maxLength: TextLimits.cidade),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('UF'),
                    _Input(
                        controller: _ufCtrl, hint: 'SC', textCapsUpper: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_canSave && !vm.isSaving) ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: vm.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('CRIAR CLUBE', style: AppTextStyles.labelLarge),
            ),
          ),
        ],
      ),
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
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          )),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final bool textCapsUpper;
  const _Input({
    required this.controller,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.textCapsUpper = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
        maxLength: maxLength,
        buildCounter: maxLines > 1
            ? null
            : (_, {required currentLength, required isFocused, maxLength}) =>
                null,
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapsUpper
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
