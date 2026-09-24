import 'dart:async';

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

  /// The query as the filter compares it, folded once per search rather than
  /// once per channel.
  String _normalizedQuery = '';

  /// Holds a query back until the typing pauses. Every keystroke would
  /// otherwise run the whole playlist through the filter and rebuild the
  /// grid, on a television whose on-screen keyboard is already slow.
  Timer? _searchDebounce;

  /// How long the typing has to pause before the grid follows it.
  static const searchDebounce = Duration(milliseconds: 150);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  /// Set when there is nothing to show at all. A refresh that fails while
  /// channels are already on screen leaves them there and stays silent.
  bool _hasError = false;
  bool get hasError => _hasError;

  /// Everything the country broadcasts, before any filter.
  ///
  /// What the app bar counts, and what a channel opened from the search page
  /// travels with: the query was how the viewer found the channel, not what
  /// they want the remote limited to once it is playing.
  List<TvChannel> get allChannels => _channels;

  int get totalChannels => _channels.length;

  /// True when the filters, not the source, are why the grid is empty.
  bool get isFilteredEmpty => _visibleChannels.isEmpty && _channels.isNotEmpty;

  @override
  void initData() {
    super.initData();
    load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _isRefreshing = true;
    } else {
      _isLoading = _channels.isEmpty;
    }
    _hasError = false;
    notifyListenersSafe();

    // The list this run fetches is the one that counts, but it is a round
    // trip away and the copy on disk is already here. It goes up first, so
    // that opening the app shows television rather than a spinner — and on a
    // line that is down, shows it at all.
    if (_isLoading) await _showStoredChannels();
    if (isDispose) return;

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

  /// Puts the last list that reached the app on screen, with the fetch that
  /// will replace it still out — the app bar's spinner says as much.
  ///
  /// Read for the country stored from last time, not for [_country]: the
  /// catalogue that turns the stored code into a country has not been read
  /// yet, and until it is [_country] is Vietnam whatever the viewer picked.
  Future<void> _showStoredChannels() async {
    final code = _countries.isEmpty
        ? (storageService.getTvCountry() ?? _country.code)
        : _country.code;
    final stored = await tvChannelService.storedChannels(code);
    if (isDispose) return;
    // Something else put a list up in the meantime.
    if (_channels.isNotEmpty) return;
    if (stored == null || stored.isEmpty) return;
    _channels = stored;
    _groups = _collectGroups(stored);
    _applyFilters();
    _isLoading = false;
    _isRefreshing = true;
    notifyListenersSafe();
  }

  /// Fetches the list again, whenever it was last fetched — what the viewer
  /// asks for by pulling the grid down or tapping the tab they are on.
  Future<void> onRefresh() => load(forceRefresh: true);

  /// Fetches the list again unless it is still fresh — what switching into
  /// the tab asks for.
  ///
  /// Every switch refreshes the page it lands on, but a list read a minute
  /// ago is the list as it stands, and fetching, reading and storing a whole
  /// country's playlist again for it is work with nothing to show for it.
  Future<void> refreshIfStale() async {
    if (_isLoading || _isRefreshing) return;
    if (tvChannelService.isFresh(_country.playlistCode)) return;
    await onRefresh();
  }

  /// Filters the list by [query] once the typing pauses, or straight away
  /// when [immediately] — the keyboard's Search key, which means the typing
  /// is over and the results are wanted now.
  void search(String query, {bool immediately = false}) {
    _searchDebounce?.cancel();
    if (_query == query) return;
    // Emptying the box is not typing: the whole list comes back at once.
    if (query.isEmpty || immediately) {
      _applySearch(query);
      return;
    }
    _searchDebounce = Timer(searchDebounce, () => _applySearch(query));
  }

  void _applySearch(String query) {
    if (isDispose || _query == query) return;
    _query = query;
    _normalizedQuery = TvChannel.normalizeName(query);
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
              channel.matchesNormalized(_normalizedQuery),
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
