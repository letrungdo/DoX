import 'package:dio/dio.dart';

mixin CancelRequestMixin {
  CancelToken _cancelToken = CancelToken();
  CancelToken get cancelToken => _cancelToken;

  void cancelRequest(String reason) {
    _cancelToken.cancel('$reason: cancelled');
  }

  void renewCancelToken(String reason) {
    cancelRequest(reason);
    _cancelToken = CancelToken();
  }
}
