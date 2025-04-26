extension StringNullableExtensions on String? {
  bool get isNullOrEmpty => this?.isEmpty ?? true;

  bool get isNotNullOrEmpty => this?.isNotEmpty ?? false;

  String withStatusCode(int? statusCode) => statusCode == null ? toString() : '$this（$statusCode）';
}
