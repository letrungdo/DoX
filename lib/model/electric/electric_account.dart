import 'package:do_x/model/electric/electric_models.dart';

/// One CSKH CPC login. Credentials/token are persisted; the fetched data
/// below them is runtime-only cache so switching accounts is instant.
class ElectricAccount {
  ElectricAccount({
    required this.username,
    required this.password,
    this.accessToken,
    this.customerName,
    this.contractType,
  });

  final String username;
  final String password;
  String? accessToken;

  /// Cached from the last successful fetch so the account chips show real
  /// names right away on app start; refreshed once the API responds.
  String? customerName;
  String? contractType;

  ElectricCustomer? customer;
  ElectricCustomerDetail? detail;
  ElectricUsageSnapshot? usage;
  List<ElectricMeterReading> spiderReadings = [];
  List<ElectricMonthlyUsage> monthlyUsages = [];

  /// True once a fetch for this account has completed at least once.
  bool loaded = false;

  String get displayName => customer?.customerName ?? customerName ?? username;

  /// Given name only ("Lê Trung Đông" → "Đông") to keep the chips compact.
  String get shortDisplayName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? displayName : parts.last;
  }

  String? get contractTypeDisplay => detail?.contractType ?? contractType;

  factory ElectricAccount.fromJson(Map<String, dynamic> json) => ElectricAccount(
    username: json['username'] as String,
    password: json['password'] as String,
    accessToken: json['accessToken'] as String?,
    customerName: json['customerName'] as String?,
    contractType: json['contractType'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'username': username, //
    'password': password,
    'accessToken': accessToken,
    'customerName': customerName,
    'contractType': contractType,
  };
}
