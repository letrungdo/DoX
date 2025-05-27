import 'package:do_x/constants/enum/market_code.dart';

class RatePushModel {
  final String? area;
  final MarketCode? code;
  final double? dayChange;
  final double? dayChangePercent;
  final double? highPrice;
  final double? highWeek52Price;
  final int? index;
  final double? lowPrice;
  final double? lowWeek52Price;
  final String? marketStatus;
  final String? name;
  final String? nameEn;
  final double? openPrice;
  final double? price;
  final double? referPrice;
  final DateTime? time;
  final double? year1ChangePercent;

  const RatePushModel({
    required this.area,
    required this.code,
    required this.dayChange,
    required this.dayChangePercent,
    required this.highPrice,
    required this.highWeek52Price,
    required this.index,
    required this.lowPrice,
    required this.lowWeek52Price,
    required this.marketStatus,
    required this.name,
    required this.nameEn,
    required this.openPrice,
    required this.price,
    required this.referPrice,
    required this.time,
    required this.year1ChangePercent,
  });

  factory RatePushModel.fromJson(Map<String, dynamic> json) {
    return RatePushModel(
      area: json['area'] as String,
      code: MarketCode.from(json['code']),
      dayChange: (json['dayChange'] as num).toDouble(),
      dayChangePercent: (json['dayChangePercent'] as num).toDouble(),
      highPrice: (json['highPrice'] as num).toDouble(),
      highWeek52Price: (json['highWeek52Price'] as num).toDouble(),
      index: json['index'] as int,
      lowPrice: (json['lowPrice'] as num).toDouble(),
      lowWeek52Price: (json['lowWeek52Price'] as num).toDouble(),
      marketStatus: json['marketStatus'] as String,
      name: json['name'] as String,
      nameEn: json['nameEn'] as String,
      openPrice: (json['openPrice'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      referPrice: (json['referPrice'] as num).toDouble(),
      time: DateTime.parse(json['time'] as String),
      year1ChangePercent: (json['year1ChangePercent'] as num).toDouble(),
    );
  }
}
