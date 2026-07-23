import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:flutter/material.dart';

/// A note text field with a dropdown of previously used notes. Tapping the
/// dropdown icon lets the user pick a past note; they can still type manually.
class NoteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  /// Previously used notes, already de-duplicated and ordered by relevance.
  final List<String> suggestions;

  /// Cap on how many recent suggestions to list in the dropdown.
  final int maxSuggestions;

  const NoteField({
    super.key,
    required this.controller,
    required this.label,
    this.suggestions = const [],
    this.maxSuggestions = 15,
  });

  void _select(String note) {
    controller.value = TextEditingValue(
      text: note,
      selection: TextSelection.collapsed(offset: note.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = suggestions.take(maxSuggestions).toList();
    return CuteTextField(
      controller: controller,
      label: label,
      suffixIcon: items.isEmpty
          ? null
          : PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down),
              tooltip: '',
              position: PopupMenuPosition.under,
              onSelected: _select,
              itemBuilder: (_) => [
                for (final note in items)
                  PopupMenuItem<String>(value: note, child: Text(note)),
              ],
            ),
    );
  }
}
