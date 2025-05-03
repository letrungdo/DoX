import 'package:json_annotation/json_annotation.dart';

class StringToDoubleConverter implements JsonConverter<double?, dynamic> {
  const StringToDoubleConverter();

  @override
  double? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is String) {
      if (json.trim().isEmpty) return double.nan;
      final value = double.tryParse(json);
      if (value == null || value.isNaN) return null;
      return value;
    }
    if (json is int || json is double) {
      return (json as num).toDouble();
    }
    return null;
  }

  @override
  String? toJson(double? object) {
    if (object == null) return null;
    return object.isNaN ? "" : object.toString();
  }
}
