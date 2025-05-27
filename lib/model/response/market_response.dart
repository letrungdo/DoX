import 'package:do_x/constants/enum/market_code.dart';

class MarketResponse {
  final MarketData data;

  const MarketResponse({required this.data});

  factory MarketResponse.fromJson(Map<String, dynamic> json) {
    return MarketResponse(data: MarketData.fromJson(json['data']));
  }
}

class MarketData {
  final List<MarketCodeInfo> codes;

  const MarketData({required this.codes});

  factory MarketData.fromJson(Map<String, dynamic> json) {
    return MarketData(codes: (json['codes'] as List).map((i) => MarketCodeInfo.fromJson(i)).toList());
  }
}

class MarketCodeInfo {
  final MarketCode? code;
  final List<Bar> bars;

  const MarketCodeInfo({required this.code, required this.bars});

  factory MarketCodeInfo.fromJson(Map<String, dynamic> json) {
    return MarketCodeInfo(code: MarketCode.from(json['code']), bars: (json['bars'] as List).map((i) => Bar.fromList(i)).toList());
  }
}

class Bar {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime date;

  const Bar({required this.open, required this.high, required this.low, required this.close, required this.volume, required this.date});

  factory Bar.fromList(List<dynamic> list) {
    return Bar(
      open: (list[0] as num).toDouble(),
      high: (list[1] as num).toDouble(),
      low: (list[2] as num).toDouble(),
      close: (list[3] as num).toDouble(),
      volume: (list[4] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(list[5] as int),
    );
  }
}
