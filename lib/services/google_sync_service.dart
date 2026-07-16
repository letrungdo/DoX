import 'package:collection/collection.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/tasks/v1.dart' as tasks;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;
import 'package:intl/intl.dart';

class GoogleSyncService {
  static const List<String> _scopes = [tasks.TasksApi.tasksScope];

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize();
    _initialized = true;
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _ensureInitialized();
      _currentUser = await _googleSignIn.authenticate(scopeHint: _scopes);
      return _currentUser;
    } catch (error) {
      print("Google Sign-In Error: $error");
      return null;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Authorizes the required scopes for the current user and returns an
  /// authenticated client for use with the `googleapis` libraries.
  Future<gapis.AuthClient?> _authorizedClient() async {
    final user = _currentUser;
    if (user == null) return null;

    final authorization =
        await user.authorizationClient.authorizationForScopes(_scopes) ?? await user.authorizationClient.authorizeScopes(_scopes);

    return authorization.authClient(scopes: _scopes);
  }

  Future<bool> syncToGoogleTasks(List<ChickenBatch> batches) async {
    if (_currentUser == null) {
      await signIn();
    }
    if (_currentUser == null) return false;

    final httpClient = await _authorizedClient();
    if (httpClient == null) return false;
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

  Future<bool> deleteTaskList(String batchName) async {
    if (_currentUser == null) return false;

    try {
      final httpClient = (await _authorizedClient())!;
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
