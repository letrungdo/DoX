import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/services/music_pairing_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

/// Where the phone is in signing a television in.
enum MusicTvPairStage { scanning, sending, done, failed }

class MusicTvPairViewModel extends CoreViewModel {
  MusicTvPairStage _stage = MusicTvPairStage.scanning;
  MusicTvPairStage get stage => _stage;

  /// What the television ended up signed in as, once [stage] is `done`.
  String _tvAccountName = '';
  String get tvAccountName => _tvAccountName;

  /// Why the last attempt failed, already translated.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// The last QR code that was not ours. A scanner reports the same code many
  /// times a second, and each of those is not worth a message of its own.
  String? _ignoredCode;

  /// Takes what the camera read. Anything but a television's code is
  /// reported once and then left alone while the camera stays on it.
  Future<void> onScanned(String raw) async {
    if (_stage != MusicTvPairStage.scanning || raw == _ignoredCode) return;
    final l10n = context.l10n;
    final code = MusicPairingCode.tryParse(raw);
    if (code == null) {
      _ignoredCode = raw;
      _errorMessage = l10n.musicPairTvNotACode;
      notifyListenersSafe();
      return;
    }
    final account = musicAuth.account;
    if (account == null || !account.isValid) {
      _fail(l10n.musicSignedOut);
      return;
    }

    _stage = MusicTvPairStage.sending;
    _errorMessage = null;
    notifyListenersSafe();
    try {
      final name = await sendMusicAccountToTv(code, account);
      _tvAccountName = name.isEmpty ? account.username : name;
      _stage = MusicTvPairStage.done;
      notifyListenersSafe();
    } on MusicPairingException catch (e) {
      _fail(switch (e.kind) {
        MusicPairingError.unreachable => l10n.musicPairTvUnreachable,
        MusicPairingError.rejected => l10n.musicPairTvRejected,
        MusicPairingError.unknown => l10n.musicPairTvFailed,
      });
    } catch (e, st) {
      logger.e('MusicTvPairViewModel failed', error: e, stackTrace: st);
      _fail(l10n.musicPairTvFailed);
    }
  }

  void scanAgain() {
    _stage = MusicTvPairStage.scanning;
    _errorMessage = null;
    _ignoredCode = null;
    notifyListenersSafe();
  }

  void _fail(String message) {
    _stage = MusicTvPairStage.failed;
    _errorMessage = message;
    notifyListenersSafe();
  }
}
