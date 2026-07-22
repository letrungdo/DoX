import 'dart:io';

import 'package:dio/dio.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/update_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';

enum UpdatePhase { idle, downloading, done, error }

/// Drives the background APK download and its fixed progress toast.
///
/// A single long-lived instance survives tab/route rebuilds. Progress is
/// persisted so that if the app is killed mid-download, [init] resumes from
/// the partial file on the next launch via an HTTP range request.
class UpdateController extends ChangeNotifier {
  UpdatePhase _phase = UpdatePhase.idle;
  UpdatePhase get phase => _phase;

  /// 0..1, or null while the total size is still unknown.
  double? _progress;
  double? get progress => _progress;

  AppUpdateInfo? _update;
  AppUpdateInfo? get update => _update;

  Object? _error;
  Object? get error => _error;

  /// The user closed the toast for this session; keep the file/state so it can
  /// be reopened, but hide the toast until the next relevant event.
  bool _dismissed = false;
  bool get dismissed => _dismissed;

  bool get hasActiveToast => !_dismissed && _phase != UpdatePhase.idle;

  /// Non-null while a download loop is running; awaited to know it has fully
  /// unwound (e.g. after cancelling to switch to a newer version).
  Future<void>? _downloadTask;
  CancelToken? _cancelToken;

  /// Restores any pending update saved by a previous run. If a download was in
  /// progress it auto-resumes; if it had already finished it shows the toast
  /// with the install button. Safe to call multiple times.
  ///
  /// This is the offline-friendly resume path. Call [reconcile] afterwards
  /// with the latest release from the network to switch to a newer version.
  Future<void> init() async {
    if (_phase != UpdatePhase.idle) return;

    final version = storageService.getPendingUpdateVersion();
    final url = storageService.getPendingUpdateUrl();
    if (version == null || url == null) return;

    // Already installed (running version >= pending): drop the stale record.
    if (!updateService.isNewerThanCurrent(version)) {
      await _clearAndDelete();
      return;
    }

    _update = AppUpdateInfo(
      version: version,
      apkUrl: url,
      releaseNotes: storageService.getPendingUpdateNotes(),
    );

    final done = storageService.getPendingUpdateDone();
    if (done && await _apkExists(_update!)) {
      _phase = UpdatePhase.done;
      _progress = 1;
      notifyListeners();
      return;
    }

    // Resume the interrupted download from its partial file.
    _phase = UpdatePhase.downloading;
    _progress = null;
    notifyListeners();
    _startDownload();
  }

  /// Reconciles whatever [init] restored with the [latest] release fetched from
  /// the network. When a newer version than the one being downloaded exists,
  /// the stale (possibly partial) download is cancelled and deleted, then the
  /// newer one starts. Passing null (offline / no newer release) keeps the
  /// resumed state untouched.
  Future<void> reconcile(AppUpdateInfo? latest) async {
    if (latest == null) return;

    // Same version already handled (resuming / downloading / downloaded).
    if (_update?.version == latest.version) return;

    // A different, newer version is available: throw away the old one.
    if (_update != null) {
      final stale = _update!;
      _cancelToken?.cancel();
      await _downloadTask; // let the cancelled loop finish unwinding
      await _deleteApk(stale);
    }

    await start(latest);
  }

  /// Starts a fresh background download for a freshly detected update.
  Future<void> start(AppUpdateInfo update) async {
    _update = update;
    _dismissed = false;
    await storageService.savePendingUpdate(
      version: update.version,
      url: update.apkUrl,
      notes: update.releaseNotes,
      done: false,
    );
    _phase = UpdatePhase.downloading;
    _progress = null;
    _error = null;
    notifyListeners();
    _startDownload();
  }

  /// Retries after an error (also used as the toast's "resume" action).
  void retry() {
    if (_downloadTask != null || _update == null) return;
    _error = null;
    _phase = UpdatePhase.downloading;
    notifyListeners();
    _startDownload();
  }

  /// Opens the Android installer for the downloaded APK.
  Future<void> install() async {
    final update = _update;
    if (update == null) return;
    try {
      await updateService.install(update);
    } catch (e) {
      logger.e("Open installer failed", error: e);
      _error = e;
      notifyListeners();
    }
  }

  /// Hides the toast for this session without deleting the download.
  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  void _startDownload() {
    if (_downloadTask != null) return;
    _downloadTask = _download().whenComplete(() {
      _downloadTask = null;
      _cancelToken = null;
    });
  }

  Future<void> _download() async {
    final update = _update;
    if (update == null) return;

    _cancelToken = CancelToken();
    try {
      await updateService.download(
        update,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _progress = received / total;
            notifyListeners();
          }
        },
      );
      await storageService.setPendingUpdateDone(true);
      _phase = UpdatePhase.done;
      _progress = 1;
      _error = null;
      // Re-surface the toast on completion so the install button is reachable
      // even if the user had closed the progress toast.
      _dismissed = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      _error = e;
      _phase = UpdatePhase.error;
      notifyListeners();
    }
  }

  Future<void> _clearAndDelete() async {
    final stale = _update;
    await storageService.clearPendingUpdate();
    if (stale != null) await _deleteApk(stale);
    _update = null;
  }

  Future<bool> _apkExists(AppUpdateInfo update) async {
    final path = await updateService.apkPath(update);
    return File(path).exists();
  }

  Future<void> _deleteApk(AppUpdateInfo update) async {
    try {
      final file = File(await updateService.apkPath(update));
      if (await file.exists()) await file.delete();
    } catch (e) {
      logger.e("Delete stale apk failed", error: e);
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}

final updateController = UpdateController();
