import 'package:do_x/converter/date_time_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'gold_model.g.dart';

@JsonSerializable(explicitToJson: true)
class GoldResponse {
  final GoldData? data;

  const GoldResponse({this.data});

  factory GoldResponse.fromJson(Map<String, dynamic> json) => _$GoldResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GoldResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class GoldData {
  final List<GoldSymbol>? symbols;

  const GoldData({this.symbols});

  factory GoldData.fromJson(Map<String, dynamic> json) => _$GoldDataFromJson(json);

  Map<String, dynamic> toJson() => _$GoldDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class GoldSymbol {
  final String? code;
  final String? name;
  final String? desc;
  final double? bid;
  final double? ask;
  final double? bidDayChangePercent;
  final double? bidDayChange;
  final double? askDayChangePercent;
  final double? askDayChange;
  final int? index;

  @DateTimeConverter()
  final DateTime? time;

  const GoldSymbol({
    this.code,
    this.name,
    this.desc,
    this.bid,
    this.ask,
    this.bidDayChangePercent,
    this.bidDayChange,
    this.askDayChangePercent,
    this.askDayChange,
    this.index,
    this.time,
  });

  factory GoldSymbol.fromJson(Map<String, dynamic> json) => _$GoldSymbolFromJson(json);

  Map<String, dynamic> toJson() => _$GoldSymbolToJson(this);
}
