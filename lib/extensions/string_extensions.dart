import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:do_x/constants/app_const.dart';
import 'package:flutter/foundation.dart';

extension StringNullableExtensions on String? {
  bool get isNullOrEmpty => this?.isEmpty ?? true;

  bool get isNotNullOrEmpty => this?.isNotEmpty ?? false;

  String get toDashIfNull => this ?? "-";

  String withStatusCode(int? statusCode) => statusCode == null ? toString() : '$this（$statusCode）';

  DateTime? toDateTime() {
    if (isNullOrEmpty) return null;
    return DateTime.tryParse(this!.replaceAll('/', '-'));
  }

  String toMd5() {
    return md5.convert(utf8.encode(this ?? "")).toString();
  }

  bool isImage() => this?.startsWith("image/") ?? false;

  bool isVideo() => this?.startsWith("video/") ?? false;

  bool isLoadingDialog() => this?.startsWith(AppConst.loadingIdPrefix) == true;

  Decimal? toDecimal() {
    return Decimal.tryParse(this ?? "");
  }

  double? toDouble() {
    return double.tryParse(this ?? "");
  }

  String withProxy() {
    if (kIsWeb) {
      return "https://app.xn--t-lia.vn/api/proxy?url=${Uri.encodeComponent(this ?? "")}";
    }
    return this ?? "";
  }
}

extension StringExtensions on String {
  String get toCapitalized => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}
