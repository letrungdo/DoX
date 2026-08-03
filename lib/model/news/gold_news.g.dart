// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gold_news.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoldNews _$GoldNewsFromJson(Map<String, dynamic> json) => GoldNews(
  date: DateTime.parse(json['date'] as String),
  summaryVi: json['summary_vi'] as String,
  summaryEn: json['summary_en'] as String,
  sentiment:
      $enumDecodeNullable(
        _$GoldImpactEnumMap,
        json['sentiment'],
        unknownValue: GoldImpact.neutral,
      ) ??
      GoldImpact.neutral,
  sentimentReasonVi: json['sentiment_reason_vi'] as String?,
  sentimentReasonEn: json['sentiment_reason_en'] as String?,
  highlights:
      (json['highlights'] as List<dynamic>?)
          ?.map((e) => GoldNewsHighlight.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  sources:
      (json['sources'] as List<dynamic>?)
          ?.map((e) => GoldNewsSource.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$GoldNewsToJson(GoldNews instance) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'summary_vi': instance.summaryVi,
  'summary_en': instance.summaryEn,
  'sentiment': _$GoldImpactEnumMap[instance.sentiment]!,
  'sentiment_reason_vi': instance.sentimentReasonVi,
  'sentiment_reason_en': instance.sentimentReasonEn,
  'highlights': instance.highlights.map((e) => e.toJson()).toList(),
  'sources': instance.sources.map((e) => e.toJson()).toList(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

const _$GoldImpactEnumMap = {
  GoldImpact.up: 'up',
  GoldImpact.down: 'down',
  GoldImpact.neutral: 'neutral',
};

GoldNewsHighlight _$GoldNewsHighlightFromJson(Map<String, dynamic> json) =>
    GoldNewsHighlight(
      titleVi: json['title_vi'] as String,
      titleEn: json['title_en'] as String,
      detailVi: json['detail_vi'] as String,
      detailEn: json['detail_en'] as String,
      impact:
          $enumDecodeNullable(
            _$GoldImpactEnumMap,
            json['impact'],
            unknownValue: GoldImpact.neutral,
          ) ??
          GoldImpact.neutral,
      sourceIndex: (json['source_index'] as num?)?.toInt(),
    );

Map<String, dynamic> _$GoldNewsHighlightToJson(GoldNewsHighlight instance) =>
    <String, dynamic>{
      'title_vi': instance.titleVi,
      'title_en': instance.titleEn,
      'detail_vi': instance.detailVi,
      'detail_en': instance.detailEn,
      'impact': _$GoldImpactEnumMap[instance.impact]!,
      'source_index': instance.sourceIndex,
    };

GoldNewsSource _$GoldNewsSourceFromJson(Map<String, dynamic> json) =>
    GoldNewsSource(
      title: json['title'] as String,
      url: json['url'] as String,
      source: json['source'] as String?,
      publishedAt: json['published_at'] as String?,
    );

Map<String, dynamic> _$GoldNewsSourceToJson(GoldNewsSource instance) =>
    <String, dynamic>{
      'title': instance.title,
      'url': instance.url,
      'source': instance.source,
      'published_at': instance.publishedAt,
    };
