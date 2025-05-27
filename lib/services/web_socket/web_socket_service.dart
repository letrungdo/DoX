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
  WebSocketChannel? _channel;

  final StreamController<RatePushModel> _rateController = StreamController.broadcast();
  Stream<RatePushModel> get rateStream => _rateController.stream;

  StreamSubscription<dynamic>? _streamSubscription;

  void connect(BuildContext context) async {
    final wssUrl = Uri.parse("wss://stream.finpath.vn");
    await disconnect();
    _channel = IOWebSocketChannel.connect(
      wssUrl,
      connectTimeout: Duration(seconds: 10), //
    );
    try {
      await _channel!.ready;

      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (!context.mounted) return;
          onReceiveData(context, message);
        },
        onError: (error) {
          debugPrint('[PUSH][onError] connection is disconnected');
          if (!context.mounted) return;
          onPushDisconnected(context);
        },
        onDone: () {
          if (!context.mounted) return;
          onPushDisconnected(context);
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
      onPushDisconnected(context);
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> disconnect() async {
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
