import 'dart:typed_data';

import 'package:dio/dio.dart';

/// For test
class MockServer implements HttpClientAdapter {
  MockServer({this.timeout = const Duration(seconds: 2)});

  final Duration timeout;

  @override
  void close({bool force = false}) {
    // nothing to do
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    await Future<void>.delayed(timeout);
    throw UnimplementedError(); // not reply valid response
  }
}
