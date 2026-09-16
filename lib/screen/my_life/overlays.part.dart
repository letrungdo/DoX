part of 'my_life_screen.dart';

Widget _buildOverlays<V extends MyLifeViewModel>(
  BuildContext context, {
  required double height,
}) {
  return Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Column(
      children: [
        CarouselSlider(
          carouselController: context.read<V>().carouselController,
          options: CarouselOptions(
            height: height, //
            enlargeCenterPage: true,
            viewportFraction: 1,
            enlargeFactor: 0,
            onPageChanged: (index, reason) {
              context.read<V>().setOverlayIndex(index);
            },
          ),
          items: OverlayType.options.map((type) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: Selector<V, (Color, Color?)>(
                selector: (p0, p1) => (p1.overlayTextColor, p1.overlayBgColor),
                builder: (context, data, _) {
                  // Only the text overlay takes a picked color; the rest carry
                  // the fixed palette the moment API draws them with.
                  final custom = type == OverlayType.standard ? data.$2 : null;
                  final textColor = custom == null
                      ? (type == OverlayType.weather
                            ? OverlayStyle.weatherText
                            : OverlayStyle.text)
                      : data.$1;
                  return _overlayBadge(
                    background: custom,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: type == OverlayType.review ? 4 : 9,
                    ),
                    textColor: textColor,
                    child: switch (type) {
                      OverlayType.standard => _buildCaptionOverlay(textColor),
                      OverlayType.review => _buildReviewOverlay(),
                      // OverlayType.music =>
                      OverlayType.location => _buildLocationOverlay(),
                      OverlayType.weather => _buildWeatherOverlay(),
                      OverlayType.time => _buildTimeOverlay(),
                    },
                  );
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
              children: OverlayType.options.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(
                      overlayIndex == entry.key ? 240 : 150,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}

/// The pill a caption overlay is drawn in.
///
/// With no color picked this is what the moment API calls a `material_blur`
/// surface: the photo behind it, blurred and darkened, with light text on top.
/// A picked [background] replaces the blur with a solid fill - it arrives
/// already paired with a [textColor] that can be read on it.
Widget _overlayBadge({
  required Color? background,
  required Color textColor,
  required EdgeInsets padding,
  required Widget child,
}) {
  final radius = BorderRadius.circular(Dimens.radiusPanel);
  return Container(
    margin: EdgeInsets.symmetric(horizontal: Dimens.pagePadding),
    // The shadow is what separates the badge from a bright photo; the blur
    // alone disappears against an overexposed sky.
    decoration: BoxDecoration(
      borderRadius: radius,
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: OverlayStyle.blurSigma,
          sigmaY: OverlayStyle.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background ?? OverlayStyle.blurTint,
            borderRadius: radius,
            border: Border.all(color: OverlayStyle.edge),
          ),
          child: Padding(
            padding: padding,
            // Every overlay's text and icons inherit from here, so a picked
            // color reaches all of them without being threaded through each.
            child: IconTheme.merge(
              data: IconThemeData(color: textColor, size: 20),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: textColor).bold,
                textAlign: TextAlign.center,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Overlay content keeps the app's type scale but takes its color from the
/// badge it sits in, so a picked color reaches every overlay alike.
TextStyle _overlayText(BuildContext context) => context.textTheme.primary.bold
    .textColor(DefaultTextStyle.of(context).style.color ?? OverlayStyle.text);

Widget _buildCaptionOverlay<V extends MyLifeViewModel>(Color textColor) {
  return Selector<V, String>(
    selector: (p0, p1) => p1.caption,
    builder: (context, caption, _) {
      return _buildCaptionInput(
        caption, //
        hintText: context.l10n.addMessage,
        onChanged: context.read<V>().onCaptionChanged,
        textColor: textColor,
      );
    },
  );
}

Widget _buildCaptionInput(
  String? caption, {
  void Function(String)? onChanged, //
  required String hintText,
  int? maxLength,
  TextInputAction? textInputAction,
  Color? textColor,
}) {
  return IntrinsicWidth(
    child: DoTextField(
      value: caption, //
      maxLines: null,
      maxLength: maxLength,
      style: TextStyle(color: textColor).bold,
      decoration: InputDecoration(
        isDense: true, // Remove the default content padding.
        contentPadding: EdgeInsets.symmetric(horizontal: 5),
        hintText: caption.isNullOrEmpty ? hintText : null, //
        border: InputBorder.none,
        counterText: "",
        hintStyle: TextStyle(color: textColor?.withValues(alpha: 0.55)).regular,
      ),
      textAlign: TextAlign.center,
      textInputAction: textInputAction,
      onChanged: onChanged,
    ),
  );
}

Widget _buildReviewOverlay<V extends MyLifeViewModel>() {
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
            itemPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: context.read<V>().setReviewRating,
          ),
          if (rating > 0)
            _buildCaptionInput(
              caption, //
              hintText: context.l10n.writeReview,
              onChanged: context.read<V>().onReviewCaptionChanged,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              textColor: DefaultTextStyle.of(context).style.color,
            ),
        ],
      );
    },
  );
}

Widget _buildTimeOverlay<V extends MyLifeViewModel>() {
  return Selector<V, DateTime?>(
    selector: (p0, p1) => p1.currentTime,
    builder: (context, currentTime, _) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SFIcon(
            SFIcons.sf_clock,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: OverlayStyle.timeIcon,
          ), //
          SizedBox(width: 6),
          Text(
            currentTime.toStringFormat(DateTimeConst.HHmma),
            style: _overlayText(context), //
          ),
        ],
      );
    },
  );
}

Widget _buildWeatherOverlay<V extends MyLifeViewModel>() {
  return Selector<V, CurrentWeather?>(
    selector: (p0, p1) => p1.weatherData,
    builder: (context, data, _) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data == null) Loading(size: 20),
          if (data != null) ...[
            SFIcon(
              wmoWeatherInfos[data.weatherCode].getIcon(data.isDaylight),
              fontSize: 20,
              fontWeight: FontWeight.bold, //
              color: OverlayStyle.weatherIcon,
            ),
            SizedBox(width: 6),
            Text(
              (data.temperatureText).toDashIfNull,
              style: _overlayText(context), //
            ),
          ],
        ],
      );
    },
  );
}

Widget _buildLocationOverlay<V extends MyLifeViewModel>() {
  return Selector<V, String?>(
    selector: (p0, p1) => p1.currentLocation,
    builder: (context, currentLocation, _) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: OverlayStyle.locationIcon), //
          SizedBox(width: 6),
          currentLocation == null
              ? Loading(size: 20)
              : Flexible(
                  child: Text(
                    currentLocation,
                    style: _overlayText(context), //
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ],
      );
    },
  );
}
