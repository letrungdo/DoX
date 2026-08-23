import 'package:do_x/model/news/news_source.dart';
import 'package:json_annotation/json_annotation.dart';

part 'storm_news.g.dart';

/// How urgent the bulletin is, which is all the card needs to pick its colour.
enum StormSeverity { watch, warning, emergency }

/// The storm bulletin, built by the `summarize-storm-news` edge function and
/// read straight off the single-row `storm_news` table.
///
/// Unlike the gold digest there is usually nothing to show: [active] is false
/// whenever no storm is affecting Vietnam, and the app then draws no card at
/// all. [isCurrent] is the second half of that rule — a bulletin the server
/// stopped refreshing is treated as "nothing to show" rather than kept on
/// screen for days.
@JsonSerializable(explicitToJson: true)
class StormNews {
  final bool active;

  final DateTime date;

  @JsonKey(name: 'name_vi')
  final String? nameVi;

  @JsonKey(name: 'name_en')
  final String? nameEn;

  @JsonKey(unknownEnumValue: StormSeverity.watch)
  final StormSeverity severity;

  @JsonKey(name: 'headline_vi')
  final String? headlineVi;

  @JsonKey(name: 'headline_en')
  final String? headlineEn;

  @JsonKey(name: 'summary_vi')
  final String? summaryVi;

  @JsonKey(name: 'summary_en')
  final String? summaryEn;

  @JsonKey(name: 'advice_vi')
  final String? adviceVi;

  @JsonKey(name: 'advice_en')
  final String? adviceEn;

  final List<StormNewsHighlight> highlights;
  final List<NewsSource> sources;

  /// When the server last rebuilt this bulletin, in UTC.
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const StormNews({
    required this.date,
    this.active = false,
    this.nameVi,
    this.nameEn,
    this.severity = StormSeverity.watch,
    this.headlineVi,
    this.headlineEn,
    this.summaryVi,
    this.summaryEn,
    this.adviceVi,
    this.adviceEn,
    this.highlights = const [],
    this.sources = const [],
    this.updatedAt,
  });

  factory StormNews.fromJson(Map<String, dynamic> json) =>
      _$StormNewsFromJson(json);

  Map<String, dynamic> toJson() => _$StormNewsToJson(this);

  /// The cron rebuilds the bulletin every three hours. Past this age we can no
  /// longer tell whether the storm is still out there, and a warning nobody is
  /// updating is worse than no warning at all.
  static const _maxAge = Duration(hours: 12);

  bool get isCurrent {
    final updatedAt = this.updatedAt;
    if (updatedAt == null) return false;
    return DateTime.now().toUtc().difference(updatedAt.toUtc()) < _maxAge;
  }

  /// True only when there is a live storm *and* the text to describe it.
  bool get shouldShow =>
      active && isCurrent && (summaryVi?.isNotEmpty ?? false);

  String name(String languageCode) => _pick(nameVi, nameEn, languageCode) ?? '';

  String summary(String languageCode) =>
      _pick(summaryVi, summaryEn, languageCode) ?? '';

  String? headline(String languageCode) =>
      _pick(headlineVi, headlineEn, languageCode);

  String? advice(String languageCode) =>
      _pick(adviceVi, adviceEn, languageCode);

  /// The article a highlight was drawn from, or null when the model cited an
  /// index we could not resolve.
  NewsSource? sourceOf(StormNewsHighlight highlight) {
    final index = highlight.sourceIndex;
    if (index == null || index < 0 || index >= sources.length) return null;
    return sources[index];
  }

  /// Either language can come back empty when the model had nothing to say, so
  /// an empty string falls back to the other one rather than to blank text.
  static String? _pick(String? vi, String? en, String languageCode) {
    final viText = (vi?.isEmpty ?? true) ? null : vi;
    final enText = (en?.isEmpty ?? true) ? null : en;
    if (viText == null || enText == null) return viText ?? enText;
    return localizedText(viText, enText, languageCode);
  }
}

@JsonSerializable()
class StormNewsHighlight {
  @JsonKey(name: 'title_vi')
  final String titleVi;

  @JsonKey(name: 'title_en')
  final String titleEn;

  @JsonKey(name: 'detail_vi')
  final String detailVi;

  @JsonKey(name: 'detail_en')
  final String detailEn;

  @JsonKey(name: 'source_index')
  final int? sourceIndex;

  const StormNewsHighlight({
    required this.titleVi,
    required this.titleEn,
    required this.detailVi,
    required this.detailEn,
    this.sourceIndex,
  });

  factory StormNewsHighlight.fromJson(Map<String, dynamic> json) =>
      _$StormNewsHighlightFromJson(json);

  Map<String, dynamic> toJson() => _$StormNewsHighlightToJson(this);

  String title(String languageCode) =>
      localizedText(titleVi, titleEn, languageCode);

  String detail(String languageCode) =>
      localizedText(detailVi, detailEn, languageCode);
}
