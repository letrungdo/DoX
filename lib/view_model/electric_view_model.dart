import 'package:do_x/model/electric/electric_account.dart';
import 'package:do_x/model/electric/electric_models.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/electric_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

enum ElectricStatus {
  loading, //
  loggedOut,
  loggedIn,
}

class ElectricViewModel extends CoreViewModel {
  final _service = ElectricService();

  ElectricStatus _status = ElectricStatus.loading;
  ElectricStatus get status => _status;

  List<ElectricAccount> _accounts = [];
  List<ElectricAccount> get accounts => _accounts;

  int _activeIndex = 0;
  int get activeIndex => _activeIndex;

  ElectricAccount? get activeAccount => _accounts.isEmpty ? null : _accounts[_activeIndex];

  final _fetchingUsernames = <String>{};

  /// True while data for the active account is being (re)loaded (any trigger,
  /// including background refreshes on tab switch / resume).
  bool get isFetching {
    final account = activeAccount;
    return account != null && _fetchingUsernames.contains(account.username);
  }

  final _loadingUsernames = <String>{};

  /// True only while an explicitly-requested load is running — first load or a
  /// manual reload (refresh button / pull-to-refresh). Background refreshes on
  /// tab switch / resume don't set this, so the top progress bar stays hidden.
  bool get isLoading {
    final account = activeAccount;
    return account != null && _loadingUsernames.contains(account.username);
  }

  ElectricCustomer? get customer => activeAccount?.customer;
  ElectricUsageSnapshot? get usage => activeAccount?.usage;

  /// Usage tiles with fallbacks when the alerts API has no data:
  /// today/yesterday from the RF-SPIDER daily deltas, this month from the
  /// latest reading's since-billing counter, last month from billing history.
  num? get usageToday => usage?.today ?? _dailyKwhOn(DateTime.now());

  num? get usageYesterday => usage?.yesterday ?? _dailyKwhOn(DateTime.now().subtract(const Duration(days: 1)));

  num? get usageThisMonth => usage?.thisMonth ?? latestReading?.usageSinceBilling;

  num? get usageLastMonth => usage?.lastMonth ?? monthlyUsages.firstOrNull?.usageKwh;

  num? _dailyKwhOn(DateTime date) {
    for (final entry in dailyUsages) {
      if (entry.day.year == date.year && entry.day.month == date.month && entry.day.day == date.day) {
        return entry.kwh;
      }
    }
    return null;
  }
  List<ElectricMonthlyUsage> get monthlyUsages => activeAccount?.monthlyUsages ?? [];

  /// RF-SPIDER readings, newest first.
  List<ElectricMeterReading> get spiderReadings => activeAccount?.spiderReadings ?? [];

  ElectricMeterReading? get latestReading => spiderReadings.firstOrNull;

  /// kWh per day derived from RF-SPIDER meter indexes (last reading of each
  /// day minus the previous day's), oldest first.
  List<({DateTime day, double kwh})> get dailyUsages {
    final readings = spiderReadings;
    if (readings.isEmpty) return [];

    // Last (highest) meter index of each day.
    final lastIndexOfDay = <DateTime, double>{};
    for (final reading in readings) {
      final readAt = reading.readAt;
      final index = reading.meterIndex?.toDouble();
      if (readAt == null || index == null) continue;
      final day = DateTime(readAt.year, readAt.month, readAt.day);
      final current = lastIndexOfDay[day];
      if (current == null || index > current) lastIndexOfDay[day] = index;
    }

    final days = lastIndexOfDay.keys.toList()..sort();
    final result = <({DateTime day, double kwh})>[];
    for (var i = 1; i < days.length; i++) {
      final kwh = lastIndexOfDay[days[i]]! - lastIndexOfDay[days[i - 1]]!;
      result.add((day: days[i], kwh: kwh < 0 ? 0 : kwh));
    }
    return result;
  }

  @override
  void initData() {
    super.initData();
    _init();
  }

  Future<void> _init() async {
    _accounts = await secureStorage.getCpcAccounts();
    if (_accounts.isEmpty) {
      _setStatus(ElectricStatus.loggedOut);
      return;
    }
    _activeIndex = 0;
    _setStatus(ElectricStatus.loggedIn);
    await _fetchAccount(_accounts[_activeIndex], showLoading: true);
  }

  /// Logs in and adds a new account tab, then makes it active.
  Future<void> addAccount({required String username, required String password}) async {
    if (_accounts.any((a) => a.username == username)) {
      switchAccount(_accounts.indexWhere((a) => a.username == username));
      return;
    }
    showLoading();
    final res = await _service.login(username: username, password: password, cancelToken: cancelToken);
    hideLoading();
    if (res.isError || res.data?.accessToken == null) {
      // ignore: use_build_context_synchronously
      showAppError(context, res.error ?? ConnectionError(type: ApiErrorType.unauthorized));
      return;
    }
    final account = ElectricAccount(username: username, password: password, accessToken: res.data?.accessToken);
    _accounts = [..._accounts, account];
    _activeIndex = _accounts.length - 1;
    await secureStorage.saveCpcAccounts(_accounts);
    _setStatus(ElectricStatus.loggedIn);
    await _fetchAccount(account, showLoading: true);
  }

  Future<void> removeActiveAccount() async {
    final account = activeAccount;
    if (account == null) return;
    _accounts = [..._accounts]..removeAt(_activeIndex);
    if (_activeIndex >= _accounts.length) _activeIndex = _accounts.isEmpty ? 0 : _accounts.length - 1;
    await secureStorage.saveCpcAccounts(_accounts);
    if (_accounts.isEmpty) {
      _setStatus(ElectricStatus.loggedOut);
      return;
    }
    notifyListenersSafe();
    final active = activeAccount;
    if (active != null && !active.loaded) {
      await _fetchAccount(active, showLoading: true);
    }
  }

  void switchAccount(int index) {
    if (index < 0 || index >= _accounts.length || index == _activeIndex) return;
    _activeIndex = index;
    notifyListenersSafe();
    final account = _accounts[index];
    if (!account.loaded) _fetchAccount(account, showLoading: true);
  }

  Future<void> onRefresh({bool showLoading = false}) async {
    renewCancelToken("onRefresh");
    final account = activeAccount;
    if (account != null) {
      await _fetchAccount(account, showLoading: showLoading);
    }
  }

  Future<void> _fetchAccount(ElectricAccount account, {bool showLoading = false}) async {
    _fetchingUsernames.add(account.username);
    if (showLoading) _loadingUsernames.add(account.username);
    notifyListenersSafe();
    try {
      await _doFetchAccount(account);
    } finally {
      _fetchingUsernames.remove(account.username);
      _loadingUsernames.remove(account.username);
      notifyListenersSafe();
    }
  }

  Future<void> _doFetchAccount(ElectricAccount account) async {
    var res = await _service.getCustomerInfos(accessToken: account.accessToken, cancelToken: cancelToken);

    // The stored token may have been revoked — try once to log in again
    // with the saved credentials before giving up.
    if (res.error?.type == ApiErrorType.unauthorized) {
      final auth = await _service.login(
        username: account.username,
        password: account.password,
        cancelToken: cancelToken,
      );
      if (auth.isError || auth.data?.accessToken == null) {
        if (identical(account, activeAccount)) await removeActiveAccount();
        return;
      }
      account.accessToken = auth.data?.accessToken;
      await secureStorage.saveCpcAccounts(_accounts);
      res = await _service.getCustomerInfos(accessToken: account.accessToken, cancelToken: cancelToken);
    }

    if (res.isError) {
      if (res.isCancelByUser) return;
      // ignore: use_build_context_synchronously
      showAppError(context, res.error, onRetry: () => _fetchAccount(account));
      return;
    }

    final customer = res.data?.customerCodes.firstOrNull;
    account.customer = customer;
    notifyListenersSafe();
    if (customer?.customerCode == null) return;

    await Future.wait([
      _getUsageAlert(account, customer!.customerCode!), //
      _getCustomerDetail(account, customer.customerCode!),
      _getSpiderReadings(account, customer.customerCode!, customer.orgCode),
      _getMonthlyUsages(account, customer.customerCode!),
    ]);
    account.loaded = true;
    notifyListenersSafe();

    // Cache the chip info so the next app start shows real names right away.
    account.customerName = customer.customerName ?? account.customerName;
    account.contractType = account.detail?.contractType ?? account.contractType;
    await secureStorage.saveCpcAccounts(_accounts);
  }

  Future<void> _getCustomerDetail(ElectricAccount account, String customerCode) async {
    final res = await _service.getCustomerDetail(customerCode, accessToken: account.accessToken, cancelToken: cancelToken);
    if (res.isError) return;
    account.detail = res.data;
    notifyListenersSafe();
  }

  Future<void> _getUsageAlert(ElectricAccount account, String customerCode) async {
    final res = await _service.getUsageAlert(customerCode, accessToken: account.accessToken, cancelToken: cancelToken);
    if (res.isError) return;
    account.usage = res.data?.electricConsumption;
    notifyListenersSafe();
  }

  Future<void> _getSpiderReadings(ElectricAccount account, String customerCode, String? orgCode) async {
    if (orgCode == null) return;
    final res = await _service.getSpiderReadings(
      customerCode: customerCode,
      orgCode: orgCode,
      accessToken: account.accessToken,
      cancelToken: cancelToken,
    );
    if (res.isError) return;
    final readings = res.data ?? [];
    readings.sort((a, b) => (b.readAt ?? DateTime(0)).compareTo(a.readAt ?? DateTime(0)));
    account.spiderReadings = readings;
    notifyListenersSafe();
  }

  Future<void> _getMonthlyUsages(ElectricAccount account, String customerCode) async {
    final res = await _service.getMonthlyUsageHistory(
      customerCode,
      accessToken: account.accessToken,
      cancelToken: cancelToken,
    );
    if (res.isError) return;
    account.monthlyUsages = (res.data ?? []).reversed.toList();
    notifyListenersSafe();
  }

  void _setStatus(ElectricStatus value) {
    _status = value;
    notifyListenersSafe();
  }
}
