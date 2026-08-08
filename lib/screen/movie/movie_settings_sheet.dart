import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:flutter/material.dart';

/// Quality / speed / rotation-lock sheet opened from the player controls.
class MovieSettingsSheet extends StatelessWidget {
  const MovieSettingsSheet({
    super.key,
    required this.selectedQuality,
    required this.availableQualities,
    required this.playbackSpeed,
    required this.isRotationLocked,
    required this.supportsOrientationManager,
    required this.onQualityChanged,
    required this.onSpeedChanged,
    required this.onRotationLockToggled,
  });

  final String selectedQuality;
  final List<MovieStreamVariant> availableQualities;
  final double playbackSpeed;
  final bool isRotationLocked;
  final bool supportsOrientationManager;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onRotationLockToggled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Bottom inset is added as empty space under the content instead, so the
      // sheet reaches the screen edge rather than being clipped above it.
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.high_quality_rounded),
              title: Text(l10n.resolutionQuality),
              subtitle: Text(selectedQuality),
              onTap: () {
                Navigator.pop(context);
                _showSelectionSheet<String>(
                  context,
                  l10n.resolutionQuality,
                  ['Auto', ...availableQualities.map((e) => e.label)],
                  selectedQuality,
                  onQualityChanged,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: Text(l10n.playbackSpeed),
              subtitle: Text('${playbackSpeed}x'),
              onTap: () {
                Navigator.pop(context);
                _showSelectionSheet<double>(
                  context,
                  l10n.playbackSpeed,
                  const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
                  playbackSpeed,
                  onSpeedChanged,
                  labelBuilder: (v) => v == 1.0 ? '1x' : '${v}x',
                );
              },
            ),
            if (supportsOrientationManager)
              ListTile(
                leading: Icon(isRotationLocked ? Icons.screen_lock_rotation_rounded : Icons.screen_rotation_rounded),
                title: Text(l10n.lockRotation),
                subtitle: Text(isRotationLocked ? l10n.lockRotation : l10n.unlockRotation),
                trailing: Switch(
                  value: isRotationLocked,
                  onChanged: (_) {
                    onRotationLockToggled();
                    Navigator.pop(context);
                  },
                ),
                onTap: () {
                  onRotationLockToggled();
                  Navigator.pop(context);
                },
              ),
            SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  void _showSelectionSheet<T>(
    BuildContext context,
    String title,
    List<T> options,
    T selectedValue,
    ValueChanged<T> onSelected, {
    String Function(T)? labelBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  // Scrolls through the bottom inset and ends on empty space.
                  padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option == selectedValue;
                    return ListTile(
                      title: Text(
                        labelBuilder?.call(option) ?? option.toString(),
                        style: TextStyle(color: isSelected ? Colors.pinkAccent : null, fontWeight: isSelected ? FontWeight.bold : null),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.pinkAccent) : null,
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
