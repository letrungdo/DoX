import 'dart:async';

import 'package:do_x/utils/logger.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:video_editor/video_editor.dart';

class ExportService {
  static Future<void> dispose() async {
    final executions = await FFmpegKit.listSessions();
    if (executions.isNotEmpty) await FFmpegKit.cancel();
  }

  static Future<String?> runFFmpegCommand(
    FFmpegVideoEditorExecute? execute, {
    void Function(Object, StackTrace)? onError,
    void Function(Statistics)? onProgress,
    required void Function(String filePath) onCompleted,
  }) async {
    logger.d('FFmpeg start process with command = ${execute?.command}');
    final complete = Completer<String?>();
    try {
      if (execute == null) throw "execute null";
      FFmpegKit.executeAsync(
        execute.command,
        (session) async {
          final code = await session.getReturnCode();

          if (ReturnCode.isSuccess(code)) {
            onCompleted.call(execute.outputPath);
            return complete.complete(execute.outputPath);
          }
          final state = FFmpegKitConfig.sessionStateToString(await session.getState());
          if (onError != null) {
            onError(
              Exception('FFmpeg process exited with state $state and return code $code.\n${await session.getOutput()}'),
              StackTrace.current,
            );
          }
          return complete.complete();
        },
        null,
        onProgress,
      );
    } catch (e) {
      complete.complete();
      logger.e(e.toString(), error: e);
    }
    return complete.future;
  }
}
