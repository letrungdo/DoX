import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/locket_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class LocketScreen extends StatefulScreen implements AutoRouteWrapper {
  const LocketScreen({super.key});

  @override
  State<LocketScreen> createState() => _HomeScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocketViewModel(), //
      child: this,
    );
  }
}

class _HomeScreenState<V extends LocketViewModel> extends ScreenState<LocketScreen, V> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profilePicture = appData.user?.profilePicture;
    final padding = EdgeInsets.symmetric(horizontal: 20);
    return AppScaffold(
      appBar: DoAppBar(
        height: 60,
        leadingWidth: 70,
        leading:
            profilePicture != null
                ? CachedNetworkImage(
                  imageUrl: profilePicture,
                  fadeInDuration: Durations.medium1,
                  imageBuilder:
                      (context, imageProvider) => Container(
                        margin: EdgeInsets.only(left: 20, top: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          image: DecorationImage(
                            image: imageProvider, //
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                )
                : null,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: padding, //
              child: _buildBody(padding),
            ),
            Positioned(
              top: 7,
              left: 0,
              right: 0,
              child: Selector<V, bool>(
                selector: (p0, p1) => p1.isBusy,
                builder: (context, isLoading, _) {
                  return Visibility(
                    visible: isLoading, //
                    child: LinearProgressIndicator(
                      // backgroundColor: Colors.grey.withValues(alpha: 0.5), //
                    ),
                  );
                },
              ),
            ),
          ],
        ), //
      ),
    );
  }

  Widget _buildBody(EdgeInsets padding) {
    return Column(
      children: [
        SizedBox(height: 20),
        Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Selector<V, Uint8List?>(
                  selector: (p0, p1) => p1.croppedImage,
                  builder: (context, data, _) {
                    return Center(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20), //
                          color: context.theme.colorScheme.primary,
                        ),
                        height: [constraints.maxWidth, Dimens.webMaxWidth - padding.horizontal].min, //
                        child: data == null ? SizedBox.expand() : Image.memory(data),
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              bottom: 10,
              left: 20,
              right: 20,
              child: Selector<V, String?>(
                selector: (p0, p1) => p1.caption,
                builder: (context, caption, _) {
                  return Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.inputBadgeBg.withAlpha(180), //
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IntrinsicWidth(
                        child: DoTextField(
                          value: caption, //
                          decoration: InputDecoration(
                            isDense: true, // Remove the default content padding.
                            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            hintText: caption.isNullOrEmpty ? "Input your caption" : null, //
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: vm.onCaptionChanged,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        SizedBox(height: 10),

        Selector<V, (bool, bool)>(
          selector: (p0, p1) => (p1.isBusy || p1.isPickingFile, p1.isCompressingVideo),
          builder: (context, data, _) {
            final isBusy = data.$1;
            final isCompressingVideo = data.$2;

            return DoButton(
              isBusy: isBusy,
              onPressed: () => isCompressingVideo ? vm.cancelCompressVideo() : vm.pickMedia(), //
              text: isCompressingVideo ? "Cancel" : 'Select Media',
            );
          },
        ),
        SizedBox(height: 32),
        Selector<V, bool>(
          selector: (p0, p1) => p1.isBusy || p1.croppedImage == null || p1.isCompressingVideo,
          builder: (context, isDisable, _) {
            return DoButton(
              onPressed: isDisable ? null : () => vm.startUpload(), //
              text: 'Upload',
            );
          },
        ),
        SizedBox(height: 10),

        Selector<V, (bool, double)>(
          selector: (p0, p1) => (p1.isCompressingVideo, p1.compressVideoProgress),
          builder: (context, data, _) {
            if (data.$1) return Text("Compressing Video: ${data.$2.toStringAsFixed(1)}");
            return SizedBox.shrink();
          },
        ),

        SizedBox(height: 20),
      ],
    );
  }
}
