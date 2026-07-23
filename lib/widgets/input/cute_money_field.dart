import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Money input: "đ" unit on the right, thousands separators added while typing.
///
/// While focused, shows a suggestion bar just above the keyboard: e.g. typing
/// "25" offers 25,000 / 250,000 / 2,500,000 for one-tap completion.
class CuteMoneyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const CuteMoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<CuteMoneyField> createState() => _CuteMoneyFieldState();
}

class _CuteMoneyFieldState extends State<CuteMoneyField> {
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onControllerChanged);
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onControllerChanged() => _overlayEntry?.markNeedsBuild();

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(builder: _buildSuggestionBar);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Digits currently in the field (thousands separators stripped).
  String get _rawDigits {
    final text = widget.controller.text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c.compareTo('0') >= 0 && c.compareTo('9') <= 0) buffer.write(c);
    }
    return buffer.toString();
  }

  List<int> _suggestions() {
    final raw = _rawDigits;
    if (raw.isEmpty) return const [];
    final base = int.tryParse(raw);
    if (base == null || base == 0) return const [];
    // Skip suggestions that already have too many trailing zeros to be useful.
    return [base * 1000, base * 10000, base * 100000];
  }

  void _applySuggestion(int value) {
    final formatted = _formatThousands(value.toString());
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onChanged?.call(formatted);
  }

  Widget _buildSuggestionBar(BuildContext overlayContext) {
    final suggestions = _suggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final mq = MediaQuery.of(overlayContext);
    final theme = Theme.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: mq.viewInsets.bottom,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final value = suggestions[index];
                return ActionChip(
                  label: Text('${_formatThousands(value.toString())} đ'),
                  onPressed: () => _applySuggestion(value),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CuteTextField(
      controller: widget.controller,
      focusNode: _focusNode,
      label: widget.label,
      hint: widget.hint,
      errorText: widget.errorText,
      suffixText: "đ",
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorInputFormatter()],
      onChanged: widget.onChanged,
      autofocus: widget.autofocus,
    );
  }
}

/// Formats an integer string with thousands separators (no decimals).
String _formatThousands(String intText) {
  final buffer = StringBuffer();
  for (var i = 0; i < intText.length; i++) {
    if (i > 0 && (intText.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intText[i]);
  }
  return buffer.toString();
}

/// Inserts thousands separators while typing, keeping the cursor in place.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Keep digits and at most one decimal point.
    final raw = StringBuffer();
    var seenDot = false;
    var rawCharsBeforeCursor = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      final isDigit = c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
      if (isDigit || (c == '.' && !seenDot)) {
        if (c == '.') seenDot = true;
        raw.write(c);
        if (i < newValue.selection.end) rawCharsBeforeCursor++;
      }
    }
    final rawText = raw.toString();
    if (rawText.isEmpty) return const TextEditingValue(text: '');

    final dotIndex = rawText.indexOf('.');
    final intPart = dotIndex < 0 ? rawText : rawText.substring(0, dotIndex);
    final decPart = dotIndex < 0 ? '' : rawText.substring(dotIndex);
    final formattedInt = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) formattedInt.write(',');
      formattedInt.write(intPart[i]);
    }
    final formatted = '$formattedInt$decPart';

    var cursor = 0;
    var seen = 0;
    while (cursor < formatted.length && seen < rawCharsBeforeCursor) {
      if (formatted[cursor] != ',') seen++;
      cursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
