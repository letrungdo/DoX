// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gold_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoldResponse _$GoldResponseFromJson(Map<String, dynamic> json) => GoldResponse(
  data:
      json['data'] == null
          ? null
          : GoldData.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GoldResponseToJson(GoldResponse instance) =>
    <String, dynamic>{'data': instance.data?.toJson()};

GoldData _$GoldDataFromJson(Map<String, dynamic> json) => GoldData(
  symbols:
      (json['symbols'] as List<dynamic>?)
          ?.map((e) => GoldSymbol.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$GoldDataToJson(GoldData instance) => <String, dynamic>{
  'symbols': instance.symbols?.map((e) => e.toJson()).toList(),
};

GoldSymbol _$GoldSymbolFromJson(Map<String, dynamic> json) => GoldSymbol(
  code: json['code'] as String?,
  name: json['name'] as String?,
  desc: json['desc'] as String?,
  bid: (json['bid'] as num?)?.toDouble(),
  ask: (json['ask'] as num?)?.toDouble(),
  bidDayChangePercent: (json['bidDayChangePercent'] as num?)?.toDouble(),
  bidDayChange: (json['bidDayChange'] as num?)?.toDouble(),
  askDayChangePercent: (json['askDayChangePercent'] as num?)?.toDouble(),
  askDayChange: (json['askDayChange'] as num?)?.toDouble(),
  index: (json['index'] as num?)?.toInt(),
  time: const DateTimeConverter().fromJson(json['time'] as String?),
);

Map<String, dynamic> _$GoldSymbolToJson(GoldSymbol instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'desc': instance.desc,
      'bid': instance.bid,
      'ask': instance.ask,
      'bidDayChangePercent': instance.bidDayChangePercent,
      'bidDayChange': instance.bidDayChange,
      'askDayChangePercent': instance.askDayChangePercent,
      'askDayChange': instance.askDayChange,
      'index': instance.index,
      'time': const DateTimeConverter().toJson(instance.time),
    };
