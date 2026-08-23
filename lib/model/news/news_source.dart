import 'package:json_annotation/json_annotation.dart';

part 'news_source.g.dart';

/// Picks the Vietnamese or English wording of a digest field. Every text the
/// server writes comes as a pair, so a card can follow the app's language
/// without a second round trip.
String localizedText(String vi, String en, String languageCode) {
  return languageCode == 'vi' ? vi : en;
}

/// An article one of the AI digests was built from. Shared by the gold-news and
/// storm-news bulletins, which the server writes in the same shape.
@JsonSerializable()
class NewsSource {
  final String title;
  final String url;
  final String? source;

  @JsonKey(name: 'published_at')
  final String? publishedAt;

  const NewsSource({
    required this.title,
    required this.url,
    this.source,
    this.publishedAt,
  });

  factory NewsSource.fromJson(Map<String, dynamic> json) =>
      _$NewsSourceFromJson(json);

  Map<String, dynamic> toJson() => _$NewsSourceToJson(this);
}
