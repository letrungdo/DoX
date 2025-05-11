import 'package:auto_route/auto_route.dart';
import 'package:camera/camera.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:collection/collection.dart';
import 'package:do_x/constants/date_time.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/date_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/weather_data.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/locket/locket_view_model.dart';
import 'package:do_x/view_model/locket/weather.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/do_camera.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/rating_bar.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:do_x/widgets/user_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:provider/provider.dart';

part 'overlays.part.dart';

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
    return Scaffold(
      appBar: DoAppBar(
        height: 60,
        leadingWidth: 76,
        leading: Padding(
          padding: EdgeInsets.only(left: 20),
          child: UserAvatar(
            onPressed: () {
              context.pushRoute(const AccountRoute());
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(child: _buildBody()),
            Positioned(
              top: 7,
              left: 0,
              right: 0,
              child: Selector<V, bool>(
                selector: (p0, p1) => p1.isBusy,
                builder: (context, isLoading, _) {
                  return Visibility(
                    visible: isLoading, //
                    child: LinearProgressIndicator(),
                  );
                },
              ),
            ),
          ],
        ), //
      ),
    );
  }

  Widget _buildBody() {
    final cameraKey = vm.cameraKey;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final height = [constraints.maxWidth, Dimens.webMaxWidth].min;
            return Selector<V, Uint8List?>(
              selector: (p0, p1) => p1.croppedImage,
              builder: (context, data, _) {
                return Stack(
                  children: [
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60), //
                        color: context.theme.scaffoldBackgroundColor,
                      ),
                      height: height, //
                      child: DoCamera(key: cameraKey, imgData: data),
                    ),
                    if (data != null) _buildOverlays(context, height: height),
                  ],
                );
              },
            );
          },
        ).webConstrainedBox(),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 20),
            IconButton(
              icon: SFIcon(SFIcons.sf_photo),
              onPressed: () => vm.pickPhoto(), //
            ),
            IconButton(
              icon: SFIcon(SFIcons.sf_video),
              onPressed: () => vm.pickVideo(), //
            ),
          ],
        ),
        SizedBox(height: 32),
        Selector<V, (bool, Uint8List?, FlashMode)>(
          selector: (p0, p1) => (p1.isBusy, p1.croppedImage, p1.flashMode),
          builder: (context, data, _) {
            final isBusy = data.$1;
            final isCameraMode = data.$2 == null;
            final flashMode = data.$3;

            return SizedBox(
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _iconButton(
                        isCameraMode: isCameraMode,
                        action: vm.cancelUpload,
                        cameraAction: vm.toggleFlash,
                        icon: SFIcons.sf_xmark,
                        cameraIcon: flashMode == FlashMode.off ? SFIcons.sf_bolt : SFIcons.sf_bolt_fill,
                        cameraIconColor: flashMode == FlashMode.always ? Colors.amber : null,
                      ),
                    ),
                  ),
                  Center(
                    child: _buildActionButton(
                      isBusy: isBusy,
                      isCameraMode: isCameraMode, //
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _iconButton(
                        isCameraMode: isCameraMode,
                        action: vm.showOverlaysModal,
                        cameraAction: vm.switchCamera,
                        icon: SFIcons.sf_wand_and_rays,
                        cameraIcon: SFIcons.sf_arrow_triangle_2_circlepath_circle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _iconButton({
    double size = 55,
    required bool isCameraMode,
    required void Function() action,
    required void Function() cameraAction,
    required IconData icon,
    required IconData cameraIcon,
    Color? cameraIconColor,
  }) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size, maxWidth: size, minHeight: size, maxHeight: size),
      onPressed: () => isCameraMode ? cameraAction.call() : action.call(), //
      icon: SFIcon(isCameraMode ? cameraIcon : icon, fontSize: 35, color: cameraIconColor),
    );
  }

  Widget _buildActionButton({required bool isCameraMode, required bool isBusy}) {
    return DoButton(
      onPressed: isBusy ? null : () => isCameraMode ? vm.capture() : vm.startUpload(), //
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.all(isCameraMode ? 8 : 15)), //
        backgroundColor: WidgetStatePropertyAll(context.theme.colorScheme.primaryContainer),
      ),
      child:
          isCameraMode
              ? Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: context.colors.iconColor.withAlpha(250), //
                  borderRadius: BorderRadius.circular(40),
                ),
              )
              : SFIcon(SFIcons.sf_paperplane, fontSize: 35),
    );
  }
}
