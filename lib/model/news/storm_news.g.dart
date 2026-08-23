// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storm_news.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StormNews _$StormNewsFromJson(Map<String, dynamic> json) => StormNews(
  date: DateTime.parse(json['date'] as String),
  active: json['active'] as bool? ?? false,
  nameVi: json['name_vi'] as String?,
  nameEn: json['name_en'] as String?,
  severity:
      $enumDecodeNullable(
        _$StormSeverityEnumMap,
        json['severity'],
        unknownValue: StormSeverity.watch,
      ) ??
      StormSeverity.watch,
  headlineVi: json['headline_vi'] as String?,
  headlineEn: json['headline_en'] as String?,
  summaryVi: json['summary_vi'] as String?,
  summaryEn: json['summary_en'] as String?,
  adviceVi: json['advice_vi'] as String?,
  adviceEn: json['advice_en'] as String?,
  highlights:
      (json['highlights'] as List<dynamic>?)
          ?.map((e) => StormNewsHighlight.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  sources:
      (json['sources'] as List<dynamic>?)
          ?.map((e) => NewsSource.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$StormNewsToJson(StormNews instance) => <String, dynamic>{
  'active': instance.active,
  'date': instance.date.toIso8601String(),
  'name_vi': instance.nameVi,
  'name_en': instance.nameEn,
  'severity': _$StormSeverityEnumMap[instance.severity]!,
  'headline_vi': instance.headlineVi,
  'headline_en': instance.headlineEn,
  'summary_vi': instance.summaryVi,
  'summary_en': instance.summaryEn,
  'advice_vi': instance.adviceVi,
  'advice_en': instance.adviceEn,
  'highlights': instance.highlights.map((e) => e.toJson()).toList(),
  'sources': instance.sources.map((e) => e.toJson()).toList(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

const _$StormSeverityEnumMap = {
  StormSeverity.watch: 'watch',
  StormSeverity.warning: 'warning',
  StormSeverity.emergency: 'emergency',
};

StormNewsHighlight _$StormNewsHighlightFromJson(Map<String, dynamic> json) =>
    StormNewsHighlight(
      titleVi: json['title_vi'] as String,
      titleEn: json['title_en'] as String,
      detailVi: json['detail_vi'] as String,
      detailEn: json['detail_en'] as String,
      sourceIndex: (json['source_index'] as num?)?.toInt(),
    );

Map<String, dynamic> _$StormNewsHighlightToJson(StormNewsHighlight instance) =>
    <String, dynamic>{
      'title_vi': instance.titleVi,
      'title_en': instance.titleEn,
      'detail_vi': instance.detailVi,
      'detail_en': instance.detailEn,
      'source_index': instance.sourceIndex,
    };
