import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/music/music_tv_pair_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

/// The phone's half of signing a television in: scans the code the
/// television's Music sign-in shows and hands it this phone's account.
@RoutePage()
class MusicTvPairScreen extends StatefulScreen implements AutoRouteWrapper {
  const MusicTvPairScreen({super.key});

  @override
  State<MusicTvPairScreen> createState() => _MusicTvPairScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MusicTvPairViewModel(),
      child: this,
    );
  }
}

class _MusicTvPairScreenState
    extends ScreenState<MusicTvPairScreen, MusicTvPairViewModel> {
  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      vm.onScanned(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewModel = context.watch<MusicTvPairViewModel>();
    return AppScaffold(
      appBar: DoAppBar(title: l10n.musicPairTvTitle),
      body: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                l10n.musicPairTvScanHint,
                textAlign: TextAlign.center,
                style: context.textTheme.secondary.size13,
              ),
              const SizedBox(height: 16),
              Center(child: _buildWindow(viewModel)),
              const SizedBox(height: 16),
              ..._buildStatus(viewModel),
            ],
          ),
        ).contentConstrainedBox(),
      ),
    );
  }

  /// The camera while scanning, and the outcome in its place afterwards —
  /// the camera is not left running on a code that has already been used.
  Widget _buildWindow(MusicTvPairViewModel viewModel) {
    final colorScheme = context.theme.colorScheme;
    final Widget child = switch (viewModel.stage) {
      // Left to own its camera: it is taken down with the scanning stage and
      // put back when the user scans again, and a fresh one starts cleanly.
      MusicTvPairStage.scanning => MobileScanner(
        onDetect: _onDetect,
        errorBuilder: (context, _) => Padding(
          padding: Dimens.screenPadding,
          child: Center(
            child: Text(
              context.l10n.musicPairTvCameraError,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      MusicTvPairStage.sending => const Center(child: Loading()),
      MusicTvPairStage.done => Icon(
        Icons.tv_rounded,
        size: 72,
        color: colorScheme.primary,
      ),
      MusicTvPairStage.failed => Icon(
        Icons.error_outline_rounded,
        size: 72,
        color: colorScheme.error,
      ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: Dimens.musicPairingScannerMaxSize,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
          child: ColoredBox(
            color: colorScheme.surfaceContainerHighest,
            child: child,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStatus(MusicTvPairViewModel viewModel) {
    final l10n = context.l10n;
    final colorScheme = context.theme.colorScheme;
    final errorMessage = viewModel.errorMessage;
    return switch (viewModel.stage) {
      MusicTvPairStage.scanning => [
        if (errorMessage != null)
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
      ],
      MusicTvPairStage.sending => [
        Text(l10n.musicPairTvSending, textAlign: TextAlign.center),
      ],
      MusicTvPairStage.done => [
        Text(
          l10n.musicPairTvDone(viewModel.tvAccountName),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        DoButton(onPressed: () => context.router.maybePop(), text: l10n.close),
      ],
      MusicTvPairStage.failed => [
        Text(
          errorMessage ?? l10n.musicPairTvFailed,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.error),
        ),
        const SizedBox(height: 20),
        DoButton(onPressed: vm.scanAgain, text: l10n.musicPairTvScanAgain),
      ],
    };
  }
}
