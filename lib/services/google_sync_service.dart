import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/tasks/v1.dart' as tasks;
import 'package:intl/intl.dart';

class GoogleSyncService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [tasks.TasksApi.tasksScope, drive.DriveApi.driveAppdataScope]);

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (error) {
      print("Google Sign-In Error: $error");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<bool> syncToGoogleTasks(List<ChickenBatch> batches) async {
    if (_currentUser == null) {
      await signIn();
    }
    if (_currentUser == null) return false;

    final httpClient = (await _googleSignIn.authenticatedClient())!;
    final tasksApi = tasks.TasksApi(httpClient);

    final dateFormat = DateFormat('dd/MM/yyyy');

    for (var batch in batches) {
      final taskLists = await tasksApi.tasklists.list();
      String? listId;

      final existingList = taskLists.items?.firstWhereOrNull((l) => l.title == "Gà: ${batch.name}");

      if (existingList?.id != null) {
        listId = existingList!.id;
      } else {
        final newList = await tasksApi.tasklists.insert(tasks.TaskList(title: "Gà: ${batch.name}"));
        listId = newList.id;
      }

      if (listId == null) continue;

      final existingTasks = await tasksApi.tasks.list(listId);

      for (var v in batch.vaccinations) {
        final taskTitle = "${v.title} - ${batch.name}";
        final existingTask = existingTasks.items?.firstWhereOrNull((t) => t.title == taskTitle);

        final targetStatus = v.isCompleted ? 'completed' : 'needsAction';

        if (existingTask == null) {
          await tasksApi.tasks.insert(
            tasks.Task(
              title: taskTitle,
              notes: "Số lượng lứa: ${batch.quantity}. Ngày nở dự kiến: ${dateFormat.format(batch.expectedHatchDate)}",
              due: v.scheduledDate.toUtc().toIso8601String(),
              status: targetStatus,
            ),
            listId,
          );
        } else if (existingTask.status != targetStatus) {
          existingTask.status = targetStatus;
          await tasksApi.tasks.patch(existingTask, listId, existingTask.id!);
        }
      }
    }
    return true;
  }

  Future<bool> backupToDrive(List<ChickenBatch> batches, List<CockSale> cockSales) async {
    if (_currentUser == null) await signIn();
    if (_currentUser == null) return false;

    try {
      final httpClient = (await _googleSignIn.authenticatedClient())!;
      final driveApi = drive.DriveApi(httpClient);

      final data = {
        'batches': batches.map((e) => e.toJson()).toList(),
        'cockSales': cockSales.map((e) => e.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final jsonContent = jsonEncode(data);
      final bytes = utf8.encode(jsonContent);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      final fileList = await driveApi.files.list(spaces: 'appDataFolder', q: "name = 'dox_chicken_backup.json'");

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        final fileMetadata = drive.File()
          ..name = 'dox_chicken_backup.json'
          ..parents = ['appDataFolder'];
        await driveApi.files.create(fileMetadata, uploadMedia: media);
      }
      return true;
    } catch (e) {
      print("Drive Backup Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> restoreFromDrive() async {
    if (_currentUser == null) await signIn();
    if (_currentUser == null) return null;

    try {
      final httpClient = (await _googleSignIn.authenticatedClient())!;
      final driveApi = drive.DriveApi(httpClient);

      final fileList = await driveApi.files.list(spaces: 'appDataFolder', q: "name = 'dox_chicken_backup.json'");

      if (fileList.files == null || fileList.files!.isEmpty) return null;

      final fileId = fileList.files!.first.id!;
      final response = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final content = await utf8.decodeStream(response.stream);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print("Drive Restore Error: $e");
      return null;
    }
  }

  Future<bool> deleteTaskList(String batchName) async {
    if (_currentUser == null) return false;

    try {
      final httpClient = (await _googleSignIn.authenticatedClient())!;
      final tasksApi = tasks.TasksApi(httpClient);

      final taskLists = await tasksApi.tasklists.list();
      final targetTitle = "Gà: $batchName";
      final existingList = taskLists.items?.firstWhereOrNull((l) => l.title == targetTitle);

      if (existingList?.id != null) {
        await tasksApi.tasklists.delete(existingList!.id!);
        return true;
      }
    } catch (e) {
      print("Error deleting Google Task List: $e");
    }
    return false;
  }
}

final googleSyncService = GoogleSyncService();
