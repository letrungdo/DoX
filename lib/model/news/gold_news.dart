import 'package:do_x/model/news/news_source.dart';
import 'package:json_annotation/json_annotation.dart';

part 'gold_news.g.dart';

/// Which way a piece of news pushes the gold price.
enum GoldImpact { up, down, neutral }

/// One day's AI-written digest of the news moving the gold price. Built by the
/// `summarize-gold-news` edge function; the app only reads it.
@JsonSerializable(explicitToJson: true)
class GoldNews {
  final DateTime date;

  @JsonKey(name: 'summary_vi')
  final String summaryVi;

  @JsonKey(name: 'summary_en')
  final String summaryEn;

  @JsonKey(unknownEnumValue: GoldImpact.neutral)
  final GoldImpact sentiment;

  @JsonKey(name: 'sentiment_reason_vi')
  final String? sentimentReasonVi;

  @JsonKey(name: 'sentiment_reason_en')
  final String? sentimentReasonEn;

  final List<GoldNewsHighlight> highlights;
  final List<NewsSource> sources;

  /// When the server last rebuilt this digest, in UTC.
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const GoldNews({
    required this.date,
    required this.summaryVi,
    required this.summaryEn,
    this.sentiment = GoldImpact.neutral,
    this.sentimentReasonVi,
    this.sentimentReasonEn,
    this.highlights = const [],
    this.sources = const [],
    this.updatedAt,
  });

  factory GoldNews.fromJson(Map<String, dynamic> json) =>
      _$GoldNewsFromJson(json);

  Map<String, dynamic> toJson() => _$GoldNewsToJson(this);

  String summary(String languageCode) =>
      localizedText(summaryVi, summaryEn, languageCode);

  String? sentimentReason(String languageCode) {
    final vi = sentimentReasonVi;
    final en = sentimentReasonEn;
    if (vi == null || en == null) return vi ?? en;
    return localizedText(vi, en, languageCode);
  }

  /// The article a highlight was drawn from, or null when the model cited an
  /// index we could not resolve.
  NewsSource? sourceOf(GoldNewsHighlight highlight) {
    final index = highlight.sourceIndex;
    if (index == null || index < 0 || index >= sources.length) return null;
    return sources[index];
  }
}

@JsonSerializable()
class GoldNewsHighlight {
  @JsonKey(name: 'title_vi')
  final String titleVi;

  @JsonKey(name: 'title_en')
  final String titleEn;

  @JsonKey(name: 'detail_vi')
  final String detailVi;

  @JsonKey(name: 'detail_en')
  final String detailEn;

  @JsonKey(unknownEnumValue: GoldImpact.neutral)
  final GoldImpact impact;

  @JsonKey(name: 'source_index')
  final int? sourceIndex;

  const GoldNewsHighlight({
    required this.titleVi,
    required this.titleEn,
    required this.detailVi,
    required this.detailEn,
    this.impact = GoldImpact.neutral,
    this.sourceIndex,
  });

  factory GoldNewsHighlight.fromJson(Map<String, dynamic> json) =>
      _$GoldNewsHighlightFromJson(json);

  Map<String, dynamic> toJson() => _$GoldNewsHighlightToJson(this);

  String title(String languageCode) =>
      localizedText(titleVi, titleEn, languageCode);

  String detail(String languageCode) =>
      localizedText(detailVi, detailEn, languageCode);
}
