import 'package:flutter/material.dart';

/// Single-choice option group rendered as wrapping tags, highlighted with the
/// app's primary color.
class CuteSegmentedButton<T> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  const CuteSegmentedButton({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final segment in segments)
          _buildTag(context, scheme, segment, segment.value == value),
      ],
    );
  }

  Widget _buildTag(
    BuildContext context,
    ColorScheme scheme,
    ButtonSegment<T> segment,
    bool selected,
  ) {
    final foreground = selected ? scheme.onTertiary : scheme.onSurface;
    return Material(
      color: selected ? scheme.tertiary : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(segment.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: foreground, size: 18),
              child: segment.label ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
