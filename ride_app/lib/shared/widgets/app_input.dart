import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class AppInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool autofocus;

  const AppInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!,
              style: AppTextStyles.titleSmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          readOnly: readOnly,
          onTap: onTap,
          focusNode: focusNode,
          textInputAction: textInputAction,
          autofocus: autofocus,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: AppSpacing.iconMd,
                    color: AppColors.textMuted)
                : null,
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: suffix,
                  )
                : null,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

class AppSearchInput extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const AppSearchInput({
    super.key,
    this.controller,
    this.hint = 'Buscar...',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: AppSpacing.iconMd,
            color: AppColors.textMuted),
        suffixIcon: controller != null && (controller!.text.isNotEmpty)
            ? GestureDetector(
                onTap: () {
                  controller!.clear();
                  onClear?.call();
                },
                child: const Icon(Icons.close, size: 18,
                    color: AppColors.textMuted),
              )
            : null,
      ),
    );
  }
}
