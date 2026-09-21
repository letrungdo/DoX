import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/model/tv_country.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/tv_catalog_service.dart';
import 'package:do_x/services/tv_channel_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class TvViewModel extends CoreViewModel {
  List<TvChannel> _channels = [];

  /// Channels left after the country, the category and the search box have
  /// had their say — what the grid draws.
  List<TvChannel> _visibleChannels = [];
  List<TvChannel> get channels => _visibleChannels;

  /// Every country the catalogue lists, for the picker. Empty until it loads.
  List<TvCountry> _countries = const [];
  List<TvCountry> get countries => _countries;

  /// The country whose playlist is on screen. Vietnam until the stored choice
  /// and the catalogue say otherwise.
  TvCountry _country = TvCountry.vietnam;
  TvCountry get country => _country;

  /// Every category the playlist mentions, in the order the chips show them.
  /// Empty while nothing is loaded; `null` in [selectedGroup] means "all".
  List<String> _groups = [];
  List<String> get groups => _groups;

  String? _selectedGroup;
  String? get selectedGroup => _selectedGroup;

  String _query = '';
  String get query => _query;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  /// Set when there is nothing to show at all. A refresh that fails while
  /// channels are already on screen leaves them there and stays silent.
  bool _hasError = false;
  bool get hasError => _hasError;

  /// Everything the country broadcasts, before any filter — what the app bar
  /// counts.
  int get totalChannels => _channels.length;

  /// True when the filters, not the source, are why the grid is empty.
  bool get isFilteredEmpty => _visibleChannels.isEmpty && _channels.isNotEmpty;

  @override
  void initData() {
    super.initData();
    load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _isRefreshing = true;
    } else {
      _isLoading = _channels.isEmpty;
    }
    _hasError = false;
    notifyListenersSafe();

    try {
      await _loadCatalog();
      if (isDispose) return;

      final channels = await tvChannelService.getChannels(
        _country.playlistCode,
        forceRefresh: forceRefresh,
      );
      if (isDispose) return;
      _channels = channels;
      _groups = _collectGroups(channels);
      if (_selectedGroup != null && !_groups.contains(_selectedGroup)) {
        _selectedGroup = null;
      }
      _applyFilters();
    } catch (e, st) {
      logger.e('TvViewModel load failed', error: e, stackTrace: st);
      if (isDispose) return;
      _hasError = _channels.isEmpty;
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListenersSafe();
    }
  }

  Future<void> onRefresh() => load(forceRefresh: true);

  void search(String query) {
    if (_query == query) return;
    _query = query;
    _applyFilters();
    notifyListenersSafe();
  }

  void selectGroup(String? group) {
    if (_selectedGroup == group) return;
    _selectedGroup = group;
    _applyFilters();
    notifyListenersSafe();
  }

  /// Switches the page to another country's playlist.
  ///
  /// The category belongs to the country that declared it, so it is cleared;
  /// the search box is the user's own words and stays.
  Future<void> selectCountry(TvCountry country) async {
    if (country.code == _country.code) return;
    _country = country;
    _selectedGroup = null;
    _channels = [];
    _groups = [];
    _visibleChannels = [];
    await storageService.setTvCountry(country.code);
    await load();
  }

  /// Resolves the country catalogue and the choice stored from last time.
  /// Only ever runs its full course once — afterwards the picker is filled.
  Future<void> _loadCatalog() async {
    if (_countries.isNotEmpty) return;

    final countries = await tvCatalogService.getCountries();
    if (isDispose) return;
    _countries = countries;

    final storedCountry = storageService.getTvCountry();
    _country = countries.firstWhere(
      (country) => country.code == (storedCountry ?? TvCountry.vietnam.code),
      orElse: () => countries.firstWhere(
        (country) => country.code == TvCountry.vietnam.code,
        orElse: () => countries.isEmpty ? TvCountry.vietnam : countries.first,
      ),
    );
  }

  void _applyFilters() {
    final group = _selectedGroup;
    _visibleChannels = _channels
        .where(
          (channel) =>
              (group == null || channel.groups.contains(group)) &&
              channel.matches(_query),
        )
        .toList();
  }

  /// Categories ordered by how many channels carry them, so the chips the user
  /// is most likely to want sit nearest the left edge.
  List<String> _collectGroups(List<TvChannel> channels) {
    final counts = <String, int>{};
    for (final channel in channels) {
      for (final group in channel.groups) {
        counts[group] = (counts[group] ?? 0) + 1;
      }
    }
    final groups = counts.keys.toList();
    groups.sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
    return groups;
  }
}
