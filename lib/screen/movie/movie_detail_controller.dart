/// Lets the movie overlay host give the embedded detail screen the first say on
/// BACK, without coupling route arguments to the deferred screen library.
///
/// Both pages sit on the one route, so a `PopScope` on each is told of every
/// press. Rather than have them both act — which shut the episode grid and
/// left full screen on the same press — the detail screen keeps its ladder to
/// itself and the host asks for it here.
class MovieDetailController {
  bool Function()? _onBack;

  /// Whether the detail screen used the press up itself, in which case the
  /// overlay around it should stay exactly where it is.
  bool handleBack() => _onBack?.call() ?? false;

  void attach(bool Function() onBack) => _onBack = onBack;

  void detach(bool Function() onBack) {
    if (_onBack == onBack) _onBack = null;
  }
}
