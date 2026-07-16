import 'dart:async';
import 'dart:convert';

import 'package:do_x/model/rate_push_model.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:toastification/toastification.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const _maxRetries = 3;

  WebSocketChannel? _channel;

  final StreamController<RatePushModel> _rateController = StreamController.broadcast();
  Stream<RatePushModel> get rateStream => _rateController.stream;

  StreamSubscription<dynamic>? _streamSubscription;

  /// Set while [disconnect] is intentional (tab hidden, app backgrounded) so
  /// the onDone/onError callbacks don't retry or show an error toast.
  bool _manuallyClosed = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  void connect(BuildContext context) {
    _retryCount = 0;
    _connect(context);
  }

  void _connect(BuildContext context) async {
    final wssUrl = Uri.parse("wss://stream.finpath.vn");
    await disconnect();
    _manuallyClosed = false;
    _channel = IOWebSocketChannel.connect(
      wssUrl,
      connectTimeout: Duration(seconds: 10), //
    );
    try {
      await _channel!.ready;
      _retryCount = 0;

      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (!context.mounted) return;
          onReceiveData(context, message);
        },
        onError: (error) {
          debugPrint('[PUSH][onError] connection is disconnected');
          if (!context.mounted) return;
          _handleDisconnected(context);
        },
        onDone: () {
          if (!context.mounted) return;
          _handleDisconnected(context);
        },
      );
      // sendMessage({
      //   "type": "sub",
      //   "payload": {"event": "on_interval_model_overviewIndex", "timeFrame": "3s"},
      // });
      // sendMessage({
      //   "type": "sub",
      //   "payload": {"event": "on_interval_model_roomStock"},
      // });
      sendMessage({
        "type": "sub",
        "payload": {"event": "on_model_overviewCrypto"},
      });
      // sendMessage({
      //   "type": "sub",
      //   "payload": {
      //     "event": "on_model_overviewIndex_V2",
      //     "codes": ["VNIndex", "VN30", "HNXIndex", "HNX30", "HNXUpcomIndex"],
      //   },
      // });
      // sendMessage({
      //   "type": "sub",
      //   "payload": {"event": "on_model_overviewIndice"},
      // });
      sendMessage({
        "type": "sub",
        "payload": {"event": "on_model_overviewCommodity"},
      });
      // sendMessage({
      //   "type": "sub",
      //   "payload": {
      //     "event": "on_model_overviewIndex_V2",
      //     "codes": ["VNIndex", "VN30", "HNXIndex", "HNX30", "HNXUpcomIndex"],
      //   },
      // });
      // sendMessage({
      //   "type": "sub",
      //   "payload": {"event": "on_model_overviewSector_V2"},
      // });
      // sendMessage({
      //   "type": "sub",
      //   "payload": {"event": "on_interval_model_overviewStock", "timeFrame": "3s"},
      // });
      // sendMessage({
      //   "type": "sub",
      //   "payload": {
      //     "event": "on_model_indexBar",
      //     "codes": ["HNXUpcomIndex", "HNXIndex", "VN30", "HNX30", "VNIndex"],
      //   },
      // });
    } catch (e) {
      debugPrint('Web Socket: connect exception $e');
      if (!context.mounted) return;
      _handleDisconnected(context);
    }
  }

  /// Silently retries up to [_maxRetries] times before surfacing the error.
  void _handleDisconnected(BuildContext context) {
    if (_manuallyClosed || !context.mounted) return;
    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint('[PUSH] reconnecting silently, attempt $_retryCount/$_maxRetries');
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: 2 * _retryCount), () {
        if (!context.mounted) return;
        _connect(context);
      });
    } else {
      onPushDisconnected(context);
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      _channel?.sink.close();
      _streamSubscription?.cancel();
      _channel = null;
      _streamSubscription = null;
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
  }

  void onPushDisconnected(BuildContext context) {
    toastification.show(
      context: context,
      closeButton: ToastCloseButton(showType: CloseButtonShowType.none),
      type: ToastificationType.error,
      alignment: Alignment.topCenter,
      backgroundColor: Colors.white.withAlpha(230),
      icon: SFIcon(SFIcons.sf_xmark_icloud_fill),
      title: Text('Push Disconnected. Please tap to retry!'),
      callbacks: ToastificationCallbacks(
        onTap: (toastItem) {
          toastification.dismiss(toastItem);
          connect(context);
        },
      ),
    );
  }

  void onRetry() {}

  void onReceiveData(BuildContext context, dynamic message) {
    final rawData = jsonDecode(message) as Map<String, dynamic>;
    switch (rawData["event"]) {
      case "ping":
        sendMessage({"event": "pong2"});
        break;
      case "pong":
        sendMessage({"event": "ping"});
        break;
      case "on_model_overviewCommodity":
      case "on_model_overviewCrypto":
        try {
          final payload = RatePushModel.fromJson(rawData["payload"]);
          _rateController.add(payload);
        } catch (e) {
          logger.e(e.toString(), error: e);
        }
        break;
    }
    // debugPrint("onReceiveData $message");
  }
}
