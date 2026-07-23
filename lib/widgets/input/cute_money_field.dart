import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Money input: "đ" unit on the right, thousands separators added while typing.
///
/// When [showSuggestions] is true, a bar above the keyboard offers one-tap
/// amounts while the field is focused, capped at 50 million:
/// - empty field: the [presetSuggestions] for this field (e.g. chick prices),
/// - after typing: length-aware completions, e.g. "25" -> 25k / 250k / 2.5tr,
///   suppressed once the typed number already looks full (5+ digits).
class CuteMoneyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Whether to show the one-tap suggestion bar above the keyboard.
  final bool showSuggestions;

  /// Amounts offered while the field is still empty. Use to seed
  /// context-specific defaults (e.g. chick prices vs. adult-bird prices).
  final List<int>? presetSuggestions;

  const CuteMoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.autofocus = false,
    this.showSuggestions = true,
    this.presetSuggestions,
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
    if (_focusNode.hasFocus && widget.showSuggestions) {
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

  /// Suggestions never exceed 50 million.
  static const int _maxSuggestion = 50000000;

  /// Completions smaller than this are too noisy to offer (e.g. "2.5k").
  static const int _minSuggestion = 10000;

  List<int> _suggestions() {
    final raw = _rawDigits;
    // Nothing typed yet: offer this field's preset amounts.
    if (raw.isEmpty) {
      final presets = widget.presetSuggestions;
      if (presets == null) return const [];
      return presets.where((v) => v <= _maxSuggestion).toList();
    }
    final base = int.tryParse(raw);
    if (base == null || base == 0) return const [];
    // Offer round "×10" completions above what's typed, e.g. "25" -> 25k/250k/
    // 2.5tr, "10000" -> 100k/1tr/10tr. Bounded to [10k, 50tr], so the list
    // stays short (at most a handful of chips) whatever the input length.
    final result = <int>[];
    for (var value = base * 10; value <= _maxSuggestion; value *= 10) {
      if (value >= _minSuggestion) result.add(value);
    }
    return result;
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
                  label: Text(_formatCompact(value)),
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
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

/// Compact money label for chips: 25,000 -> "25k", 1,500,000 -> "1.5tr".
String _formatCompact(int value) {
  if (value >= 1000000) return '${_trimZeros(value / 1000000)}tr';
  if (value >= 1000) return '${_trimZeros(value / 1000)}k';
  return value.toString();
}

/// "1.0" -> "1", "1.5" -> "1.5" (drops a trailing ".0").
String _trimZeros(double v) {
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
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

/// Strips leading zeros from a plain integer field: "01" -> "1", "00" -> "0".
/// Pair it after [FilteringTextInputFormatter.digitsOnly] on quantity inputs.
class NoLeadingZeroInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final stripped = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (stripped == text) return newValue;
    final removed = text.length - stripped.length;
    var offset = newValue.selection.end - removed;
    offset = offset.clamp(0, stripped.length);
    return TextEditingValue(
      text: stripped,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
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
    final rawInt = dotIndex < 0 ? rawText : rawText.substring(0, dotIndex);
    final decPart = dotIndex < 0 ? '' : rawText.substring(dotIndex);
    // Drop leading zeros: "01" -> "1", "00" -> "0" (keep a single leading 0 so
    // "0.5" still works). Shift the cursor back past any zeros we removed.
    final intPart = rawInt.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final removedZeros = rawInt.length - intPart.length;
    if (removedZeros > 0) {
      rawCharsBeforeCursor = rawCharsBeforeCursor > removedZeros
          ? rawCharsBeforeCursor - removedZeros
          : 0;
    }
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
