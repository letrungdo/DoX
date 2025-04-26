import 'dart:io';

import 'package:dio/io.dart';
import 'package:do_ai/constants/env.dart';

final httpClientAdapter = IOHttpClientAdapter(
  createHttpClient: () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    if (Envs.isDev) {
      // client.findProxy = (uri) {
      //   return 'PROXY $proxy;';
      // };
    }
    // You can also create a new HttpClient for Dio instead of returning,
    // but a client must being returned here.
    return client;
  },
);
