import 'package:json_annotation/json_annotation.dart';

part 'electric_models.g.dart';

/// Response of POST /api/cskh/user/login (cskh-api.cpc.vn).
@JsonSerializable()
class ElectricAuthResponse {
  @JsonKey(name: "access_token")
  final String? accessToken;

  @JsonKey(name: "expires_in")
  final int? expiresIn;

  @JsonKey(name: "token_type")
  final String? tokenType;

  const ElectricAuthResponse({this.accessToken, this.expiresIn, this.tokenType});

  factory ElectricAuthResponse.fromJson(Map<String, dynamic> json) => _$ElectricAuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricAuthResponseToJson(this);
}

/// Response of GET /api/remote/customers/infos.
@JsonSerializable(explicitToJson: true)
class ElectricCustomerInfos {
  final String? userName;
  final List<ElectricCustomer> customerCodes;

  const ElectricCustomerInfos({this.userName, this.customerCodes = const []});

  factory ElectricCustomerInfos.fromJson(Map<String, dynamic> json) => _$ElectricCustomerInfosFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricCustomerInfosToJson(this);
}

@JsonSerializable()
class ElectricCustomer {
  final String? orgCode;
  final String? customerCode;
  final String? customerName;
  final String? address;
  final String? meterId;
  final String? phoneNumber;

  const ElectricCustomer({
    this.orgCode, //
    this.customerCode,
    this.customerName,
    this.address,
    this.meterId,
    this.phoneNumber,
  });

  factory ElectricCustomer.fromJson(Map<String, dynamic> json) => _$ElectricCustomerFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricCustomerToJson(this);
}

/// Response of GET /api/remote/customers/{customerCode}/info — contract
/// details; only the fields the app shows are mapped.
@JsonSerializable()
class ElectricCustomerDetail {
  /// e.g. "Sinh hoạt", "Nông nghiệp".
  final String? contractType;
  final String? paymentType;
  final String? voltageLevel;

  const ElectricCustomerDetail({this.contractType, this.paymentType, this.voltageLevel});

  factory ElectricCustomerDetail.fromJson(Map<String, dynamic> json) => _$ElectricCustomerDetailFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricCustomerDetailToJson(this);
}

/// One row of GET /api/remote/lichSuDienNangTieuThu — usage/cost of a month
/// (`HT` = current period) compared with the same month last year (`QK`).
@JsonSerializable()
class ElectricMonthlyUsage {
  @JsonKey(name: "THANG_HT")
  final int? month;

  @JsonKey(name: "NAM_HT")
  final int? year;

  @JsonKey(name: "DIEN_TTHU_HT")
  final num? usageKwh;

  @JsonKey(name: "TONG_TIEN_HT")
  final num? totalAmount;

  @JsonKey(name: "THANG_QK")
  final int? lastYearMonth;

  @JsonKey(name: "NAM_QK")
  final int? lastYearYear;

  @JsonKey(name: "DIEN_TTHU_QK")
  final num? lastYearUsageKwh;

  @JsonKey(name: "TONG_TIEN_QK")
  final num? lastYearTotalAmount;

  const ElectricMonthlyUsage({
    this.month, //
    this.year,
    this.usageKwh,
    this.totalAmount,
    this.lastYearMonth,
    this.lastYearYear,
    this.lastYearUsageKwh,
    this.lastYearTotalAmount,
  });

  factory ElectricMonthlyUsage.fromJson(Map<String, dynamic> json) => _$ElectricMonthlyUsageFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricMonthlyUsageToJson(this);
}

/// GET /api/cskh/power-consumption-alerts/by-customer-code — daily/monthly
/// usage snapshot used by the CSKH dashboard.
@JsonSerializable(explicitToJson: true)
class ElectricUsageAlert {
  final String? customerCode;
  final ElectricUsageSnapshot? electricConsumption;

  const ElectricUsageAlert({this.customerCode, this.electricConsumption});

  factory ElectricUsageAlert.fromJson(Map<String, dynamic> json) => _$ElectricUsageAlertFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricUsageAlertToJson(this);
}

@JsonSerializable()
class ElectricUsageSnapshot {
  @JsonKey(name: "electricConsumptionToday")
  final num? today;

  @JsonKey(name: "electricConsumptionYesterday")
  final num? yesterday;

  @JsonKey(name: "electricConsumptionThisMonth")
  final num? thisMonth;

  @JsonKey(name: "electricConsumptionLastMonth")
  final num? lastMonth;

  const ElectricUsageSnapshot({this.today, this.yesterday, this.thisMonth, this.lastMonth});

  factory ElectricUsageSnapshot.fromJson(Map<String, dynamic> json) => _$ElectricUsageSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricUsageSnapshotToJson(this);
}

/// One row of GET /api/remote/customers/{code}/chiSoSpiderTop3 — meter
/// readings collected several times a day.
@JsonSerializable()
class ElectricMeterReading {
  @JsonKey(name: "SO_CTO")
  final String? meterId;

  /// Absolute meter index (kWh).
  @JsonKey(name: "CS_MOI")
  final num? meterIndex;

  /// kWh consumed since the last billing date.
  @JsonKey(name: "SL_MOI")
  final num? usageSinceBilling;

  @JsonKey(name: "NGAYGIO")
  final DateTime? readAt;

  const ElectricMeterReading({this.meterId, this.meterIndex, this.usageSinceBilling, this.readAt});

  factory ElectricMeterReading.fromJson(Map<String, dynamic> json) => _$ElectricMeterReadingFromJson(json);

  Map<String, dynamic> toJson() => _$ElectricMeterReadingToJson(this);
}
