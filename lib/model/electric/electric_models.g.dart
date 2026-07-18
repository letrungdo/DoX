// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'electric_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ElectricAuthResponse _$ElectricAuthResponseFromJson(
  Map<String, dynamic> json,
) => ElectricAuthResponse(
  accessToken: json['access_token'] as String?,
  expiresIn: (json['expires_in'] as num?)?.toInt(),
  tokenType: json['token_type'] as String?,
);

Map<String, dynamic> _$ElectricAuthResponseToJson(
  ElectricAuthResponse instance,
) => <String, dynamic>{
  'access_token': instance.accessToken,
  'expires_in': instance.expiresIn,
  'token_type': instance.tokenType,
};

ElectricCustomerInfos _$ElectricCustomerInfosFromJson(
  Map<String, dynamic> json,
) => ElectricCustomerInfos(
  userName: json['userName'] as String?,
  customerCodes:
      (json['customerCodes'] as List<dynamic>?)
          ?.map((e) => ElectricCustomer.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ElectricCustomerInfosToJson(
  ElectricCustomerInfos instance,
) => <String, dynamic>{
  'userName': instance.userName,
  'customerCodes': instance.customerCodes.map((e) => e.toJson()).toList(),
};

ElectricCustomer _$ElectricCustomerFromJson(Map<String, dynamic> json) =>
    ElectricCustomer(
      orgCode: json['orgCode'] as String?,
      customerCode: json['customerCode'] as String?,
      customerName: json['customerName'] as String?,
      address: json['address'] as String?,
      meterId: json['meterId'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
    );

Map<String, dynamic> _$ElectricCustomerToJson(ElectricCustomer instance) =>
    <String, dynamic>{
      'orgCode': instance.orgCode,
      'customerCode': instance.customerCode,
      'customerName': instance.customerName,
      'address': instance.address,
      'meterId': instance.meterId,
      'phoneNumber': instance.phoneNumber,
    };

ElectricCustomerDetail _$ElectricCustomerDetailFromJson(
  Map<String, dynamic> json,
) => ElectricCustomerDetail(
  contractType: json['contractType'] as String?,
  paymentType: json['paymentType'] as String?,
  voltageLevel: json['voltageLevel'] as String?,
);

Map<String, dynamic> _$ElectricCustomerDetailToJson(
  ElectricCustomerDetail instance,
) => <String, dynamic>{
  'contractType': instance.contractType,
  'paymentType': instance.paymentType,
  'voltageLevel': instance.voltageLevel,
};

ElectricMonthlyUsage _$ElectricMonthlyUsageFromJson(
  Map<String, dynamic> json,
) => ElectricMonthlyUsage(
  month: (json['THANG_HT'] as num?)?.toInt(),
  year: (json['NAM_HT'] as num?)?.toInt(),
  usageKwh: json['DIEN_TTHU_HT'] as num?,
  totalAmount: json['TONG_TIEN_HT'] as num?,
  lastYearMonth: (json['THANG_QK'] as num?)?.toInt(),
  lastYearYear: (json['NAM_QK'] as num?)?.toInt(),
  lastYearUsageKwh: json['DIEN_TTHU_QK'] as num?,
  lastYearTotalAmount: json['TONG_TIEN_QK'] as num?,
);

Map<String, dynamic> _$ElectricMonthlyUsageToJson(
  ElectricMonthlyUsage instance,
) => <String, dynamic>{
  'THANG_HT': instance.month,
  'NAM_HT': instance.year,
  'DIEN_TTHU_HT': instance.usageKwh,
  'TONG_TIEN_HT': instance.totalAmount,
  'THANG_QK': instance.lastYearMonth,
  'NAM_QK': instance.lastYearYear,
  'DIEN_TTHU_QK': instance.lastYearUsageKwh,
  'TONG_TIEN_QK': instance.lastYearTotalAmount,
};

ElectricUsageAlert _$ElectricUsageAlertFromJson(Map<String, dynamic> json) =>
    ElectricUsageAlert(
      customerCode: json['customerCode'] as String?,
      electricConsumption: json['electricConsumption'] == null
          ? null
          : ElectricUsageSnapshot.fromJson(
              json['electricConsumption'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$ElectricUsageAlertToJson(ElectricUsageAlert instance) =>
    <String, dynamic>{
      'customerCode': instance.customerCode,
      'electricConsumption': instance.electricConsumption?.toJson(),
    };

ElectricUsageSnapshot _$ElectricUsageSnapshotFromJson(
  Map<String, dynamic> json,
) => ElectricUsageSnapshot(
  today: json['electricConsumptionToday'] as num?,
  yesterday: json['electricConsumptionYesterday'] as num?,
  thisMonth: json['electricConsumptionThisMonth'] as num?,
  lastMonth: json['electricConsumptionLastMonth'] as num?,
);

Map<String, dynamic> _$ElectricUsageSnapshotToJson(
  ElectricUsageSnapshot instance,
) => <String, dynamic>{
  'electricConsumptionToday': instance.today,
  'electricConsumptionYesterday': instance.yesterday,
  'electricConsumptionThisMonth': instance.thisMonth,
  'electricConsumptionLastMonth': instance.lastMonth,
};

ElectricMeterReading _$ElectricMeterReadingFromJson(
  Map<String, dynamic> json,
) => ElectricMeterReading(
  meterId: json['SO_CTO'] as String?,
  meterIndex: json['CS_MOI'] as num?,
  usageSinceBilling: json['SL_MOI'] as num?,
  readAt: json['NGAYGIO'] == null
      ? null
      : DateTime.parse(json['NGAYGIO'] as String),
);

Map<String, dynamic> _$ElectricMeterReadingToJson(
  ElectricMeterReading instance,
) => <String, dynamic>{
  'SO_CTO': instance.meterId,
  'CS_MOI': instance.meterIndex,
  'SL_MOI': instance.usageSinceBilling,
  'NGAYGIO': instance.readAt?.toIso8601String(),
};
