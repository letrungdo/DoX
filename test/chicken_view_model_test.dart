import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/pending_op.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuth extends ChickenAuth {
  _FakeAuth({this.signedIn = true, this.id = 'user-1'});

  bool signedIn;
  String? id;
  final _changes = StreamController<AuthState>.broadcast();

  @override
  bool get isSignedIn => signedIn;

  @override
  String? get userId => id;

  @override
  Stream<AuthState> get changes => _changes.stream;

  void emit(AuthState state) => _changes.add(state);
}

/// Repository whose reads return [batches] and whose writes either land in
/// [applied] or throw [writeFailure], so both the offline queue and the
/// rollback path can be driven from a test.
class _FakeRepository extends ChickenRepository {
  List<ChickenBatch> batches = [];
  Object? readFailure;
  Object? writeFailure;

  /// Stands in for network latency: without it a fake write resolves in a
  /// single microtask, which is faster than any real request and hides races.
  Duration applyDelay = Duration.zero;
  int getBatchesCalls = 0;
  int getGlobalCockSalesCalls = 0;
  final applied = <PendingOp>[];

  /// Fails every call as if there were no connection.
  void goOffline() {
    readFailure = const SocketException('offline');
    writeFailure = const SocketException('offline');
  }

  void goOnline() {
    readFailure = null;
    writeFailure = null;
  }

  @override
  Future<List<ChickenBatch>> getBatches() async {
    getBatchesCalls++;
    if (readFailure != null) throw readFailure!;
    // A copy, like the real repository: the view model mutates the list it is
    // handed, and it must not reach back into what the server holds.
    return List.of(batches);
  }

  @override
  Future<List<CockSale>> getGlobalCockSales() async {
    getGlobalCockSalesCalls++;
    if (readFailure != null) throw readFailure!;
    return [];
  }

  @override
  Future<void> apply(PendingOp op) async {
    if (applyDelay > Duration.zero) await Future<void>.delayed(applyDelay);
    if (writeFailure != null) throw writeFailure!;
    applied.add(op);
  }
}

ChickenBatch _batch({
  String id = 'batch-1',
  List<Expense> expenses = const [],
}) {
  return ChickenBatch(
    id: id,
    name: 'Bầy 1',
    incubationDate: DateTime(2026, 7, 1),
    quantity: 10,
    expenses: expenses,
  );
}

Expense _expense({String id = 'expense-1'}) => Expense(
  id: id,
  type: ExpenseType.feed,
  amount: 50000,
  date: DateTime(2026, 7, 10),
  note: 'Cám',
);

CockSale _cockSale({double amount = 1}) => CockSale(
  id: 'sale-1',
  note: 'gà',
  amount: amount,
  date: DateTime(2026, 7, 12),
  category: SaleCategory.fighting,
);

/// A cache as written by a previous session of [userId].
String _cache({
  required String userId,
  required List<ChickenBatch> batches,
  required DateTime syncedAt,
  int version = 1,
}) {
  return jsonEncode({
    'version': version,
    'userId': userId,
    'batches': batches,
    'batchesSyncedAt': syncedAt.toIso8601String(),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  setUp(() async {
    await storageService.clearChickenCache();
    await storageService.clearChickenSyncQueue();
  });

  group('cache restore', () {
    test('shows the previous session\'s batches before the API answers', () {
      final syncedAt = DateTime(2026, 7, 27, 14, 32);
      storageService.setChickenCache(
        _cache(userId: 'user-1', batches: [_batch()], syncedAt: syncedAt),
      );

      final vm = ChickenViewModel(
        repository: _FakeRepository(),
        auth: _FakeAuth(),
      );
      vm.initState();

      expect(vm.batches.single.id, 'batch-1');
      expect(vm.batchesSync.syncedAt, syncedAt);
      expect(vm.batchesSync.refreshFailed, isFalse);
      vm.dispose();
    });

    test('ignores a cache written by another account', () {
      storageService.setChickenCache(
        _cache(
          userId: 'someone-else',
          batches: [_batch()],
          syncedAt: DateTime(2026, 7, 27),
        ),
      );

      final vm = ChickenViewModel(
        repository: _FakeRepository(),
        auth: _FakeAuth(id: 'user-1'),
      );
      vm.initState();

      expect(vm.batches, isEmpty);
      vm.dispose();
    });

    test('ignores a cache written by an older app version', () {
      storageService.setChickenCache(
        _cache(
          userId: 'user-1',
          batches: [_batch()],
          syncedAt: DateTime(2026, 7, 27),
          version: 0,
        ),
      );

      final vm = ChickenViewModel(
        repository: _FakeRepository(),
        auth: _FakeAuth(),
      );
      vm.initState();

      expect(vm.batches, isEmpty);
      vm.dispose();
    });

    test('restores nothing while signed out', () {
      storageService.setChickenCache(
        _cache(
          userId: 'user-1',
          batches: [_batch()],
          syncedAt: DateTime(2026, 7, 27),
        ),
      );

      final vm = ChickenViewModel(
        repository: _FakeRepository(),
        auth: _FakeAuth(signedIn: false),
      );
      vm.initState();

      expect(vm.batches, isEmpty);
      vm.dispose();
    });

    test(
      'keeps cached data on screen when the refresh fails, marked stale',
      () async {
        final syncedAt = DateTime(2026, 7, 27, 14, 32);
        storageService.setChickenCache(
          _cache(userId: 'user-1', batches: [_batch()], syncedAt: syncedAt),
        );
        final repository = _FakeRepository()
          ..readFailure = const SocketException('offline');

        final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
        vm.initState();
        await vm.ensureBatchesLoaded();

        expect(repository.getBatchesCalls, 1);
        expect(vm.batches.single.id, 'batch-1', reason: 'cached data stays');
        expect(vm.batchesSync.refreshFailed, isTrue);
        expect(vm.batchesSync.syncedAt, syncedAt, reason: 'still the old time');
        // The spinner must not run over data that is already on screen.
        expect(vm.isBatchesLoading, isFalse);
        vm.dispose();
      },
    );

    test(
      'a successful refresh replaces the data and clears the stale flag',
      () async {
        storageService.setChickenCache(
          _cache(
            userId: 'user-1',
            batches: [_batch()],
            syncedAt: DateTime(2026, 7, 27),
          ),
        );
        final repository = _FakeRepository()
          ..readFailure = const SocketException('offline');
        final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
        vm.initState();
        await vm.ensureBatchesLoaded();
        expect(vm.batchesSync.refreshFailed, isTrue);

        repository
          ..readFailure = null
          ..batches = [_batch(id: 'batch-2')];
        await vm.loadBatches();

        expect(vm.batches.single.id, 'batch-2');
        expect(vm.batchesSync.refreshFailed, isFalse);
        expect(vm.batchesSync.syncedAt, isNotNull);
        vm.dispose();
      },
    );
  });

  group('cache write', () {
    test('persists fetched data for the next launch', () async {
      final repository = _FakeRepository()..batches = [_batch()];
      final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
      vm.initState();
      await vm.ensureBatchesLoaded();

      // dispose() flushes the debounced write.
      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final raw = storageService.getChickenCache();
      expect(raw, isNotNull);
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      expect(data['userId'], 'user-1');
      expect((data['batches'] as List).single['id'], 'batch-1');
      expect(data['batchesSyncedAt'], isNotNull);
    });

    test('drops the cache on sign-out', () async {
      final repository = _FakeRepository()..batches = [_batch()];
      final auth = _FakeAuth();
      final vm = ChickenViewModel(repository: repository, auth: auth);
      vm.initState();
      await vm.ensureBatchesLoaded();
      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(storageService.getChickenCache(), isNotNull);

      final signedOutVm = ChickenViewModel(repository: repository, auth: auth);
      signedOutVm.initState();
      auth
        ..signedIn = false
        ..id = null;
      auth.emit(const AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(signedOutVm.batches, isEmpty);
      expect(storageService.getChickenCache(), isNull);
      signedOutVm.dispose();
    });
  });

  group('write rollback', () {
    test('undoes an expense the server rejected', () async {
      final repository = _FakeRepository()..batches = [_batch()];
      final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
      vm.initState();
      await vm.ensureBatchesLoaded();

      repository.writeFailure = PostgrestException(
        message: 'row level security',
        code: '42501',
      );
      await expectLater(
        vm.addExpense('batch-1', _expense()),
        throwsA(isA<PostgrestException>()),
      );

      expect(
        vm.batches.single.expenses,
        isEmpty,
        reason: 'a record the server never took must not linger locally',
      );
      vm.dispose();
    });

    test('keeps an expense the server accepted', () async {
      final repository = _FakeRepository()..batches = [_batch()];
      final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
      vm.initState();
      await vm.ensureBatchesLoaded();

      await vm.addExpense('batch-1', _expense());

      expect(vm.batches.single.expenses.single.id, 'expense-1');
      expect(repository.applied.single.target, 'expenses');
      vm.dispose();
    });

    test('a rejected write is not left behind in the cache', () async {
      final repository = _FakeRepository()..batches = [_batch()];
      final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
      vm.initState();
      await vm.ensureBatchesLoaded();

      repository.writeFailure = PostgrestException(message: 'nope');
      await vm.addExpense('batch-1', _expense()).catchError((_) {});

      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final data =
          jsonDecode(storageService.getChickenCache()!) as Map<String, dynamic>;
      final cachedBatch = (data['batches'] as List).single;
      expect(cachedBatch['expenses'], isEmpty);
    });
  });

  group('offline writes', () {
    /// A view model that already holds one batch loaded from the server.
    Future<(ChickenViewModel, _FakeRepository)> loadedVm({
      _FakeAuth? auth,
    }) async {
      final repository = _FakeRepository()..batches = [_batch()];
      final vm = ChickenViewModel(
        repository: repository,
        auth: auth ?? _FakeAuth(),
      );
      vm.initState();
      await vm.ensureBatchesLoaded();
      return (vm, repository);
    }

    test(
      'an edit made offline is kept and queued instead of thrown away',
      () async {
        final (vm, repository) = await loadedVm();
        repository.goOffline();

        // No throw: as far as the user is concerned the expense is saved.
        await vm.addExpense('batch-1', _expense());

        expect(vm.batches.single.expenses.single.id, 'expense-1');
        expect(vm.pendingChangeCount, 1);
        vm.dispose();
      },
    );

    test('queued changes are pushed on the next load, oldest first', () async {
      final (vm, repository) = await loadedVm();
      repository.goOffline();
      await vm.addExpense('batch-1', _expense());
      await vm.addExpense('batch-1', _expense(id: 'expense-2'));
      await vm.deleteExpense('batch-1', 'expense-1');
      expect(vm.pendingChangeCount, 3);

      repository.goOnline();
      await vm.loadBatches();

      expect(vm.pendingChangeCount, 0);
      expect(
        repository.applied.map((op) => '${op.action.name} ${op.rowId ?? ''}'),
        ['insert ', 'insert ', 'delete expense-1'],
        reason: 'order is what makes the replay safe',
      );
      vm.dispose();
    });

    test(
      'a load does not overwrite changes that have not synced yet',
      () async {
        final (vm, repository) = await loadedVm();
        repository.goOffline();
        await vm.addExpense('batch-1', _expense());

        // The server still holds the batch without the expense.
        repository
          ..readFailure = null
          ..batches = [_batch()];
        await vm.loadBatches();

        expect(
          vm.batches.single.expenses.single.id,
          'expense-1',
          reason: 'the unsynced local edit is the newer truth',
        );
        expect(vm.pendingChangeCount, 1);
        vm.dispose();
      },
    );

    test('a write the server rejects is rolled back, not queued', () async {
      final (vm, repository) = await loadedVm();
      repository.writeFailure = PostgrestException(
        message: 'row level security',
        code: '42501',
      );

      await expectLater(
        vm.addExpense('batch-1', _expense()),
        throwsA(isA<PostgrestException>()),
      );

      expect(vm.batches.single.expenses, isEmpty);
      expect(vm.pendingChangeCount, 0, reason: 'retrying would never succeed');
      vm.dispose();
    });

    test('the queue survives an app restart', () async {
      final (vm, repository) = await loadedVm();
      repository.goOffline();
      await vm.addExpense('batch-1', _expense());
      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final restarted = ChickenViewModel(
        repository: repository,
        auth: _FakeAuth(),
      );
      restarted.initState();
      expect(restarted.pendingChangeCount, 1);
      expect(
        restarted.batches.single.expenses.single.id,
        'expense-1',
        reason: 'the cache holds the matching local state',
      );

      repository.goOnline();
      await restarted.loadBatches();
      expect(restarted.pendingChangeCount, 0);
      expect(repository.applied.single.target, 'expenses');
      restarted.dispose();
    });

    test('queued changes outlive a sign-out, unlike the cache', () async {
      final auth = _FakeAuth();
      final (vm, repository) = await loadedVm(auth: auth);
      repository.goOffline();
      await vm.addExpense('batch-1', _expense());

      auth
        ..signedIn = false
        ..id = null;
      auth.emit(const AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(storageService.getChickenCache(), isNull);
      expect(
        storageService.getChickenSyncQueue(),
        isNotNull,
        reason: 'work the user believes is saved must not vanish',
      );
      vm.dispose();
    });

    test(
      'a queued change the server later refuses is dropped and counted',
      () async {
        final (vm, repository) = await loadedVm();
        repository.goOffline();
        await vm.addExpense('batch-1', _expense());

        repository
          ..readFailure = null
          ..writeFailure = PostgrestException(message: 'gone', code: '23503');
        await vm.loadBatches();

        expect(vm.pendingChangeCount, 0, reason: 'it can never succeed');
        expect(vm.discardedChangeCount, 1);
        vm.acknowledgeDiscardedChanges();
        expect(vm.discardedChangeCount, 0);
        vm.dispose();
      },
    );

    test('an offline batch insert replays as one atomic rpc', () async {
      final (vm, repository) = await loadedVm();
      repository.goOffline();
      final added = await vm.addBatch(
        name: 'Bầy 2',
        incubationDate: DateTime(2026, 8, 1),
        quantity: 20,
      );
      expect(vm.batches.map((b) => b.id), contains(added.id));
      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Restart, so the op also has to survive a JSON round trip.
      final restarted = ChickenViewModel(
        repository: repository,
        auth: _FakeAuth(),
      );
      restarted.initState();
      repository.goOnline();
      await restarted.loadBatches();

      final op = repository.applied.single;
      expect(op.action, PendingOpAction.rpc);
      expect(op.target, 'insert_chicken_batch');
      expect((op.payload['p_batch'] as Map)['name'], 'Bầy 2');
      expect(
        (op.payload['p_vaccinations'] as List),
        hasLength(5),
        reason: 'the default schedule travels with the batch',
      );
      restarted.dispose();
    });

    test('an offline edit of a global expense keeps its owner scope', () async {
      final repository = _FakeRepository();
      final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
      vm.initState();
      await vm.addGlobalExpense(_expense());
      repository.applied.clear();
      repository.goOffline();

      await vm.updateGlobalExpense(
        Expense(
          id: 'expense-1',
          type: ExpenseType.medicine,
          amount: 90000,
          date: DateTime(2026, 7, 11),
          note: 'Thuốc',
        ),
      );
      await vm.deleteGlobalExpense('expense-1');
      expect(vm.globalExpenses, isEmpty);
      expect(vm.pendingChangeCount, 2);

      repository.goOnline();
      await vm.loadExpenses();

      expect(
        repository.applied.every((op) => op.globalRecord),
        isTrue,
        reason: 'a replayed write must stay scoped to the user\'s own records',
      );
      vm.dispose();
    });

    test(
      'two sections loading at once both refresh after the queue drains',
      () async {
        final (vm, repository) = await loadedVm();
        repository.goOffline();
        await vm.addExpense('batch-1', _expense());
        repository
          ..goOnline()
          ..applyDelay = const Duration(milliseconds: 20);
        final batchLoadsBefore = repository.getBatchesCalls;

        // The statistics screen asks for every section in the same frame.
        await Future.wait([vm.loadBatches(), vm.loadCockSales()]);

        expect(vm.pendingChangeCount, 0);
        expect(repository.getBatchesCalls, batchLoadsBefore + 1);
        expect(
          repository.getGlobalCockSalesCalls,
          1,
          reason: 'a load that waited for the sync must still fetch afterwards',
        );
        vm.dispose();
      },
    );

    test(
      'a delete the server refuses stops hiding the batch locally',
      () async {
        final (vm, repository) = await loadedVm();
        repository.goOffline();
        await vm.deleteBatch('batch-1');
        expect(vm.batches, isEmpty);

        // Back online, but the server refuses the delete.
        repository
          ..readFailure = null
          ..writeFailure = PostgrestException(message: 'gone', code: '23503');
        await vm.loadBatches();

        expect(vm.discardedChangeCount, 1);
        expect(
          vm.batches.single.id,
          'batch-1',
          reason: 'the server still has it, so the user must see it again',
        );
        vm.dispose();
      },
    );

    test('repeated edits of one record collapse into a single write', () async {
      final (vm, repository) = await loadedVm();
      repository.goOffline();
      final vaccinationId = _batch().vaccinations.firstOrNull?.id;
      expect(vaccinationId, isNull, reason: 'this batch has no vaccinations');

      await vm.updateGlobalCockSale(_cockSale());
      await vm.addGlobalCockSale(_cockSale());
      await vm.updateGlobalCockSale(_cockSale(amount: 2));
      await vm.updateGlobalCockSale(_cockSale(amount: 3));
      expect(
        vm.pendingChangeCount,
        2,
        reason: 'the two trailing updates of the same row are one write',
      );

      repository.goOnline();
      await vm.loadCockSales();
      expect(repository.applied.last.payload['amount'], 3);
      vm.dispose();
    });

    test('bulk actions refuse to run on top of unsynced changes', () async {
      final (vm, repository) = await loadedVm();
      repository.goOffline();
      await vm.addExpense('batch-1', _expense());

      await expectLater(vm.deleteAllData(), throwsA(isA<StateError>()));
      vm.dispose();
    });
  });
}
