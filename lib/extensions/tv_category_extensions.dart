import 'package:do_x/l10n/app_localizations.dart';

/// The channel categories `iptv-org` files its playlists under, translated.
///
/// The playlist writes them in English whatever the user's language is, so the
/// filter chips would otherwise read `Entertainment` next to a Vietnamese page.
/// The set is upstream's fixed list; anything outside it — a category added to
/// the catalogue after this shipped — falls back to what the playlist said,
/// which is still better than an empty chip.
String tvCategoryLabel(String category, AppLocalizations l10n) =>
    switch (category.trim().toLowerCase()) {
      'animation' => l10n.tvCategoryAnimation,
      'auto' => l10n.tvCategoryAuto,
      'business' => l10n.tvCategoryBusiness,
      'classic' => l10n.tvCategoryClassic,
      'comedy' => l10n.tvCategoryComedy,
      'cooking' => l10n.tvCategoryCooking,
      'culture' => l10n.tvCategoryCulture,
      'documentary' => l10n.tvCategoryDocumentary,
      'education' => l10n.tvCategoryEducation,
      'entertainment' => l10n.tvCategoryEntertainment,
      'family' => l10n.tvCategoryFamily,
      'general' => l10n.tvCategoryGeneral,
      'kids' => l10n.tvCategoryKids,
      'legislative' => l10n.tvCategoryLegislative,
      'lifestyle' => l10n.tvCategoryLifestyle,
      'movies' => l10n.tvCategoryMovies,
      'music' => l10n.tvCategoryMusic,
      'news' => l10n.tvCategoryNews,
      'outdoor' => l10n.tvCategoryOutdoor,
      'relax' => l10n.tvCategoryRelax,
      'religious' => l10n.tvCategoryReligious,
      'science' => l10n.tvCategoryScience,
      'series' => l10n.tvCategorySeries,
      'shop' => l10n.tvCategoryShop,
      'sports' => l10n.tvCategorySports,
      'travel' => l10n.tvCategoryTravel,
      'weather' => l10n.tvCategoryWeather,
      // Upstream's word for a channel it has not categorised, not a label to
      // show a user.
      'undefined' => l10n.tvGroupOther,
      _ => category,
    };
