import 'dart:async';
import 'dart:io';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/model/rate_push_model.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class MacOSStatusBarService {
  static const _channel = MethodChannel('com.do_x.market/status_bar');

  StreamSubscription<RatePushModel>? _subscription;
  WebSocketService? _socketService;
  double? _lastPrice;

  /// Initializes the status bar service and listens for market updates.
  void init(WebSocketService webSocketService) {
    if (!Platform.isMacOS) return;
    _socketService = webSocketService;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAppChanged':
          final event = call.arguments['event'];
          final name = call.arguments['name'];
          debugPrint('MacOSStatusBarService: App $event: $name');

          // Show status bar and ensure socket is connected when apps are launched/terminated
          await setVisibility(true);
          _socketService?.connect();
          _fetchNews();
          break;
      }
    });

    _subscription?.cancel();
    _subscription = _socketService!.rateStream.listen((event) {
      if (event.code == MarketCode.xauUSD) {
        final currentPrice = event.price;
        if (currentPrice == null) return;

        String? colorHex;
        if (_lastPrice != null) {
          if (currentPrice > _lastPrice!) {
            colorHex = '#32D74B'; // System Vivid Green
          } else if (currentPrice < _lastPrice!) {
            colorHex = '#FF6961'; // Bright Pastel Red (pops on dark bg)
          }
        }

        updatePrice(currentPrice.toStringAsFixed(2), colorHex: colorHex);
        _lastPrice = currentPrice;
      }
    });

    // Initial price fetch to show something immediately before first push
    _fetchInitialPrice();

    // Initial news fetch
    _fetchNews();

    // Periodically update news every 30 minutes
    Timer.periodic(const Duration(minutes: 30), (_) => _fetchNews());
  }

  Future<void> _fetchNews() async {
    try {
      final FxRateService fxRateService = FxRateService();
      final res = await fxRateService.getGoldNews();
      final news = res.data;
      if (news != null) {
        // Use the current system locale if possible, fallback to 'vi'
        final summary = news.summary('vi');
        await updateNews(summary);
      }
    } catch (e) {
      debugPrint('Error fetching gold news for status bar: $e');
    }
  }

  Future<void> _fetchInitialPrice() async {
    try {
      final FxRateService fxRateService = FxRateService();
      final res = await fxRateService.getMarketOverviews(
        markets: [MarketCode.xauUSD],
      );
      final overview = res.data?[MarketCode.xauUSD];
      if (overview != null && overview.price != null) {
        _lastPrice = overview.price;
        await updatePrice(overview.price!.toStringAsFixed(2));
      }
    } catch (e) {
      debugPrint('Error fetching initial price for status bar: $e');
    }
  }

  /// Sends the AI news summary to the macOS status bar.
  Future<void> updateNews(String summary) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('updateNews', {'summary': summary});
    } catch (e) {
      debugPrint('Error updating news to status bar: $e');
    }
  }

  /// Sends the updated price and color to the macOS status bar.
  Future<void> updatePrice(String price, {String? colorHex}) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('updatePrice', {
        'price': price,
        'color': colorHex,
      });
    } catch (e) {
      debugPrint('Error updating price to status bar: $e');
    }
  }

  /// Controls the visibility of the status bar item.
  Future<void> setVisibility(bool visible) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('setVisibility', {'visible': visible});
    } catch (e) {
      debugPrint('Error setting status bar visibility: $e');
    }
  }

  /// Disposes of subscriptions when the service is no longer needed.
  void dispose() {
    _subscription?.cancel();
  }
}

final macOSStatusBarService = MacOSStatusBarService();
