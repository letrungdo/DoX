import 'package:dio/dio.dart';
import 'package:do_x/model/electric/electric_models.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';

/// CSKH CPC (Trung tâm CSKH Điện lực miền Trung) API client.
class ElectricService {
  final dio = DioClient.create("https://cskh-api.cpc.vn");

  /// Several accounts can fetch concurrently, so the JWT is passed per
  /// request instead of being kept on the client.
  Options _authOptions(String? accessToken) =>
      Options(headers: {if (accessToken != null) "Authorization": "Bearer $accessToken"});

  Future<Result<ElectricAuthResponse>> login({
    required String username,
    required String password,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final response = await dio.post(
        "/api/cskh/user/login",
        data: {
          "username": username,
          "password": password,
          "grant_type": "password",
          "scope": "CSKH",
          "ThongTinCaptcha": {"captcha": "undefined", "token": "undefined"},
        },
        cancelToken: cancelToken,
      );
      return ElectricAuthResponse.fromJson(response.data);
    });
  }

  Future<Result<ElectricCustomerInfos>> getCustomerInfos({
    required String? accessToken,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        "/api/remote/customers/infos",
        options: _authOptions(accessToken),
        cancelToken: cancelToken,
      );
      return ElectricCustomerInfos.fromJson(response.data);
    });
  }

  Future<Result<ElectricCustomerDetail>> getCustomerDetail(
    String customerCode, {
    required String? accessToken,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        "/api/remote/customers/$customerCode/info",
        options: _authOptions(accessToken),
        cancelToken: cancelToken,
      );
      return ElectricCustomerDetail.fromJson(response.data);
    });
  }

  Future<Result<List<ElectricMonthlyUsage>>> getMonthlyUsageHistory(
    String customerCode, {
    required String? accessToken,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        "/api/remote/lichSuDienNangTieuThu",
        queryParameters: {"customerCode": customerCode},
        options: _authOptions(accessToken),
        cancelToken: cancelToken,
      );
      final result = response.data["result"] as List<dynamic>? ?? [];
      return result.map((e) => ElectricMonthlyUsage.fromJson(e)).toList();
    });
  }

  Future<Result<ElectricUsageAlert>> getUsageAlert(
    String customerCode, {
    required String? accessToken,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        "/api/cskh/power-consumption-alerts/by-customer-code/$customerCode",
        options: _authOptions(accessToken),
        cancelToken: cancelToken,
      );
      return ElectricUsageAlert.fromJson(response.data);
    });
  }

  /// RF-SPIDER remote metering readings (every ~6h), newest first.
  Future<Result<List<ElectricMeterReading>>> getSpiderReadings({
    required String customerCode,
    required String orgCode,
    required String? accessToken,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        "/api/remote/spider/thongTinChiSo",
        queryParameters: {"customerCode": customerCode, "orgCode": orgCode},
        options: _authOptions(accessToken),
        cancelToken: cancelToken,
      );
      final result = response.data["chiSoGiao"] as List<dynamic>? ?? [];
      return result.map((e) => ElectricMeterReading.fromJson(e)).toList();
    });
  }
}
