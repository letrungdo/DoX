import 'package:do_x/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dialog bo góc lớn với icon SVG cute ở đầu, dùng chung cho các form nhập liệu.
class CuteDialog extends StatelessWidget {
  final SvgGenImage? icon;
  final String title;
  final Color accent;
  final List<Widget> children;
  final String? confirmText;
  final VoidCallback? onConfirm;
  final String cancelText;

  const CuteDialog({
    super.key,
    this.icon,
    required this.title,
    this.accent = const Color(0xFFFB8C00),
    this.children = const [],
    this.confirmText,
    this.onConfirm,
    this.cancelText = "Hủy",
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header scrolls together with the fields so the content keeps
              // its space when the keyboard shrinks the dialog.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (icon != null) ...[
                        Center(
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: accent.withValues(alpha: 0.12),
                            child: icon!.svg(width: 32, height: 32),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(cancelText),
                    ),
                  ),
                  if (confirmText != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: onConfirm,
                        child: Text(confirmText!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decoration bo tròn nền mềm dùng chung cho TextField/Dropdown trong dialog.
InputDecoration cuteInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
  String? prefixText,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border([BorderSide side = BorderSide.none]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: side);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(BorderSide(color: scheme.primary, width: 1.6)),
  );
}

class CuteTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;

  const CuteTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.keyboardType,
    this.maxLines = 1,
    this.style,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: style,
      onChanged: onChanged,
      decoration: cuteInputDecoration(context, label, hint: hint, prefixText: prefixText),
    );
  }
}

/// Ô chọn ngày cùng phong cách với [CuteTextField].
class CuteDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const CuteDateField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        // When empty, the label sits inline and acts as the placeholder —
        // rendering a placeholder child too would draw both on top of each other.
        isEmpty: value == null,
        decoration: cuteInputDecoration(context, label, suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20)),
        child: value == null ? const SizedBox.shrink() : Text(DateFormat('dd/MM/yyyy').format(value!)),
      ),
    );
  }
}
