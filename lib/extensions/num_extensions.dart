import 'package:do_x/constants/app_const.dart';
import 'package:do_x/extensions/double_extensions.dart';

extension NumExtensions on num? {
  String formatUnit({int? digit, bool hasPlus = false}) {
    final value = this;
    if (value == null) return AppConst.dash;
    return value.toDouble().formatUnit(digit: digit, hasPlus: hasPlus);
  }
}
