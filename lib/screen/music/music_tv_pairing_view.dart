import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/services/music_pairing_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The television's sign-in: a QR code for a phone that is already signed in
/// to scan, instead of the service's sign-in page.
///
/// The page is not offered here at all. Its bot check wants a challenge solved
/// that a remote cannot reach, so on a television it is a dead end — see
/// [MusicPairingHost] for how the phone's account is brought over instead.
class MusicTvPairingView extends StatefulWidget {
  const MusicTvPairingView({
    super.key,
    required this.onToken,
    this.errorMessage,
    this.isSigningIn = false,
  });

  /// Signs this television in with the token a phone handed over, answering
  /// with the account's name, or `null` when it could not be used.
  final Future<String?> Function(String accessToken) onToken;

  /// What went wrong with the last hand-over, already translated.
  final String? errorMessage;

  /// A phone's token is being checked with the music service.
  final bool isSigningIn;

  @override
  State<MusicTvPairingView> createState() => _MusicTvPairingViewState();
}

class _MusicTvPairingViewState extends State<MusicTvPairingView> {
  MusicPairingHost? _host;
  MusicPairingCode? _code;

  /// Still opening the port, or there is no network to open it on.
  bool _isStarting = true;
  bool _noNetwork = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the translation for the page a phone's browser is shown, which is
    // not to be had in initState.
    if (_host == null) _start();
  }

  @override
  void dispose() {
    // Not forced: a phone whose token was just accepted is still waiting for
    // the answer, and the screen closing is what that answer causes.
    _host?.stop();
    super.dispose();
  }

  Future<void> _start() async {
    final host = _host ??= MusicPairingHost(
      onToken: widget.onToken,
      browserMessage: context.l10n.musicTvQrBrowserMessage,
    );
    setState(() {
      _isStarting = true;
      _noNetwork = false;
    });
    MusicPairingCode? code;
    try {
      code = await host.start();
    } on Object catch (e, st) {
      logger.e('Music pairing could not start', error: e, stackTrace: st);
    }
    if (!mounted) return;
    setState(() {
      _code = code;
      _isStarting = false;
      _noNetwork = code == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCode(),
              const SizedBox(width: 32),
              Expanded(child: _buildInstructions()),
            ],
          ),
        ).contentConstrainedBox(),
      ),
    );
  }

  Widget _buildCode() {
    final code = _code;
    const size = Dimens.musicPairingQrSize;
    const plate = size + Dimens.musicPairingQrPadding * 2;
    Widget child;
    if (_isStarting) {
      child = const Center(child: Loading());
    } else if (code == null) {
      child = Icon(
        Icons.wifi_off_rounded,
        size: 72,
        color: context.theme.colorScheme.onSurfaceVariant,
      );
    } else {
      child = Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimens.musicPairingQrPadding),
            child: QrImageView(
              data: code.uri.toString(),
              size: size,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ),
          if (widget.isSigningIn)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xCCFFFFFF),
                child: Center(child: Loading()),
              ),
            ),
        ],
      );
    }
    return Container(
      width: plate,
      height: plate,
      decoration: BoxDecoration(
        color: code == null
            ? context.theme.colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(Dimens.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildInstructions() {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final code = _code;
    final errorMessage = widget.errorMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.musicTvQrTitle, style: textTheme.title.size24.bold),
        const SizedBox(height: 16),
        if (_noNetwork)
          Text(l10n.musicTvQrNoNetwork, style: textTheme.primary.size18)
        else ...[
          for (final (index, step) in [
            l10n.musicTvQrStep1,
            l10n.musicTvQrStep2,
            l10n.musicTvQrStep3,
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${index + 1}. $step',
                style: textTheme.primary.size18,
              ),
            ),
          if (code != null)
            Text(
              l10n.musicTvQrAddress('${code.host}:${code.port}'),
              style: textTheme.secondary.size15,
            ),
        ],
        if (widget.isSigningIn) ...[
          const SizedBox(height: 12),
          Text(
            l10n.musicTvQrSigningIn,
            style: TextStyle(color: context.theme.colorScheme.primary),
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage,
            style: TextStyle(color: context.theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        // The one control on the page, so the remote has somewhere to be.
        DoButton(
          autofocus: true,
          onPressed: _isStarting || widget.isSigningIn ? null : _start,
          text: _noNetwork ? l10n.retry : l10n.musicTvQrNewCode,
        ),
      ],
    );
  }
}
