import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/repository/client/http_client_adapter.dart';
import 'package:flutter/foundation.dart';

class SpeedTestServer {
  final String name;
  final String url;
  const SpeedTestServer({required this.name, required this.url});

  static const List<SpeedTestServer> internetServers = [
    SpeedTestServer(
      name: "Cloudflare (Global)",
      // Cloudflare currently rejects 100 MB requests with HTTP 403. Workers
      // repeat this 25 MB payload until the timed test has finished.
      url: "https://speed.cloudflare.com/__down?bytes=25000000",
    ),
  ];
}

class SpeedTestUpdate {
  final double currentMbps;
  final double progress;
  final bool isDone;
  final int? latencyMs;

  const SpeedTestUpdate({
    required this.currentMbps,
    required this.progress,
    this.isDone = false,
    this.latencyMs,
  });
}

class SpeedTestService {
  static const _internetDuration = Duration(seconds: 8);
  static const _lanDuration = Duration(seconds: 5);
  static const _sampleInterval = Duration(milliseconds: 200);
  static const _rollingWindow = Duration(seconds: 1);
  static const _warmUpDuration = Duration(milliseconds: 800);

  final Dio _dio = () {
    final dio = Dio();
    if (!kIsWeb) dio.httpClientAdapter = httpClientAdapter;
    return dio;
  }();

  Stream<SpeedTestUpdate> testInternetSpeed(
    SpeedTestServer server, {
    CancelToken? cancelToken,
  }) {
    return _timedDownloadTest(
      server.url,
      duration: _internetDuration,
      // A single HTTP connection often cannot saturate a fast Internet link.
      parallelDownloads: 4,
      cancelToken: cancelToken,
    );
  }

  Stream<SpeedTestUpdate> testLanSpeed(
    String routerBaseUrl, {
    CancelToken? cancelToken,
  }) {
    final controller = StreamController<SpeedTestUpdate>();
    unawaited(_runLanTest(routerBaseUrl, controller, cancelToken));
    return controller.stream;
  }

  Future<void> _runLanTest(
    String baseUrl,
    StreamController<SpeedTestUpdate> controller,
    CancelToken? cancelToken,
  ) async {
    try {
      final assetUrl = await _findLanAsset(baseUrl, cancelToken);
      await controller.addStream(
        _timedDownloadTest(
          assetUrl,
          duration: _lanDuration,
          // Router assets are usually small. Concurrent repeated downloads avoid
          // measuring only one request's setup overhead.
          parallelDownloads: 4,
          cancelToken: cancelToken,
        ),
      );
    } catch (error, stackTrace) {
      if (!controller.isClosed && cancelToken?.isCancelled != true) {
        controller.addError(error, stackTrace);
      }
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  Future<String> _findLanAsset(String baseUrl, CancelToken? cancelToken) async {
    const paths = [
      // Xiaomi MiWiFi firmware (including the R3G) serves these assets from
      // the web root. They are substantially larger than the login page.
      "/js/jquery-1.8.3.js",
      "/js/raphael.js",
      "/js/qwrap.js",
      "/luci-static/resources/web.js",
      "/luci-static/resources/xhci.js",
      "/luci-static/resources/luci.js",
      "/cgi-bin/luci/web/home",
    ];

    Object? lastError;
    String? largestAssetUrl;
    var largestAssetBytes = -1;
    for (final path in paths) {
      if (cancelToken?.isCancelled == true) {
        throw DioException.requestCancelled(
          requestOptions: RequestOptions(path: baseUrl),
          reason: cancelToken?.cancelError,
        );
      }
      final url = "$baseUrl$path";
      try {
        final response = await _dio.head<void>(
          url,
          cancelToken: cancelToken,
          options: Options(
            receiveTimeout: const Duration(seconds: 3),
            sendTimeout: const Duration(seconds: 3),
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (response.statusCode == 200) {
          final contentLength =
              int.tryParse(
                response.headers.value(Headers.contentLengthHeader) ?? "",
              ) ??
              0;
          if (contentLength > largestAssetBytes) {
            largestAssetBytes = contentLength;
            largestAssetUrl = url;
          }
          continue;
        }
        lastError = "HTTP ${response.statusCode} tại $path";
      } catch (error) {
        lastError = error;
      }
    }
    if (largestAssetUrl != null) return largestAssetUrl;
    throw Exception("Không tìm thấy file phù hợp trên router ($lastError)");
  }

  Stream<SpeedTestUpdate> _timedDownloadTest(
    String url, {
    required Duration duration,
    required int parallelDownloads,
    CancelToken? cancelToken,
  }) {
    final controller = StreamController<SpeedTestUpdate>();
    unawaited(
      _runTimedDownloadTest(
        url,
        duration,
        parallelDownloads,
        controller,
        cancelToken,
      ),
    );
    return controller.stream;
  }

  Future<void> _runTimedDownloadTest(
    String url,
    Duration duration,
    int parallelDownloads,
    StreamController<SpeedTestUpdate> controller,
    CancelToken? parentCancelToken,
  ) async {
    final requestCancelToken = CancelToken();
    final stopwatch = Stopwatch()..start();
    final samples = <_ByteSample>[_ByteSample(Duration.zero, 0)];
    var totalBytes = 0;
    var warmUpBytes = 0;
    var warmUpElapsed = Duration.zero;
    int? latencyMs;
    Object? workerError;
    Timer? deadlineTimer;
    Timer? sampleTimer;

    void emitSample() {
      if (controller.isClosed) return;
      final elapsed = stopwatch.elapsed;
      samples.add(_ByteSample(elapsed, totalBytes));
      final windowStart = elapsed - _rollingWindow;
      while (samples.length > 2 && samples[1].elapsed < windowStart) {
        samples.removeAt(0);
      }

      final oldest = samples.first;
      final sampleMicros = (elapsed - oldest.elapsed).inMicroseconds;
      final currentMbps = sampleMicros > 0
          ? ((totalBytes - oldest.bytes) * 8) / sampleMicros
          : 0.0;
      controller.add(
        SpeedTestUpdate(
          currentMbps: currentMbps,
          progress: (elapsed.inMicroseconds / duration.inMicroseconds).clamp(
            0.0,
            0.99,
          ),
          latencyMs: latencyMs,
        ),
      );

      if (warmUpElapsed == Duration.zero && elapsed >= _warmUpDuration) {
        warmUpElapsed = elapsed;
        warmUpBytes = totalBytes;
      }
    }

    Future<void> downloadWorker(int workerIndex) async {
      while (!requestCancelToken.isCancelled && stopwatch.elapsed < duration) {
        final uri = Uri.parse(url);
        final targetUrl = uri
            .replace(
              queryParameters: {
                ...uri.queryParameters,
                "_t": DateTime.now().microsecondsSinceEpoch.toString(),
                "_w": workerIndex.toString(),
              },
            )
            .toString();
        try {
          final requestStarted = stopwatch.elapsed;
          final response = await _dio.get<ResponseBody>(
            targetUrl,
            options: Options(
              responseType: ResponseType.stream,
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 5),
              validateStatus: (status) => status != null && status < 500,
              headers: const {
                "Accept": "*/*",
                "Cache-Control": "no-cache, no-store",
              },
            ),
            cancelToken: requestCancelToken,
          );
          if (response.statusCode != 200 || response.data == null) {
            throw DioException.badResponse(
              statusCode: response.statusCode ?? 0,
              requestOptions: response.requestOptions,
              response: response,
            );
          }
          latencyMs ??= (stopwatch.elapsed - requestStarted).inMilliseconds;
          await for (final chunk in response.data!.stream) {
            totalBytes += chunk.length;
            if (requestCancelToken.isCancelled ||
                stopwatch.elapsed >= duration) {
              break;
            }
          }
        } on DioException catch (error) {
          if (!requestCancelToken.isCancelled) {
            workerError ??= error;
            requestCancelToken.cancel("Speed test request failed");
          }
        } catch (error) {
          workerError ??= error;
          requestCancelToken.cancel("Speed test request failed");
        }
      }
    }

    try {
      if (parentCancelToken?.isCancelled == true) return;
      parentCancelToken?.whenCancel.then((error) {
        if (!requestCancelToken.isCancelled) requestCancelToken.cancel(error);
      });
      deadlineTimer = Timer(duration, () {
        if (!requestCancelToken.isCancelled) {
          requestCancelToken.cancel("Speed test completed");
        }
      });
      sampleTimer = Timer.periodic(_sampleInterval, (_) => emitSample());

      await Future.wait(List.generate(parallelDownloads, downloadWorker));
      emitSample();

      if (workerError != null && totalBytes == 0) throw workerError!;
      if (parentCancelToken?.isCancelled == true) return;

      final elapsed = stopwatch.elapsed;
      final measuredStart = warmUpElapsed == Duration.zero
          ? Duration.zero
          : warmUpElapsed;
      final measuredBytes = totalBytes - warmUpBytes;
      final measuredMicros = (elapsed - measuredStart).inMicroseconds;
      final finalMbps = measuredMicros > 0
          ? (measuredBytes * 8) / measuredMicros
          : 0.0;
      controller.add(
        SpeedTestUpdate(
          currentMbps: finalMbps,
          progress: 1,
          isDone: true,
          latencyMs: latencyMs,
        ),
      );
    } catch (error, stackTrace) {
      if (!controller.isClosed && parentCancelToken?.isCancelled != true) {
        controller.addError(error, stackTrace);
      }
    } finally {
      deadlineTimer?.cancel();
      sampleTimer?.cancel();
      stopwatch.stop();
      if (!requestCancelToken.isCancelled) {
        requestCancelToken.cancel("Speed test ended");
      }
      if (!controller.isClosed) await controller.close();
    }
  }
}

class _ByteSample {
  final Duration elapsed;
  final int bytes;

  const _ByteSample(this.elapsed, this.bytes);
}
