// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewsSource _$NewsSourceFromJson(Map<String, dynamic> json) => NewsSource(
  title: json['title'] as String,
  url: json['url'] as String,
  source: json['source'] as String?,
  publishedAt: json['published_at'] as String?,
);

Map<String, dynamic> _$NewsSourceToJson(NewsSource instance) =>
    <String, dynamic>{
      'title': instance.title,
      'url': instance.url,
      'source': instance.source,
      'published_at': instance.publishedAt,
    };
