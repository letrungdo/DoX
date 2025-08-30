part of 'locket_screen.dart';

Widget _buildOverlays<V extends LocketViewModel>(BuildContext context, {required double height}) {
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
          items:
              OverlayType.options.map((type) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Theme(
                    data: AppTheme.lightTheme,
                    child: Selector<V, (Color, Color?)>(
                      selector: (p0, p1) => (p1.overlayTextColor, p1.overlayBgColor),
                      builder: (context, data, _) {
                        final textColor = data.$1;
                        final bgColor = type == OverlayType.standard ? data.$2 : null;
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 10),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical:
                                type == OverlayType.review
                                    ? 3
                                    : type == OverlayType.time
                                    ? 7
                                    : 8, //
                          ),
                          decoration: BoxDecoration(
                            color: bgColor ?? Colors.white.withAlpha(200), //
                            borderRadius: BorderRadius.circular(20),
                          ),
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
                  OverlayType.options.asMap().entries.map((entry) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(overlayIndex == entry.key ? 240 : 150),
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

Widget _buildCaptionOverlay<V extends LocketViewModel>(Color textColor) {
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
        hintStyle: TextStyle(color: textColor).regular,
      ),
      textAlign: TextAlign.center,
      textInputAction: textInputAction,
      onChanged: onChanged,
    ),
  );
}

Widget _buildReviewOverlay<V extends LocketViewModel>() {
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
            ),
        ],
      );
    },
  );
}

Widget _buildTimeOverlay<V extends LocketViewModel>() {
  return Selector<V, DateTime?>(
    selector: (p0, p1) => p1.currentTime,
    builder: (context, currentTime, _) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SFIcon(SFIcons.sf_clock, fontSize: 20, fontWeight: FontWeight.bold), //
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

Widget _buildWeatherOverlay<V extends LocketViewModel>() {
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
            ),
            SizedBox(width: 4),
            Text(
              (data.temperatureText).toDashIfNull,
              style: context.textTheme.primary.bold, //
            ),
          ],
        ],
      );
    },
  );
}

Widget _buildLocationOverlay<V extends LocketViewModel>() {
  return Selector<V, String?>(
    selector: (p0, p1) => p1.currentLocation,
    builder: (context, currentLocation, _) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on), //
          SizedBox(width: 4),
          currentLocation == null
              ? Loading(size: 20)
              : Flexible(
                child: Text(
                  currentLocation,
                  style: context.textTheme.primary.bold, //
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
      );
    },
  );
}
