import 'package:do_x/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// What the settings sheet was closed with. Quality and speed each open a
/// follow-up picker, which the caller shows against its own context — the
/// sheet's is gone the moment it pops.
enum MovieSettingsAction { quality, speed }

/// Quality / speed / rotation-lock sheet opened from the player controls.
///
/// Meant to be shown through `showAppBottomSheet`, which supplies the shared
/// surface (drag handle, radius, insets), so this builds only the rows.
class MovieSettingsSheet extends StatelessWidget {
  const MovieSettingsSheet({
    super.key,
    required this.selectedQuality,
    required this.playbackSpeed,
    required this.isRotationLocked,
    required this.supportsOrientationManager,
    required this.onRotationLockToggled,
  });

  final String selectedQuality;
  final double playbackSpeed;
  final bool isRotationLocked;
  final bool supportsOrientationManager;
  final VoidCallback onRotationLockToggled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.high_quality_rounded),
          title: Text(l10n.resolutionQuality),
          subtitle: Text(selectedQuality),
          onTap: () => Navigator.pop(context, MovieSettingsAction.quality),
        ),
        ListTile(
          leading: const Icon(Icons.speed_rounded),
          title: Text(l10n.playbackSpeed),
          subtitle: Text('${playbackSpeed}x'),
          onTap: () => Navigator.pop(context, MovieSettingsAction.speed),
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
      ],
    );
  }
}
