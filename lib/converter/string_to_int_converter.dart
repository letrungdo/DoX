import 'package:do_x/converter/string_to_double_converter.dart';
import 'package:json_annotation/json_annotation.dart';

class StringToIntConverter implements JsonConverter<int?, dynamic> {
  const StringToIntConverter();

  @override
  int? fromJson(dynamic json) {
    if (json is String?) {
      final floatValue = const StringToDoubleConverter().fromJson(json);
      if (floatValue?.isNaN ?? false) {
        return null;
      }
      return floatValue?.toInt();
    }
    if (json is int || json is double) {
      return (json as num).toInt();
    }
    return null;
  }

  @override
  String? toJson(int? object) {
    return object?.toString();
  }
}
