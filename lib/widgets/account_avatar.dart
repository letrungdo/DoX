import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// The signed-in account's picture, falling back to the first letter of the
/// address when there is none.
///
/// The initial is not a placeholder for a missing image — most accounts will
/// never set a picture, so it is the normal state and has to look deliberate.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.email,
    this.avatarUrl,
    this.radius = 26,
    this.onTap,
  });

  final String email;
  final String? avatarUrl;
  final double radius;

  /// Adds the camera badge and makes the whole circle tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final url = avatarUrl;

    Widget circle = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      // Sized off the radius so one widget serves the 20px row in the menu and
      // the 34px header on the account page.
      child: url == null || url.isEmpty
          ? Text(
              email.isEmpty ? '?' : email.characters.first.toUpperCase(),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: radius * 0.85,
                fontWeight: FontWeight.w700,
              ),
            )
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                fadeInDuration: Durations.short3,
                errorWidget: (context, _, _) => Icon(
                  Icons.person_rounded,
                  size: radius,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
    );

    if (onTap == null) return circle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 14,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(customBorder: const CircleBorder(), onTap: onTap),
          ),
        ),
      ],
    );
  }
}
