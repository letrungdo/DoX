import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/store/app_data.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.onPressed, //
    this.size = const Size(58, 58),
  });
  final void Function()? onPressed;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final profilePicture = appData.user?.profilePicture;
    final radius = BorderRadius.circular(30);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.loose,
        children: [
          profilePicture == null
              ? Container(
                decoration: BoxDecoration(
                  color: Colors.grey, //
                  borderRadius: radius,
                ),
              )
              : CachedNetworkImage(
                imageUrl: profilePicture.withProxy(),
                fadeInDuration: Durations.medium1,
                imageBuilder:
                    (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(color: context.theme.primaryColor, width: 4),
                        image: DecorationImage(
                          image: imageProvider, //
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
              ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed, //
              customBorder: CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
