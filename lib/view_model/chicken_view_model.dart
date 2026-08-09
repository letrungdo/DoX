import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/pending_op.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/services/chicken_import_service.dart';
import 'package:do_x/services/chicken_recent_changes.dart';
import 'package:do_x/services/chicken_sync_queue.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/utils/sale_price_suggestion.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// The slice of authentication the chicken data depends on. It exists as a
/// class so tests can drive the signed-in state without a real Supabase
/// session; production uses the default implementation over [supabase].
class ChickenAuth {
  const ChickenAuth();

  bool get isSignedIn => supabase.auth.currentSession != null;

  String? get userId => supabase.auth.currentUser?.id;

  Stream<AuthState> get changes => supabase.auth.onAuthStateChange;
}

class ChickenViewModel extends CoreViewModel {
  ChickenViewModel({
    ChickenRepository? repository,
    ChickenAuth auth = const ChickenAuth(),
  }) : _repository = repository ?? ChickenRepository(),
       _auth = auth;

  final ChickenRepository _repository;
  final ChickenAuth _auth;
  final _uuid = const Uuid();

  List<ChickenDataSource> _dataSources = [];
  List<ChickenDataSource> get dataSources => _dataSources;

  List<ChickenShareViewer> _shareViewers = [];
  List<ChickenShareViewer> get shareViewers => _shareViewers;

  String? _activeOwnerId;
  String? _activeOwnerEmail;
  String? _selectionRestoredForUserId;

  String? get activeOwnerId => _activeOwnerId ?? _auth.userId;
  String? get activeOwnerEmail => _activeOwnerEmail;
  bool get isReadOnly => activeOwnerId != null && activeOwnerId != _auth.userId;

  /// Restores only a selection written by the currently signed-in account.
  /// Access is validated against [dataSources] by [loadSharing] before the
  /// selected owner's data is trusted.
  void _restoreDataSourceSelection() {
    final userId = _auth.userId;
    if (userId == null || _selectionRestoredForUserId == userId) return;
    _selectionRestoredForUserId = userId;
    try {
      final raw = storageService.getChickenDataSourceSelection();
      if (raw == null) {
        _activeOwnerId = userId;
        _activeOwnerEmail = null;
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1 || data['userId'] != userId) {
        _activeOwnerId = userId;
        _activeOwnerEmail = null;
        return;
      }
      _activeOwnerId = data['ownerId'] as String? ?? userId;
      _activeOwnerEmail = data['ownerEmail'] as String?;
    } catch (e) {
      logger.e('restore chicken data source failed', error: e);
      _activeOwnerId = userId;
      _activeOwnerEmail = null;
    }
  }

  Future<void> _saveDataSourceSelection(ChickenDataSource source) async {
    final userId = _auth.userId;
    if (userId == null) return;
    await storageService.setChickenDataSourceSelection(
      jsonEncode({
        'version': 1,
        'userId': userId,
        'ownerId': source.ownerId,
        'ownerEmail': source.email,
      }),
    );
  }

  List<ChickenBatch> _batches = [];
  List<ChickenBatch> get batches => _batches;

  // Ids of batches deleted locally whose server delete may still be settling.
  // A batch load in flight can return a stale snapshot that still contains a
  // just-deleted batch; we filter those out so it doesn't reappear.
  final Set<String> _pendingDeletedBatchIds = {};

  List<CockSale> _globalCockSales = [];
  List<CockSale> get globalCockSales => _globalCockSales;

  List<Expense> _globalExpenses = [];
  List<Expense> get globalExpenses => _globalExpenses;

  // The suggestion lists below read across sections. A screen only fetches the
  // section it shows, so the other sections are whatever the last load or the
  // restored cache left in memory — recent enough for suggestions, and never
  // empty in practice because the cache holds every section it has ever seen.

  /// Distinct, non-empty notes in the order given, keeping the first occurrence
  /// — callers pass records sorted newest-first so recent notes come first.
  List<String> _distinctNotes(Iterable<String?> notes) {
    final seen = <String>{};
    final result = <String>[];
    for (final note in notes) {
      final trimmed = note?.trim() ?? '';
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      result.add(trimmed);
    }
    return result;
  }

  /// Previously used notes for cock-sale records (global + per batch), newest
  /// first.
  List<String> get cockSaleNoteSuggestions {
    final sales = [..._globalCockSales, ..._batches.expand((b) => b.cockSales)]
      ..sort((a, b) => b.date.compareTo(a.date));
    return _distinctNotes(sales.map((s) => s.note));
  }

  /// Previously used notes for batch-sale records, newest first.
  List<String> get batchSaleNoteSuggestions {
    final sales = _batches.expand((b) => b.sales).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return _distinctNotes(sales.map((s) => s.note));
  }

  /// Suggested price per chicken for a sale at [ageInDays] days old, read from
  /// every past sale round of every batch. Null until there is a past round to
  /// learn from. [excludeSaleId] leaves out the round being edited.
  SalePriceSuggestion? salePriceSuggestion({
    required int ageInDays,
    String? excludeSaleId,
  }) => suggestSaleUnitPrice(
    batches: _batches,
    ageInDays: ageInDays,
    excludeSaleId: excludeSaleId,
  );

  /// Previously used notes for expense records (global + per batch), newest
  /// first.
  List<String> get expenseNoteSuggestions {
    final expenses = [..._globalExpenses, ..._batches.expand((b) => b.expenses)]
      ..sort((a, b) => b.date.compareTo(a.date));
    return _distinctNotes(expenses.map((e) => e.note));
  }

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  double _importProgress = 0;
  double get importProgress => _importProgress;

  bool _useLunarCalendar = storageService.getChickenLunarDisplay();

  /// Whether chicken dates are displayed on the lunar calendar (default) or
  /// on the solar one. Stored dates are always solar values.
  bool get useLunarCalendar => _useLunarCalendar;

  Future<void> setUseLunarCalendar(bool value) async {
    if (_useLunarCalendar == value) return;
    _useLunarCalendar = value;
    notifyListenersSafe();
    await storageService.setChickenLunarDisplay(value);
  }

  final ChickenRecentChanges _recentChanges = ChickenRecentChanges();

  /// Badge a record should show in the lists ("new" / "edited"), or null when it
  /// has not changed recently. Keyed by record id, so it works for batches,
  /// sales and expenses alike.
  RecordChange? changeBadgeOf(String id) => _recentChanges.statusOf(id);

  /// Year of a stored (solar) [date] in the currently displayed calendar:
  /// the lunar year in lunar mode, the solar year in solar mode. Used by the
  /// year filters/grouping so they match the statistics.
  int displayYear(DateTime date) => _useLunarCalendar
      ? LunarCalendar.solarToLunar(date.day, date.month, date.year).year
      : date.year;

  /// The year containing today in the calendar currently shown by the app.
  /// [now] is injectable so the lunar-new-year boundary can be tested.
  int currentDisplayYear([DateTime? now]) => displayYear(now ?? DateTime.now());

  StreamSubscription<AuthState>? _authSub;

  // --- Local cache ----------------------------------------------------------
  // The screens show the data cached from the previous session right away and
  // refresh from the API in the background, so opening the tab is never empty.

  // 4: dates switched from lunar to solar values. A cache written by an older
  // build holds lunar dates, which this build would read as solar and show
  // about a month out, so it has to be discarded rather than migrated.
  static const _cacheVersion = 4;
  static const _cacheSaveDelay = Duration(milliseconds: 500);

  bool _cacheRestored = false;
  bool _restoringCache = false;
  Timer? _cacheSaveTimer;

  /// Loads the data cached on disk into memory. Runs once per app launch, as
  /// soon as a session is available (restoring it is async, so this is retried
  /// from the auth listener); a cache written by another account is discarded.
  void _restoreFromCache() {
    if (_cacheRestored || !_auth.isSignedIn || isReadOnly) return;
    _cacheRestored = true;
    // Writes made offline in an earlier session go back on the queue, and are
    // pushed by the first load that follows.
    _queue.restore(_auth.userId);
    _scheduleSyncRetry();
    final raw = storageService.getChickenCache();
    if (raw == null) return;
    _restoringCache = true;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != _cacheVersion || data['userId'] != _auth.userId) {
        unawaited(storageService.clearChickenCache());
        return;
      }
      List<T>? decode<T>(
        String key,
        T Function(Map<String, dynamic>) fromJson,
      ) {
        final list = data[key] as List?;
        return list
            ?.map((e) => fromJson(e as Map<String, dynamic>))
            .toList(growable: true);
      }

      final syncedAt = (data['syncedAt'] as Map?) ?? const {};
      final years = (data['years'] as Map?) ?? const {};
      for (final section in ChickenSection.values) {
        final stored = years[section.name] as List?;
        if (stored != null) {
          _serverYears[section] = stored.map((y) => (y as num).toInt()).toSet();
        }
      }
      void restore<T>(
        ChickenSection section,
        String key,
        T Function(Map<String, dynamic>) fromJson,
        void Function(List<T> value) assign,
      ) {
        // A section already fetched from the server wins: never fall back to
        // the cache if a load won the race with the session restore.
        if (_loadedSections.contains(section)) return;
        final restored = decode(key, fromJson);
        if (restored == null) return;
        assign(restored);
        _loadedSections.add(section);
        final at = DateTime.tryParse(syncedAt[section.name] as String? ?? '');
        if (at != null) _syncedAt[section] = at;
      }

      restore<ChickenBatch>(
        ChickenSection.batches,
        'batches',
        ChickenBatch.fromJson,
        (value) => _batches = value,
      );
      restore<CockSale>(
        ChickenSection.globalCockSales,
        'cockSales',
        CockSale.fromJson,
        (value) => _globalCockSales = value,
      );
      restore<Expense>(
        ChickenSection.globalExpenses,
        'expenses',
        Expense.fromJson,
        (value) => _globalExpenses = value,
      );
      notifyListenersSafe();
    } catch (e) {
      logger.e('restore chicken cache failed', error: e);
      unawaited(storageService.clearChickenCache());
    } finally {
      _restoringCache = false;
    }
  }

  // --- Offline writes -------------------------------------------------------
  // Editing works with no connection: the change goes into the local lists (and
  // from there into the cache) straight away, and the matching server write is
  // parked in [_queue] until the server can be reached again.

  static const _syncRetryInterval = Duration(seconds: 30);

  final ChickenSyncQueue _queue = ChickenSyncQueue();

  Timer? _syncRetryTimer;
  bool _syncing = false;
  int _discardedChanges = 0;

  /// How many local changes are still waiting to reach the server.
  int get pendingChangeCount => _queue.length;

  /// True while queued changes are being pushed.
  bool get isSyncing => _syncing;

  /// Changes the server refused when they were finally replayed (a record that
  /// no longer exists, a rule that rejects them). They are gone from the queue;
  /// the count is kept so the user can be told rather than left guessing.
  int get discardedChangeCount => _discardedChanges;

  void acknowledgeDiscardedChanges() {
    if (_discardedChanges == 0) return;
    _discardedChanges = 0;
    notifyListenersSafe();
  }

  /// Whether [error] means the write never reached the server, so it is worth
  /// keeping and retrying. Anything the server actually answered — a constraint
  /// violation, an RLS denial, a row that is not there — is a real rejection
  /// and must not be queued, or it would be retried forever.
  static bool isOfflineError(Object error) {
    if (error is AuthRetryableFetchException) return true;
    if (error is PostgrestException || error is AuthException) return false;
    // Bugs (a bad cast, our own "matched no row" StateError) are Errors, never
    // Exceptions. Retrying one forever would wedge the queue, and a wedged
    // queue stops every later change and every refresh.
    if (error is Error) return false;
    // SocketException, http ClientException, TimeoutException, ...
    return true;
  }

  Future<void>? _syncTask;

  /// Pushes queued writes to the server, oldest first. Cheap to call often: it
  /// returns immediately when there is nothing queued.
  ///
  /// A second caller joins the push already in flight instead of walking past
  /// it — the screens load their sections in the same frame, and a caller that
  /// did not wait would find a queue still draining and skip its fetch.
  Future<void> syncPending() {
    if (_queue.isEmpty || !_auth.isSignedIn) return Future.value();
    return _syncTask ??= _runSync();
  }

  Future<void> _runSync() async {
    _syncing = true;
    notifyListenersSafe();
    try {
      final discarded = await _queue.drain(
        _repository.apply,
        isOffline: isOfflineError,
      );
      _discardedChanges += discarded;
      if (discarded > 0) {
        // Those writes are never landing. The guard that hides a just-deleted
        // batch was only meant to cover a delete in flight, so drop it: the
        // next fetch has to be able to bring the record back.
        _pendingDeletedBatchIds.clear();
      }
    } catch (e) {
      logger.e('sync of offline chicken changes failed', error: e);
    } finally {
      _syncTask = null;
      _syncing = false;
      _scheduleSyncRetry();
      notifyListenersSafe();
    }
  }

  /// Keeps retrying on a timer while anything is queued, so a connection that
  /// comes back while the app is open is picked up without the user acting.
  void _scheduleSyncRetry() {
    _syncRetryTimer?.cancel();
    if (_queue.isEmpty) return;
    _syncRetryTimer = Timer(_syncRetryInterval, () async {
      await syncPending();
      // Back online: the loads that were skipped while changes were queued now
      // have to happen, or the screen keeps showing pre-outage data.
      if (_queue.isEmpty && !isDispose) {
        unawaited(loadData(sections: _requestedSections));
      }
    });
  }

  void _queueOps(Iterable<PendingOp> ops) {
    _queue.add(ops, _auth.userId);
    _scheduleSyncRetry();
    notifyListenersSafe();
  }

  /// Every change goes through [notifyListenersSafe], so the cache is written
  /// from there — debounced, because a single action can notify several times.
  @override
  void notifyListenersSafe() {
    super.notifyListenersSafe();
    if (_restoringCache || isDispose) return;
    _cacheSaveTimer?.cancel();
    _cacheSaveTimer = Timer(_cacheSaveDelay, _saveCache);
  }

  void _saveCache() {
    // Nothing worth caching until the first successful fetch: an empty list
    // must never be stored as if it were the user's data.
    if (!_auth.isSignedIn || isReadOnly || _loadedSections.isEmpty) return;
    try {
      // The timestamps are the last successful *fetch* of each section, not
      // the time of this write, so the "data as of …" notice stays truthful
      // even after the user edits records locally. Only sections that really
      // came back from the server are stored: an empty list that just means
      // "never fetched" must not come back looking like the user's data.
      bool has(ChickenSection section) => _loadedSections.contains(section);
      final data = {
        'version': _cacheVersion,
        'userId': _auth.userId,
        'syncedAt': {
          for (final entry in _syncedAt.entries)
            entry.key.name: entry.value.toIso8601String(),
        },
        'years': {
          for (final entry in _serverYears.entries)
            entry.key.name: entry.value.toList(),
        },
        if (has(ChickenSection.batches)) 'batches': _batches,
        if (has(ChickenSection.globalCockSales)) 'cockSales': _globalCockSales,
        if (has(ChickenSection.globalExpenses)) 'expenses': _globalExpenses,
      };
      unawaited(storageService.setChickenCache(jsonEncode(data)));
    } catch (e) {
      logger.e('save chicken cache failed', error: e);
    }
  }

  // Sections are tracked one by one because screens fetch only what they show.
  final Set<ChickenSection> _loadedSections = {};

  /// Sections a screen has asked for at least once, so they are worth
  /// reloading on sign-in and after an offline queue is pushed.
  final Set<ChickenSection> _requestedSections = {};

  /// The year each section was last fetched with; null means "all years".
  final Map<ChickenSection, int?> _loadedYear = {};

  final Map<ChickenSection, DateTime> _syncedAt = {};
  final Set<ChickenSection> _failedSections = {};

  /// Monotonic local-write versions. A server read remembers these before it
  /// starts and may only replace a section if no local change happened while
  /// it was in flight. Without this guard, an empty response captured as a
  /// page opened could arrive after a newly saved sale/expense and hide it
  /// until the page was opened again.
  final Map<ChickenSection, int> _sectionRevision = {};

  void _markSectionChanged(ChickenSection section) {
    _sectionRevision[section] = (_sectionRevision[section] ?? 0) + 1;
  }

  /// Every year the server holds records for, per section. Kept separate from
  /// the loaded data because a year-filtered load only brings back one year and
  /// the year pickers still have to offer the rest.
  final Map<ChickenSection, Set<int>> _serverYears = {};

  /// Years to offer in the year picker of a screen showing [sections]: what the
  /// server holds, plus whatever is in memory (a batch added offline for a new
  /// year has to show up before it is ever fetched back).
  Set<int> yearsFor(Set<ChickenSection> sections) => {
    for (final section in sections) ...?_serverYears[section],
    if (sections.contains(ChickenSection.batches))
      for (final batch in _batches)
        displayYear(batch.actualHatchDate ?? batch.expectedHatchDate),
    if (sections.contains(ChickenSection.globalCockSales))
      for (final sale in _globalCockSales) displayYear(sale.date),
    if (sections.contains(ChickenSection.globalExpenses))
      for (final expense in _globalExpenses) displayYear(expense.date),
  };

  bool _loading = false;

  /// True only while loading something that is not on screen yet — this is what
  /// drives the spinner.
  bool get isLoading => _loading;

  bool _fetching = false;

  /// True while any fetch is in flight, silent refreshes included; drives the
  /// thin progress bar under the app bar.
  bool get isFetching => _fetching;

  /// How fresh [sections] are: when the oldest of them last came back from the
  /// server, and whether the latest attempt for any of them failed. A failed
  /// refresh leaves the cached copy on screen, so the screens say so instead of
  /// passing it off as current.
  ChickenSyncStatus syncStatusFor(Set<ChickenSection> sections) {
    final times = sections.map((s) => _syncedAt[s]).toList();
    return (
      refreshFailed: sections.any(_failedSections.contains),
      syncedAt: times.contains(null)
          ? null
          : times.reduce((oldest, t) => t!.isBefore(oldest!) ? t : oldest),
    );
  }

  @override
  void initState() {
    super.initState();
    _recentChanges.restore();
    _restoreDataSourceSelection();
    _restoreFromCache();
    // This view model lives app-wide and initState runs on every screen mount,
    // so only subscribe once. Data is (re)loaded on sign-in because screens may
    // already be built (empty) while the login screen is shown.
    _authSub ??= _auth.changes.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.initialSession:
          // The persisted session is restored asynchronously, so this is often
          // the first moment the cache can be matched against a user.
          _restoreDataSourceSelection();
          _restoreFromCache();
          unawaited(loadSharing());
        case AuthChangeEvent.signedIn:
          _selectionRestoredForUserId = null;
          _restoreDataSourceSelection();
          _restoreFromCache();
          unawaited(loadSharing());
          // Cached data is already on screen: refresh it silently.
          unawaited(loadData(sections: _requestedSections));
        case AuthChangeEvent.signedOut:
          _batches = [];
          _globalCockSales = [];
          _globalExpenses = [];
          _loadedSections.clear();
          _loadedYear.clear();
          _syncedAt.clear();
          _failedSections.clear();
          _serverYears.clear();
          _dataSources = [];
          _shareViewers = [];
          _activeOwnerId = null;
          _activeOwnerEmail = null;
          _selectionRestoredForUserId = null;
          _cacheSaveTimer?.cancel();
          _syncRetryTimer?.cancel();
          // The cache goes, the queue stays: it holds work the user believes is
          // saved, and it is replayed when the same account signs back in.
          unawaited(storageService.clearChickenCache());
          // The badges describe this account's records, so they go with them.
          _recentChanges.clear();
          _cacheRestored = false;
          notifyListenersSafe();
          unawaited(_syncVaccinationNotifications());
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _syncRetryTimer?.cancel();
    // Flush a pending write so the last change still makes it to the cache.
    if (_cacheSaveTimer?.isActive ?? false) {
      _cacheSaveTimer!.cancel();
      _saveCache();
    }
    super.dispose();
  }

  @override
  void initData() {
    super.initData();
    _restoreDataSourceSelection();
    _activeOwnerId ??= _auth.userId;
    if (_auth.isSignedIn) unawaited(loadSharing());
    if (!_auth.isSignedIn && vaccinationNotificationsEnabled) {
      unawaited(notificationService.cancelVaccinationNotifications());
    }
  }

  /// Called when a chicken screen opens, with the sections that screen shows
  /// and the year it is filtered to (null for all years). Always re-fetches,
  /// but shows the spinner only when the data is not on screen yet — later
  /// entries refresh behind what is already there.
  Future<void> ensureLoaded(Set<ChickenSection> sections, {int? year}) async {
    _requestedSections.addAll(sections);
    final missing = sections.where(
      (s) => !_loadedSections.contains(s) || _loadedYear[s] != year,
    );
    await loadData(
      sections: sections,
      year: year,
      showLoading: missing.isNotEmpty && !_loadedSections.containsAll(sections),
    );
  }

  Future<void>? _loadTask;
  Set<ChickenSection> _loadTaskSections = const {};
  int? _loadTaskYear;

  /// Fetches [sections] (all of them when not given), narrowed to [year].
  ///
  /// Concurrent callers share one fetch when the one already running covers
  /// what they need: the screens mount together often enough (a detail screen
  /// over its list, a resume landing on a tab switch) that fetching the same
  /// payload twice would be the normal case rather than the exception.
  Future<void> loadData({
    Set<ChickenSection>? sections,
    int? year,
    bool showLoading = false,
  }) {
    if (!_auth.isSignedIn) return Future.value();
    final wanted = sections ?? ChickenSection.values.toSet();
    if (wanted.isEmpty) return Future.value();

    final inFlight = _loadTask;
    // An unfiltered read covers every year, so it also answers a narrower one.
    final coversYear = _loadTaskYear == null || _loadTaskYear == year;
    if (inFlight != null &&
        coversYear &&
        _loadTaskSections.containsAll(wanted)) {
      return inFlight;
    }

    late final Future<void> task;
    task = _load(wanted, year: year, showLoading: showLoading).whenComplete(() {
      if (identical(_loadTask, task)) {
        _loadTask = null;
        _loadTaskSections = const {};
        _loadTaskYear = null;
      }
    });
    _loadTask = task;
    _loadTaskSections = wanted;
    _loadTaskYear = year;
    return task;
  }

  /// The year to ask the server for when the screens are filtering on [year] of
  /// the displayed calendar.
  ///
  /// Stored dates are solar and the server answers for stored years
  /// `[year - 1, year]`. A lunar year runs from late January of the same solar
  /// year into January of the next one, so showing lunar year Y needs solar
  /// years `[Y, Y + 1]` — which is exactly the window the server gives for
  /// `Y + 1`.
  int? _serverYearFor(int? year) =>
      year == null ? null : (_useLunarCalendar ? year + 1 : year);

  /// Merges a year-filtered read into what is already in memory.
  ///
  /// The server answers for stored years `[year - 1, year]`, so records outside
  /// that window were never part of the answer and have to survive — otherwise
  /// switching the year filter would throw away every other year. Within the
  /// window the server is the authority. [year] here is the *server* year, the
  /// one [_serverYearFor] produced.
  List<T> _mergeYearWindow<T>(
    List<T> fetched,
    List<T> existing,
    int? year,
    int Function(T) storedYear,
    String Function(T) idOf,
  ) {
    if (year == null) return fetched;
    final fetchedIds = fetched.map(idOf).toSet();
    return [
      ...existing.where(
        (item) =>
            !fetchedIds.contains(idOf(item)) &&
            (storedYear(item) < year - 1 || storedYear(item) > year),
      ),
      ...fetched,
    ];
  }

  Future<void> _load(
    Set<ChickenSection> sections, {
    required int? year,
    required bool showLoading,
  }) async {
    await syncPending();
    // Changes that have not reached the server yet are the newer truth: a fetch
    // now would overwrite them with a snapshot that predates them.
    if (_queue.isNotEmpty) return;

    _fetching = true;
    if (showLoading) _loading = true;
    notifyListenersSafe();
    // The screens filter on the displayed calendar; the server stores solar
    // dates and knows nothing about the setting.
    final serverYear = _serverYearFor(year);
    final revisionAtRequest = {
      for (final section in ChickenSection.values)
        section: _sectionRevision[section] ?? 0,
    };
    bool isCurrent(ChickenSection section) =>
        (_sectionRevision[section] ?? 0) == revisionAtRequest[section];
    try {
      final data = await _repository.getChickenData(
        sections: sections,
        year: serverYear,
        ownerId: activeOwnerId,
      );
      final batches = data.batches;
      if (batches != null && isCurrent(ChickenSection.batches)) {
        if (_pendingDeletedBatchIds.isNotEmpty) {
          // Once the server no longer returns a deleted batch, stop guarding it.
          final fetchedIds = batches.map((b) => b.id).toSet();
          _pendingDeletedBatchIds.removeWhere((id) => !fetchedIds.contains(id));
        }
        _batches = _mergeYearWindow(
          batches
              .where((b) => !_pendingDeletedBatchIds.contains(b.id))
              .toList(),
          _batches,
          serverYear,
          (b) => b.incubationDate.year,
          (b) => b.id,
        );
        mergeSort(
          _batches,
          compare: (a, b) => b.incubationDate.compareTo(a.incubationDate),
        );
      }
      if (data.globalCockSales != null &&
          isCurrent(ChickenSection.globalCockSales)) {
        _globalCockSales = _mergeYearWindow(
          data.globalCockSales!,
          _globalCockSales,
          serverYear,
          (s) => s.date.year,
          (s) => s.id,
        );
        mergeSort(
          _globalCockSales,
          compare: (a, b) => b.date.compareTo(a.date),
        );
      }
      if (data.globalExpenses != null &&
          isCurrent(ChickenSection.globalExpenses)) {
        _globalExpenses = _mergeYearWindow(
          data.globalExpenses!,
          _globalExpenses,
          serverYear,
          (e) => e.date.year,
          (e) => e.id,
        );
        mergeSort(_globalExpenses, compare: (a, b) => b.date.compareTo(a.date));
      }
      for (final entry in data.years.entries) {
        if (isCurrent(entry.key)) _serverYears[entry.key] = entry.value;
      }

      final now = DateTime.now();
      for (final section in sections) {
        if (!isCurrent(section)) continue;
        _loadedSections.add(section);
        _loadedYear[section] = year;
        _syncedAt[section] = now;
        _failedSections.remove(section);
      }
    } catch (e) {
      logger.e("load chicken data failed", error: e);
      _failedSections.addAll(sections);
    } finally {
      _loading = false;
      _fetching = false;
      notifyListenersSafe();
    }
    // Scheduling local notifications can be slow; keep it off the UI path.
    if (sections.contains(ChickenSection.batches) && !isReadOnly) {
      unawaited(_syncVaccinationNotifications());
    }
  }

  Future<void> loadSharing() async {
    if (!_auth.isSignedIn) return;
    try {
      _restoreDataSourceSelection();
      final results = await Future.wait([
        _repository.getDataSources(),
        _repository.getShareViewers(),
      ]);
      _dataSources = results[0] as List<ChickenDataSource>;
      _shareViewers = results[1] as List<ChickenShareViewer>;
      final activeId = activeOwnerId;
      final activeSource = _dataSources.firstWhereOrNull(
        (source) => source.ownerId == activeId,
      );
      if (activeId != null && activeSource == null) {
        await _loadTask;
        _activeOwnerId = _auth.userId;
        _activeOwnerEmail = null;
        _clearLoadedData();
        await storageService.clearChickenDataSourceSelection();
        await loadData(sections: _requestedSections);
      } else if (activeSource != null) {
        _activeOwnerEmail = activeSource.email;
      }
      notifyListenersSafe();
    } catch (e) {
      logger.e('load chicken sharing failed', error: e);
    }
  }

  Future<void> selectDataSource(ChickenDataSource source) async {
    if (source.ownerId == activeOwnerId) return;
    await _loadTask;
    if (_queue.isNotEmpty) {
      await syncPending();
      if (_queue.isNotEmpty) {
        throw StateError('Please wait for pending changes to sync first.');
      }
    }
    _activeOwnerId = source.ownerId;
    _activeOwnerEmail = source.email;
    await _saveDataSourceSelection(source);
    _clearLoadedData();
    notifyListenersSafe();
    await loadData(sections: _requestedSections);
  }

  Future<bool> shareWith(String email) async {
    final emailSent = await _repository.shareWith(email);
    await loadSharing();
    return emailSent;
  }

  Future<void> revokeShare(String viewerId) async {
    await _repository.revokeShare(viewerId);
    await loadSharing();
  }

  void _clearLoadedData() {
    _batches = [];
    _globalCockSales = [];
    _globalExpenses = [];
    _loadedSections.clear();
    _loadedYear.clear();
    _syncedAt.clear();
    _failedSections.clear();
    _serverYears.clear();
    _pendingDeletedBatchIds.clear();
  }

  /// Sends a change that was already applied to the local lists to the server.
  ///
  /// Three outcomes: it lands; the server cannot be reached, in which case the
  /// write is queued and the local change stands (this is what makes offline
  /// editing work); or the server rejects it, in which case [rollback] undoes
  /// the local change — memory, and the cache written from it, must never keep
  /// a record the server refused — and the error is rethrown for the caller to
  /// surface.
  Future<void> _commit(
    String action,
    List<PendingOp> ops, {
    required VoidCallback rollback,
  }) async {
    if (isReadOnly) {
      rollback();
      notifyListenersSafe();
      throw StateError('Shared chicken data is read-only.');
    }
    // Anything already queued has to land first, or this write could reach the
    // server ahead of the change it builds on.
    if (_queue.isNotEmpty) {
      _queueOps(ops);
      return;
    }
    for (var i = 0; i < ops.length; i++) {
      try {
        await _repository.apply(ops[i]);
      } catch (e) {
        if (isOfflineError(e)) {
          // Queue what is left. Anything already sent was an update, which is
          // harmless to repeat, so the remainder is enough.
          _queueOps(ops.skip(i));
          return;
        }
        logger.e("$action failed", error: e);
        rollback();
        notifyListenersSafe();
        rethrow;
      }
    }
  }

  /// Rollback that puts [previous] back in place of the edited batch.
  VoidCallback _restoreBatch(ChickenBatch previous) => () {
    final index = _batches.indexWhere((b) => b.id == previous.id);
    if (index != -1) _batches[index] = previous;
  };

  /// Applies [edit] to the batch with [batchId] and pushes the change to the
  /// server, restoring the previous batch if the write is rejected.
  Future<void> _editBatch(
    String batchId,
    String action,
    ChickenBatch Function(ChickenBatch batch) edit,
    List<PendingOp> ops,
  ) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index == -1) return;
    final previous = _batches[index];
    _batches[index] = edit(previous);
    _markSectionChanged(ChickenSection.batches);
    notifyListenersSafe();
    await _commit(action, ops, rollback: _restoreBatch(previous));
  }

  Future<ChickenBatch> addBatch({
    required String name,
    required DateTime incubationDate,
    required int quantity,
  }) async {
    final newBatch = ChickenBatch(
      id: _uuid.v4(),
      name: name,
      incubationDate: incubationDate,
      quantity: quantity,
      vaccinations: _getDefaultVaccinationSchedule(incubationDate),
    );
    _batches.insert(0, newBatch);
    _markSectionChanged(ChickenSection.batches);
    _recentChanges.markAdded(newBatch.id);
    // Stable sort so a batch added with the same incubation date as an existing
    // one stays on top (it was just inserted at the front).
    mergeSort(
      _batches,
      compare: (a, b) => b.incubationDate.compareTo(a.incubationDate),
    );
    notifyListenersSafe();
    await _commit(
      "insert chicken batch",
      [_repository.insertBatchOp(newBatch)],
      rollback: () => _batches.removeWhere((b) => b.id == newBatch.id),
    );
    await _syncVaccinationNotifications();
    return newBatch;
  }

  Future<void> updateBatch(ChickenBatch batch) async {
    final index = _batches.indexWhere((e) => e.id == batch.id);
    if (index == -1) return;
    final previousBatch = _batches[index];
    final incubationDateDelta = batch.incubationDate.difference(
      previousBatch.incubationDate,
    );
    final updatedBatch = incubationDateDelta == Duration.zero
        ? batch
        : batch.shiftVaccinationSchedule(incubationDateDelta);

    _batches[index] = updatedBatch;
    _markSectionChanged(ChickenSection.batches);
    _recentChanges.markUpdated(updatedBatch.id);
    notifyListenersSafe();
    await _commit("update chicken batch", [
      _repository.updateBatchOp(updatedBatch),
      if (incubationDateDelta != Duration.zero)
        ..._repository.updateVaccinationDateOps(updatedBatch.vaccinations),
    ], rollback: _restoreBatch(previousBatch));
    await _syncVaccinationNotifications();
  }

  Future<void> deleteBatch(String id) async {
    final batch = _batches.firstWhereOrNull((e) => e.id == id);
    if (batch == null) return;
    _batches.removeWhere((e) => e.id == id);
    _markSectionChanged(ChickenSection.batches);
    _recentChanges.forget(id);
    // Guard against an in-flight load re-adding this batch before the server
    // delete has settled. The guard is cleared by a later load once the
    // server confirms the batch is gone.
    _pendingDeletedBatchIds.add(id);
    notifyListenersSafe();
    await _commit(
      "delete chicken batch",
      [_repository.deleteBatchOp(id)],
      rollback: () {
        // Rejected: stop guarding and restore the batch locally.
        _pendingDeletedBatchIds.remove(id);
        _batches.add(batch);
        mergeSort(
          _batches,
          compare: (a, b) => b.incubationDate.compareTo(a.incubationDate),
        );
      },
    );
    await _syncVaccinationNotifications();
  }

  Future<void> addExpense(String batchId, Expense expense) {
    _recentChanges.markAdded(expense.id);
    return _editBatch(
      batchId,
      "insert expense",
      (batch) => batch.copyWith(expenses: [...batch.expenses, expense]),
      [_repository.insertExpenseOp(batchId, expense)],
    );
  }

  Future<void> updateExpense(String batchId, Expense expense) {
    _recentChanges.markUpdated(expense.id);
    return _editBatch(
      batchId,
      "update expense",
      (batch) => batch.copyWith(
        expenses: batch.expenses
            .map((e) => e.id == expense.id ? expense : e)
            .toList(),
      ),
      [_repository.updateExpenseOp(expense)],
    );
  }

  Future<void> deleteExpense(String batchId, String expenseId) {
    _recentChanges.forget(expenseId);
    return _editBatch(
      batchId,
      "delete expense",
      (batch) => batch.copyWith(
        expenses: batch.expenses.where((e) => e.id != expenseId).toList(),
      ),
      [_repository.deleteExpenseOp(expenseId)],
    );
  }

  Future<void> addBatchSale(String batchId, BatchSale sale) {
    _recentChanges.markAdded(sale.id);
    return _editBatch(
      batchId,
      "insert batch sale",
      (batch) => batch.copyWith(
        sales: [...batch.sales, sale]..sort((a, b) => a.date.compareTo(b.date)),
      ),
      [_repository.insertBatchSaleOp(batchId, sale)],
    );
  }

  Future<void> updateBatchSale(String batchId, BatchSale sale) {
    _recentChanges.markUpdated(sale.id);
    return _editBatch(
      batchId,
      "update batch sale",
      (batch) => batch.copyWith(
        sales: batch.sales.map((s) => s.id == sale.id ? sale : s).toList()
          ..sort((a, b) => a.date.compareTo(b.date)),
      ),
      [_repository.updateBatchSaleOp(sale)],
    );
  }

  Future<void> deleteBatchSale(String batchId, String saleId) {
    _recentChanges.forget(saleId);
    return _editBatch(
      batchId,
      "delete batch sale",
      (batch) => batch.copyWith(
        sales: batch.sales.where((s) => s.id != saleId).toList(),
      ),
      [_repository.deleteBatchSaleOp(saleId)],
    );
  }

  Future<void> addCockSale(String batchId, CockSale sale) {
    _recentChanges.markAdded(sale.id);
    return _editBatch(
      batchId,
      "insert cock sale",
      (batch) => batch.copyWith(cockSales: [...batch.cockSales, sale]),
      [_repository.insertCockSaleOp(batchId, sale)],
    );
  }

  Future<void> addGlobalCockSale(CockSale sale) async {
    // Front of the list so a same-date sale shows on top (stable sort keeps it).
    _globalCockSales.insert(0, sale);
    _markSectionChanged(ChickenSection.globalCockSales);
    _recentChanges.markAdded(sale.id);
    notifyListenersSafe();
    await _commit(
      "insert global cock sale",
      [_repository.insertCockSaleOp(null, sale)],
      rollback: () => _globalCockSales.removeWhere((s) => s.id == sale.id),
    );
  }

  Future<void> updateGlobalCockSale(CockSale sale) async {
    final index = _globalCockSales.indexWhere((item) => item.id == sale.id);
    if (index == -1) return;
    final previous = _globalCockSales[index];
    _globalCockSales[index] = sale;
    _markSectionChanged(ChickenSection.globalCockSales);
    _recentChanges.markUpdated(sale.id);
    notifyListenersSafe();
    await _commit(
      "update global cock sale",
      [_repository.updateCockSaleOp(sale, globalRecord: true)],
      rollback: () {
        final at = _globalCockSales.indexWhere((item) => item.id == sale.id);
        if (at != -1) _globalCockSales[at] = previous;
      },
    );
  }

  Future<void> deleteGlobalCockSale(String id) async {
    final index = _globalCockSales.indexWhere((sale) => sale.id == id);
    if (index == -1) return;
    final removed = _globalCockSales.removeAt(index);
    _markSectionChanged(ChickenSection.globalCockSales);
    _recentChanges.forget(id);
    notifyListenersSafe();
    await _commit(
      "delete global cock sale",
      [_repository.deleteCockSaleOp(id, globalRecord: true)],
      rollback: () => _globalCockSales.insert(
        index.clamp(0, _globalCockSales.length),
        removed,
      ),
    );
  }

  Future<void> addGlobalExpense(Expense expense) async {
    _globalExpenses.insert(0, expense);
    _markSectionChanged(ChickenSection.globalExpenses);
    _recentChanges.markAdded(expense.id);
    notifyListenersSafe();
    await _commit(
      "insert global expense",
      [_repository.insertExpenseOp(null, expense)],
      rollback: () => _globalExpenses.removeWhere((e) => e.id == expense.id),
    );
  }

  Future<void> updateGlobalExpense(Expense expense) async {
    final index = _globalExpenses.indexWhere((item) => item.id == expense.id);
    if (index == -1) return;
    final previous = _globalExpenses[index];
    _globalExpenses[index] = expense;
    _markSectionChanged(ChickenSection.globalExpenses);
    _recentChanges.markUpdated(expense.id);
    notifyListenersSafe();
    await _commit(
      "update global expense",
      [_repository.updateExpenseOp(expense, globalRecord: true)],
      rollback: () {
        final at = _globalExpenses.indexWhere((item) => item.id == expense.id);
        if (at != -1) _globalExpenses[at] = previous;
      },
    );
  }

  Future<void> deleteGlobalExpense(String id) async {
    final index = _globalExpenses.indexWhere((expense) => expense.id == id);
    if (index == -1) return;
    final removed = _globalExpenses.removeAt(index);
    _markSectionChanged(ChickenSection.globalExpenses);
    _recentChanges.forget(id);
    notifyListenersSafe();
    await _commit(
      "delete global expense",
      [_repository.deleteExpenseOp(id, globalRecord: true)],
      rollback: () => _globalExpenses.insert(
        index.clamp(0, _globalExpenses.length),
        removed,
      ),
    );
  }

  /// Bulk actions cannot run while local changes are still queued: they rewrite
  /// data the queued writes refer to.
  void _requireEverythingSynced(String action) {
    if (_queue.isEmpty) return;
    throw StateError(
      'Còn ${_queue.length} thay đổi chưa đồng bộ. '
      'Hãy kết nối mạng và đợi đồng bộ xong trước khi $action.',
    );
  }

  /// Imports data from the JSON format described in [ChickenImportService].
  /// Returns the number of imported records, or throws on invalid input.
  Future<int> importFromJson(String jsonString) async {
    if (isReadOnly) throw StateError('Shared chicken data is read-only.');
    final data = ChickenImportService.parse(jsonString);
    final userId = _auth.userId;
    if (userId == null) throw StateError('Bạn cần đăng nhập trước khi import.');
    // A bulk write on top of unsynced local changes would be impossible to
    // reconcile afterwards, so the queue has to be empty first.
    _requireEverythingSynced('import');

    _isImporting = true;
    _importProgress = 0;
    notifyListenersSafe();

    try {
      await _repository.importData(
        batches: data.batches,
        globalSales: data.globalSales,
        globalExpenses: data.globalExpenses,
        onProgress: (completed, total) {
          _importProgress = total == 0 ? 1 : completed / total;
          notifyListenersSafe();
        },
      );
      await loadData();
      return data.totalRecords;
    } finally {
      _isImporting = false;
      notifyListenersSafe();
    }
  }

  Future<int> deleteAllData() async {
    if (isReadOnly) throw StateError('Shared chicken data is read-only.');
    if (_auth.userId == null) {
      throw StateError('Bạn cần đăng nhập trước khi xóa dữ liệu.');
    }
    _requireEverythingSynced('xóa dữ liệu');

    // Do not let a response captured before the delete land afterwards and
    // repopulate memory/cache with the rows that have just been removed.
    await _loadTask;

    final deletedCount = await _repository.deleteAllData();
    // Nothing is left to badge.
    _recentChanges.clear();
    _clearLoadedData();
    await storageService.clearChickenCache();
    notifyListenersSafe();
    await loadData();
    return deletedCount;
  }

  Future<void> toggleVaccination(String batchId, String vaccinationId) async {
    final batch = _batches.firstWhereOrNull((e) => e.id == batchId);
    final current = batch?.vaccinations.firstWhereOrNull(
      (v) => v.id == vaccinationId,
    );
    if (current == null) return;
    final isCompleted = !current.isCompleted;
    await _editBatch(
      batchId,
      "toggle vaccination",
      (batch) => batch.copyWith(
        vaccinations: batch.vaccinations
            .map(
              (v) => v.id == vaccinationId
                  ? v.copyWith(isCompleted: isCompleted)
                  : v,
            )
            .toList(),
      ),
      [_repository.setVaccinationCompletedOp(vaccinationId, isCompleted)],
    );
    await _syncVaccinationNotifications();
  }

  List<Vaccination> _getDefaultVaccinationSchedule(DateTime incubationDate) {
    final hatchDate = incubationDate.add(const Duration(days: 21));

    Vaccination vaccination(String title, int daysAfterHatch) => Vaccination(
      id: _uuid.v4(),
      title: title,
      scheduledDate: hatchDate.add(Duration(days: daysAfterHatch)),
    );

    return [
      vaccination('Gumboro (Lần 1)', 7),
      vaccination('Newcastle (Lần 1)', 10),
      vaccination('Gumboro (Lần 2)', 14),
      vaccination('Newcastle (Lần 2)', 21),
      vaccination('Tụ huyết trùng', 45),
    ];
  }

  bool get vaccinationNotificationsEnabled =>
      storageService.getChickenNotificationsEnabled();

  Future<bool> setVaccinationNotificationsEnabled(bool enabled) async {
    if (enabled && !await notificationService.requestPermission()) return false;
    try {
      if (enabled) {
        await notificationService.scheduleVaccinations(_batches);
      } else {
        await notificationService.cancelVaccinationNotifications();
      }
      await storageService.setChickenNotificationsEnabled(enabled);
      notifyListenersSafe();
      return true;
    } catch (e) {
      logger.e('update vaccination notification setting failed', error: e);
      notifyListenersSafe();
      return false;
    }
  }

  Future<void> _syncVaccinationNotifications() async {
    if (isReadOnly || !vaccinationNotificationsEnabled) return;
    try {
      await notificationService.scheduleVaccinations(_batches);
    } catch (e) {
      logger.e('schedule vaccination notifications failed', error: e);
    }
  }

  Map<ChickenMonth, ChickenStats> getMonthlyStats(int year) {
    final leapMonth = _useLunarCalendar
        ? LunarCalendar.leapMonthOfYear(year)
        : null;
    final stats = <ChickenMonth, _MutableStats>{
      for (int month = 1; month <= 12; month++) ...{
        (month: month, isLeap: false): _MutableStats(),
        if (month == leapMonth) (month: month, isLeap: true): _MutableStats(),
      },
    };
    _accumulateStats(
      (date) => date.year == year
          ? stats[(month: date.month, isLeap: date.isLeap)]!
          : null,
    );
    return stats.map((month, val) => MapEntry(month, val.toRecord()));
  }

  Map<int, ChickenStats> getYearlyStats() {
    final stats = <int, _MutableStats>{};
    _accumulateStats(
      (date) => stats.putIfAbsent(date.year, () => _MutableStats()),
    );
    return stats.map((y, val) => MapEntry(y, val.toRecord()));
  }

  void _accumulateStats(
    _MutableStats? Function(_ChickenStatsDate date) bucketOf,
  ) {
    // Keep the leap flag in the bucket. Converting through a DateTime would
    // collapse the regular and leap occurrences of the same lunar month.
    _ChickenStatsDate bucketDate(DateTime date) {
      if (!_useLunarCalendar) {
        return (year: date.year, month: date.month, isLeap: false);
      }
      final lunar = LunarCalendar.solarToLunar(date.day, date.month, date.year);
      return (year: lunar.year, month: lunar.month, isLeap: lunar.isLeap);
    }

    void addSale(CockSale sale) {
      final bucket = bucketOf(bucketDate(sale.date));
      if (bucket == null) return;
      if (sale.category == SaleCategory.meat) {
        bucket.meatRevenue += sale.amount;
      } else {
        bucket.cockRevenue += sale.amount;
      }
    }

    void addExpense(Expense exp) =>
        bucketOf(bucketDate(exp.date))?.expense += exp.amount;

    for (var batch in _batches) {
      for (var sale in batch.sales) {
        bucketOf(bucketDate(sale.date))?.batchRevenue += sale.amount;
      }
      batch.cockSales.forEach(addSale);
      batch.expenses.forEach(addExpense);
    }
    _globalCockSales.forEach(addSale);
    _globalExpenses.forEach(addExpense);
  }
}

/// How fresh a section's data is: when it last came back from the API (null if
/// it never did) and whether the latest refresh attempt failed.
typedef ChickenSyncStatus = ({bool refreshFailed, DateTime? syncedAt});

typedef ChickenStats = ({
  double batchRevenue,
  double cockRevenue,
  double meatRevenue,
  double expense,
  double profit,
});

/// A month in the currently displayed calendar. Solar months never use
/// [isLeap]; a lunar leap year contains both `(month: 6, isLeap: false)` and
/// `(month: 6, isLeap: true)`, for example.
typedef ChickenMonth = ({int month, bool isLeap});

typedef _ChickenStatsDate = ({int year, int month, bool isLeap});

class _MutableStats {
  double batchRevenue = 0;
  double cockRevenue = 0;
  double meatRevenue = 0;
  double expense = 0;

  ChickenStats toRecord() => (
    batchRevenue: batchRevenue,
    cockRevenue: cockRevenue,
    meatRevenue: meatRevenue,
    expense: expense,
    profit: (batchRevenue + cockRevenue + meatRevenue) - expense,
  );
}
