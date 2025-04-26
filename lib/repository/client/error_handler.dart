import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:do_ai/utils/logger.dart';
import 'package:flutter/foundation.dart';

const requestTimeOutMessage = "The semaphore timeout period has expired.";
const connectionCloseMessage = "Connection closed before full header was received";

enum ApiErrorType {
  networkError, //
  requestTimeout,
  maintenance,
  unknownError,
  cancel,
  sessionTimeout,
  businessError,
  badRequest,
  other,
}

class ConnectionError {
  ConnectionError({this.type, this.message, this.statusCode, this.resultString});
  final ApiErrorType? type;
  final String? message;
  final int? statusCode;
  final String? resultString;
}

class Result<T> {
  const Result({this.data, this.error});
  final T? data;
  final ConnectionError? error;
  bool get isError => error != null;
  bool get isCancelByUser => error?.type == ApiErrorType.cancel;

  static Future<Result<T>> guardFuture<T>(Future<T> Function() request) async {
    try {
      return Result(data: await request());
    } on DioException catch (e) {
      logger.e('guardFuture DioException[${e.response?.statusCode}] => URL: ${e.requestOptions.uri}; res: ${e.response}', error: e.error);
      switch (e.type) {
        case DioExceptionType.cancel:
          debugPrint('Request canceled: ${e.message}');
          return Result(error: ConnectionError(type: ApiErrorType.cancel));
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return Result(error: ConnectionError(type: ApiErrorType.requestTimeout));
        case DioExceptionType.badResponse:
          final error = e.error;
          if (error is DioException) {
            final statusCode = error.response?.statusCode;
            switch (statusCode) {
              case HttpStatus.badRequest: // 400
                return Result(error: ConnectionError(type: ApiErrorType.badRequest, statusCode: statusCode));
              case HttpStatus.movedPermanently: // 301
              case HttpStatus.serviceUnavailable: // 503
                return Result(error: ConnectionError(type: ApiErrorType.maintenance, message: error.message));
              default:
                return Result(error: ConnectionError(type: ApiErrorType.other, statusCode: statusCode));
            }
          }
          return Result(error: ConnectionError(type: ApiErrorType.unknownError));
        case DioExceptionType.badCertificate:
        case DioExceptionType.connectionError:
          return Result(error: ConnectionError(type: ApiErrorType.networkError));
        case DioExceptionType.unknown:
          if (e.error is SocketException) {
            final message = (e.error as SocketException).message;
            if (message.contains(requestTimeOutMessage) || message.contains(connectionCloseMessage)) {
              return Result(error: ConnectionError(type: ApiErrorType.requestTimeout));
            }
          }
          if (e.error is HttpException) {
            final message = (e.error as HttpException).message;
            if (message.contains(requestTimeOutMessage) || message.contains(connectionCloseMessage)) {
              return Result(error: ConnectionError(type: ApiErrorType.requestTimeout));
            }
          }
          return Result(error: ConnectionError(type: ApiErrorType.unknownError));
      }
    } catch (e) {
      logger.e('Api Unknown error', error: e);
      return Result(error: ConnectionError(type: ApiErrorType.unknownError));
    }
  }
}
