import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/services/tv_channel_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class TvViewModel extends CoreViewModel {
  List<TvChannel> _channels = [];

  /// Channels left after the category and the search box have had their say —
  /// what the grid draws.
  List<TvChannel> _visibleChannels = [];
  List<TvChannel> get channels => _visibleChannels;

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
      final channels = await tvChannelService.getChannels(
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
