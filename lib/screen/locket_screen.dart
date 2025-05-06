import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/locket_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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

  final _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profilePicture = appData.user?.profilePicture;
    final padding = EdgeInsets.symmetric(horizontal: 20);
    return Scaffold(
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
      body: SafeArea(
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final height = [constraints.maxWidth, Dimens.webMaxWidth - padding.horizontal].min;
            return Stack(
              children: [
                Selector<V, Uint8List?>(
                  selector: (p0, p1) => p1.croppedImage,
                  builder: (context, data, _) {
                    return Center(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20), //
                          color: context.theme.colorScheme.primary,
                        ),
                        height: height, //
                        child: data == null ? SizedBox.expand() : Image.memory(data),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: [
                      CarouselSlider(
                        carouselController: _carouselController,
                        options: CarouselOptions(
                          height: height, //
                          enlargeCenterPage: true,
                          viewportFraction: 1,
                          enlargeFactor: 0,
                          onPageChanged: (index, reason) {
                            vm.setOverlayIndex(index);
                          },
                        ),

                        items:
                            OverlayType.values.map((type) {
                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: context.colors.inputBadgeBg.withAlpha(180), //
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: switch (type) {
                                    OverlayType.standard => _buildCaptionOverlay(),
                                    OverlayType.review => _buildReviewOverlay(),
                                    // case OverlayType.music:
                                    // case OverlayType.location:
                                    // case OverlayType.weather:
                                    OverlayType.time => _buildTimeOverlay(),
                                  },
                                ),
                              );
                            }).toList(),
                      ),
                      Selector<V, int>(
                        selector: (p0, p1) => p1.overlayIndex,
                        builder: (context, overlayIndex, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children:
                                OverlayType.values.asMap().entries.map((entry) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.colors.inputBadgeBg.withAlpha(overlayIndex == entry.key ? 220 : 100),
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ).webConstrainedBox(),
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

  Widget _buildCaptionOverlay() {
    return Selector<V, String>(
      selector: (p0, p1) => p1.caption,
      builder: (context, caption, _) {
        return _buildCaptionInput(
          caption, //
          hintText: context.l10n.addMessage,
          onChanged: vm.onCaptionChanged,
        );
      },
    );
  }

  Widget _buildCaptionInput(
    String? caption, {
    void Function(String)? onChanged, //
    required String hintText,
  }) {
    return IntrinsicWidth(
      child: DoTextField(
        value: caption, //
        decoration: InputDecoration(
          isDense: true, // Remove the default content padding.
          contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          hintText: caption.isNullOrEmpty ? hintText : null, //
          border: InputBorder.none,
        ),
        textAlign: TextAlign.center,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReviewOverlay() {
    return Selector<V, (String, double)>(
      selector: (p0, p1) => (p1.reviewCaption, p1.reviewRating),
      builder: (context, data, _) {
        final caption = data.$1;
        final rating = data.$2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: rating,
              minRating: 0,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 20,
              glow: false,
              itemPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: vm.setReviewRating,
            ),
            if (rating > 0)
              _buildCaptionInput(
                caption, //
                hintText: context.l10n.writeReview,
                onChanged: vm.onReviewCaptionChanged,
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimeOverlay() {
    return Selector<V, DateTime?>(
      selector: (p0, p1) => p1.currentTime,
      builder: (context, currentTime, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timelapse), //
            SizedBox(width: 4),
            Text(
              currentTime.toStringFormat(DateTimeConst.HHmma),
              style: context.textTheme.primary.bold, //
            ),
          ],
        );
      },
    );
  }
}
