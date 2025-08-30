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

class _HomeScreenState<V extends LocketViewModel> extends ScreenState<LocketScreen, V> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(
        height: kIsWeb ? 80 : 60,
        leadingWidth: 120,
        leading: Row(
          children: [
            SizedBox(width: 20),
            UserAvatar(
              onPressed: () {
                context.pushRoute(const AccountRoute());
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(child: _buildBody().webConstrainedBox()),
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
        if (!kIsWeb) SizedBox(height: 20),
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
                      width: height,
                      child: DoCamera(key: cameraKey, imgData: data, parentSize: height),
                    ),
                    if (data != null) _buildOverlays(context, height: height),
                  ],
                );
              },
            );
          },
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 20),
            IconButton(
              padding: EdgeInsets.all(4),
              icon: SFIcon(SFIcons.sf_photo),
              onPressed: () => vm.pickPhoto(), //
            ),
            IconButton(
              padding: EdgeInsets.all(4),
              icon: SFIcon(SFIcons.sf_video),
              onPressed: () => vm.pickVideo(), //
            ),
            Spacer(),
            IconButton(
              padding: EdgeInsets.all(4),
              icon: SFIcon(SFIcons.sf_pencil_tip_crop_circle), //
              onPressed: () => vm.colorPickerDialog(),
            ),
            SizedBox(width: 20),
          ],
        ),
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
                  if (!kIsWeb || (kIsWeb && !isCameraMode))
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
                  if (!kIsWeb)
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
                          cameraIcon: SFIcons.sf_arrow_trianglehead_2_clockwise_rotate_90,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
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
      icon: SFIcon(
        isCameraMode ? cameraIcon : icon,
        fontSize: 35, //
        color: cameraIconColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildActionButton({required bool isCameraMode, required bool isBusy}) {
    return SizedBox(
      width: 63,
      height: 63,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primaryContainer, //
                borderRadius: BorderRadius.circular(40),
              ),
              child:
                  isCameraMode
                      ? Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: context.colors.iconColor.withAlpha(250), //
                          borderRadius: BorderRadius.circular(40),
                        ),
                      )
                      : SFIcon(SFIcons.sf_paperplane, fontSize: 35),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isBusy ? null : () => isCameraMode ? vm.capture() : vm.startUpload(), //
              customBorder: CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
