// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExchangeData _$ExchangeDataFromJson(Map<String, dynamic> json) => ExchangeData(
  rates: Rates.fromJson(json['Rates'] as Map<String, dynamic>),
  startDateTime: DateTime.parse(json['StartDateTime'] as String),
);

Map<String, dynamic> _$ExchangeDataToJson(ExchangeData instance) =>
    <String, dynamic>{
      'Rates': instance.rates.toJson(),
      'StartDateTime': instance.startDateTime.toIso8601String(),
    };

Rates _$RatesFromJson(Map<String, dynamic> json) => Rates(
  allAllAll: AllAllAll.fromJson(json['ALL_ALL_ALL'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RatesToJson(Rates instance) => <String, dynamic>{
  'ALL_ALL_ALL': instance.allAllAll.toJson(),
};

AllAllAll _$AllAllAllFromJson(Map<String, dynamic> json) => AllAllAll(
  type: (json['Type'] as num).toInt(),
  currency: (json['Currency'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, CurrencyRate.fromJson(e as Map<String, dynamic>)),
  ),
);

Map<String, dynamic> _$AllAllAllToJson(AllAllAll instance) => <String, dynamic>{
  'Type': instance.type,
  'Currency': instance.currency.map((k, e) => MapEntry(k, e.toJson())),
};

CurrencyRate _$CurrencyRateFromJson(Map<String, dynamic> json) => CurrencyRate(
  from: json['From'] as String,
  to: json['To'] as String,
  buyingRate: (json['BuyingRate'] as num?)?.toDouble(),
  sellingRate: (json['SellingRate'] as num?)?.toDouble(),
  bookRate: (json['BookRate'] as num?)?.toDouble(),
  averageRate: (json['AverageRate'] as num?)?.toDouble(),
  ttmRate: (json['TTMRate'] as num?)?.toDouble(),
);

Map<String, dynamic> _$CurrencyRateToJson(CurrencyRate instance) =>
    <String, dynamic>{
      'From': instance.from,
      'To': instance.to,
      'BuyingRate': instance.buyingRate,
      'SellingRate': instance.sellingRate,
      'BookRate': instance.bookRate,
      'AverageRate': instance.averageRate,
      'TTMRate': instance.ttmRate,
    };
