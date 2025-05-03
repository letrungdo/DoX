import 'package:dio/dio.dart';

enum ClientType { locket, firebase, other }

class FXDioError {
  const FXDioError({
    required this.clientType, //
    required this.response,
  });
  final ClientType clientType;
  final Response response;

  dynamic get data => response.data ?? {};
}

extension DioExceptionExt on DioException {
  static DioException badResponse({required FXDioError error}) => DioException(
    type: DioExceptionType.badResponse,
    requestOptions: error.response.requestOptions,
    response: error.response,
    error: error,
  );
}
