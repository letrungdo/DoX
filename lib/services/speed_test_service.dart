import 'dart:async';
import 'package:dio/dio.dart';
import 'package:do_x/repository/client/http_client_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class SpeedTestServer {
  final String name;
  final String url;
  final int maxBytes;
  final double? lat;
  final double? lon;

  SpeedTestServer({
    required this.name,
    required this.url,
    required this.maxBytes,
    this.lat,
    this.lon,
  });

  static final List<SpeedTestServer> internetServers = [
    SpeedTestServer(
      name: "Viettel (Hà Nội)",
      url: "http://speedtestkv1a.viettel.vn:8080/speedtest/random4000x4000.jpg",
      maxBytes: 15 * 1024 * 1024,
      lat: 21.0285,
      lon: 105.8542,
    ),
    SpeedTestServer(
      name: "Viettel (TP.HCM)",
      url: "http://speedtestkv3a.viettel.vn:8080/speedtest/random4000x4000.jpg",
      maxBytes: 15 * 1024 * 1024,
      lat: 10.8231,
      lon: 106.6297,
    ),
    SpeedTestServer(
      name: "FPT Telecom (TP.HCM)",
      url: "http://speedtest.fpt.vn:8080/speedtest/random4000x4000.jpg",
      maxBytes: 15 * 1024 * 1024,
      lat: 10.8231,
      lon: 106.6297,
    ),
    SpeedTestServer(
      name: "Viettel (Đà Nẵng)",
      url: "http://speedtestkv2a.viettel.vn:8080/speedtest/random4000x4000.jpg",
      maxBytes: 15 * 1024 * 1024,
      lat: 16.0544,
      lon: 108.2022,
    ),
    SpeedTestServer(
      name: "VNPT (Hà Nội)",
      url: "http://speedtest1.vtn.com.vn:8080/speedtest/random4000x4000.jpg",
      maxBytes: 15 * 1024 * 1024,
      lat: 21.0285,
      lon: 105.8542,
    ),
    SpeedTestServer(
      name: "Cloudflare (Global)",
      url: "https://speed.cloudflare.com/__down?bytes=15000000",
      maxBytes: 15 * 1024 * 1024,
    ),
  ];

  static SpeedTestServer findNearest(Position position) {
    SpeedTestServer nearest = internetServers.first;
    double minDistance = double.infinity;

    for (final server in internetServers) {
      if (server.lat == null || server.lon == null) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        server.lat!,
        server.lon!,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = server;
      }
    }

    return nearest;
  }
}

class SpeedTestUpdate {
  final double currentMbps;
  final double progress;
  final bool isDone;
  final int? latencyMs;

  SpeedTestUpdate({
    required this.currentMbps,
    required this.progress,
    this.isDone = false,
    this.latencyMs,
  });
}

class SpeedTestService {
  final Dio _dio = () {
    final dio = Dio();
    if (!kIsWeb) dio.httpClientAdapter = httpClientAdapter;
    return dio;
  }();

  Stream<SpeedTestUpdate> testDownloadSpeedStream(String url, {CancelToken? cancelToken, int maxBytes = 10 * 1024 * 1024}) {
    final controller = StreamController<SpeedTestUpdate>();
    final requestStartTime = DateTime.now();

    _runTest(url, controller, requestStartTime, cancelToken, maxBytes);

    return controller.stream;
  }

  Future<void> _runTest(String url, StreamController<SpeedTestUpdate> controller, DateTime requestStartTime, CancelToken? cancelToken, int maxBytes) async {
    int receivedBytes = 0;
    DateTime? firstByteTime;
    int? latencyMs;

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "*/*",
            "Connection": "keep-alive",
          },
        ),
        cancelToken: cancelToken,
      );

      latencyMs = DateTime.now().difference(requestStartTime).inMilliseconds;
      controller.add(SpeedTestUpdate(currentMbps: 0, progress: 0, latencyMs: latencyMs));

      final stream = response.data!.stream;
      DateTime lastUpdateTime = DateTime.now();

      late StreamSubscription subscription;
      subscription = stream.listen(
        (chunk) {
          final now = DateTime.now();
          if (firstByteTime == null) {
            firstByteTime = now;
            lastUpdateTime = now;
          }

          receivedBytes += chunk.length;

          if (now.difference(lastUpdateTime).inMilliseconds > 100) {
            final totalDuration = now.difference(firstByteTime!);
            if (totalDuration.inMicroseconds > 0) {
              final avgMbps = (receivedBytes * 8) / (totalDuration.inMicroseconds / 1000000) / 1000000;
              controller.add(SpeedTestUpdate(
                currentMbps: avgMbps,
                progress: (receivedBytes / maxBytes).clamp(0.0, 1.0),
                latencyMs: latencyMs,
              ));
            }
            lastUpdateTime = now;
          }

          if (receivedBytes >= maxBytes) {
            subscription.cancel();
            final totalDuration = DateTime.now().difference(firstByteTime!);
            final finalMbps = (receivedBytes * 8) / (totalDuration.inMicroseconds / 1000000) / 1000000;
            controller.add(SpeedTestUpdate(
              currentMbps: finalMbps,
              progress: 1.0,
              isDone: true,
              latencyMs: latencyMs,
            ));
            controller.close();
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            final totalDuration = DateTime.now().difference(firstByteTime ?? DateTime.now());
            final finalMbps = totalDuration.inMicroseconds > 0
                ? (receivedBytes * 8) / (totalDuration.inMicroseconds / 1000000) / 1000000
                : 0.0;
            controller.add(SpeedTestUpdate(
              currentMbps: finalMbps,
              progress: 1.0,
              isDone: true,
              latencyMs: latencyMs,
            ));
            controller.close();
          }
        },
        onError: (e) {
          if (!controller.isClosed) controller.addError(e);
          controller.close();
        },
        cancelOnError: true,
      );

      cancelToken?.whenCancel.then((_) {
        subscription.cancel();
        if (!controller.isClosed) controller.close();
      });

    } on DioException catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    }
  }

  Stream<SpeedTestUpdate> testLanSpeed(String routerBaseUrl, {CancelToken? cancelToken}) {
    final assets = [
      "/luci-static/resources/web.js",
      "/luci-static/resources/luci.js",
      "/luci-static/resources/icons/loading.gif",
      "/cgi-bin/luci/web/home",
    ];

    final controller = StreamController<SpeedTestUpdate>();
    _tryLanAssets(assets, routerBaseUrl, controller, cancelToken);
    return controller.stream;
  }

  Future<void> _tryLanAssets(List<String> assets, String baseUrl, StreamController<SpeedTestUpdate> controller, CancelToken? cancelToken) async {
    for (var i = 0; i < assets.length; i++) {
      try {
        final url = "$baseUrl${assets[i]}";
        final head = await _dio.head(url, cancelToken: cancelToken, options: Options(receiveTimeout: const Duration(seconds: 3)));
        if (head.statusCode == 200) {
          final testStream = testDownloadSpeedStream(url, cancelToken: cancelToken, maxBytes: 5 * 1024 * 1024);
          await controller.addStream(testStream);
          await controller.close();
          return;
        }
      } catch (e) {
        if (i == assets.length - 1) {
          controller.addError(e);
          controller.close();
        }
      }
    }
  }

  Stream<SpeedTestUpdate> testInternetSpeed(SpeedTestServer server, {CancelToken? cancelToken}) {
    return testDownloadSpeedStream(server.url, cancelToken: cancelToken, maxBytes: server.maxBytes);
  }
}
