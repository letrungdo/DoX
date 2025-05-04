import 'dart:typed_data';

import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_compress/video_compress.dart';

mixin CompressVideoMixin on CoreViewModel {
  bool _isCompressing = false;
  bool get isCompressingVideo => _isCompressing;

  double _compressProgress = 0;
  double get compressVideoProgress => _compressProgress;

  Uint8List? _videoCompressed;
  Uint8List? get videoCompressed => _videoCompressed;

  void clearCacheVideo() {
    if (_videoCompressed != null) {
      _videoCompressed = null;
      VideoCompress.deleteAllCache();
    }
  }

  void setCompressingVideo(bool value) {
    _isCompressing = value;
    _compressProgress = 0;
    notifyListenersSafe();
  }

  late Subscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      debugPrint('progress: $progress');
      _compressProgress = progress;
      notifyListenersSafe();
    });
  }

  @override
  void dispose() {
    _subscription.unsubscribe();
    cancelCompressVideo();
    super.dispose();
  }

  Future<Uint8List?> getVideoThumbnail(String videoPath) async {
    Uint8List? uint8list;
    try {
      uint8list = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 90, // default(100)
      );
    } catch (e) {
      //
    }
    return uint8list;
  }

  Future<MediaInfo?> compressVideo(String videoPath) async {
    setCompressingVideo(true);
    final mediaInfo = await VideoCompress.compressVideo(
      videoPath,
      quality: VideoQuality.HighestQuality,
      deleteOrigin: false, // It's false by default
    );
    _videoCompressed = await mediaInfo?.file?.readAsBytes();
    setCompressingVideo(false);
    return mediaInfo;
  }

  void cancelCompressVideo() {
    VideoCompress.cancelCompression();
  }
}
