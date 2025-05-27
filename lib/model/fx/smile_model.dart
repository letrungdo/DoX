import 'dart:convert';

import 'package:do_x/converter/date_time_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'smile_model.g.dart';

@JsonSerializable(explicitToJson: true)
class ExchangeData {
  @JsonKey(name: "Rates")
  final Rates rates;

  @DateTimeConverter()
  @JsonKey(name: "StartDateTime")
  final DateTime startDateTime;

  const ExchangeData({required this.rates, required this.startDateTime});

  factory ExchangeData.fromJson(Map<String, dynamic> json) {
    return ExchangeData(
      rates: Rates.fromJson(jsonDecode(json['Rates'])),
      startDateTime: DateTime.parse(json['StartDateTime']),
    );
  }

  Map<String, dynamic> toJson() => _$ExchangeDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Rates {
  @JsonKey(name: "ALL_ALL_ALL")
  final AllAllAll allAllAll;

  const Rates({required this.allAllAll});

  factory Rates.fromJson(Map<String, dynamic> json) => _$RatesFromJson(json);

  Map<String, dynamic> toJson() => _$RatesToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AllAllAll {
  @JsonKey(name: "Type")
  final int type;

  @JsonKey(name: "Currency")
  final Map<String, CurrencyRate> currency;

  const AllAllAll({required this.type, required this.currency});

  factory AllAllAll.fromJson(Map<String, dynamic> json) => _$AllAllAllFromJson(json);

  Map<String, dynamic> toJson() => _$AllAllAllToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CurrencyRate {
  @JsonKey(name: "From")
  final String from;
  @JsonKey(name: "To")
  final String to;
  @JsonKey(name: "BuyingRate")
  final double? buyingRate;
  @JsonKey(name: "SellingRate")
  final double? sellingRate;
  @JsonKey(name: "BookRate")
  final double? bookRate;
  @JsonKey(name: "AverageRate")
  final double? averageRate;
  @JsonKey(name: "TTMRate")
  final double? ttmRate;

  const CurrencyRate({
    required this.from,
    required this.to,
    this.buyingRate,
    this.sellingRate,
    this.bookRate,
    this.averageRate,
    this.ttmRate,
  });

  factory CurrencyRate.fromJson(Map<String, dynamic> json) => _$CurrencyRateFromJson(json);

  Map<String, dynamic> toJson() => _$CurrencyRateToJson(this);
}
