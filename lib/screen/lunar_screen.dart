import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

@RoutePage()
class LunarScreen extends StatefulWidget {
  const LunarScreen({super.key});

  @override
  State<LunarScreen> createState() => _LunarScreenState();
}

class _LunarScreenState extends State<LunarScreen> {
  /// Month currently focused in the calendar (drives the header + page).
  late DateTime _focusedDay;
  late DateTime _selected;

  static final _firstDay = DateTime(2000);
  static final _lastDay = DateTime(2100, 12, 31);

  MainViewModel? _mainViewModel;
  late final Future<void> Function() _tabReselectHandler;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _focusedDay = _selected;
    _tabReselectHandler = _handleTabReselect;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mainViewModel = context.read<MainViewModel>();
    if (identical(_mainViewModel, mainViewModel)) return;
    _mainViewModel?.unregisterTabReselectHandler(
      LunarRoute.name,
      _tabReselectHandler,
    );
    _mainViewModel = mainViewModel;
    mainViewModel.registerTabReselectHandler(
      LunarRoute.name,
      _tabReselectHandler,
    );
  }

  @override
  void dispose() {
    _mainViewModel?.unregisterTabReselectHandler(
      LunarRoute.name,
      _tabReselectHandler,
    );
    super.dispose();
  }

  Future<void> _handleTabReselect() async {
    _goToToday();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selected = DateTime(now.year, now.month, now.day);
      _focusedDay = _selected;
    });
  }

  void _shiftMonth(int delta) {
    final target = DateTime(_focusedDay.year, _focusedDay.month + delta);
    setState(() {
      _focusedDay = target.isBefore(_firstDay)
          ? _firstDay
          : (target.isAfter(_lastDay) ? _lastDay : target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.lunarCalendar,
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: l10n.lunarToday,
            onPressed: _goToToday,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildCalendarCard(context),
              const SizedBox(height: 14),
              _buildDetailCard(context, l10n),
            ],
          ).webConstrainedBox(),
        ),
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Column(
          children: [
            _buildMonthHeader(context),
            const SizedBox(height: 4),
            _buildTableCalendar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();
    final title = DateFormat.yMMMM(localeName).format(_focusedDay);

    // Lunar year label from the 1st of the focused month.
    final lunar = LunarCalendar.solarToLunar(1, _focusedDay.month, _focusedDay.year);
    final canChiYear = LunarCalendar.canChiOfYear(lunar.year);

    return Row(
      children: [
        IconButton(
          onPressed: () => _shiftMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _capitalize(title),
                style: context.theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Năm $canChiYear',
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _shiftMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildTableCalendar(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();

    return TableCalendar(
      locale: localeName,
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      currentDay: DateTime.now(),
      rowHeight: 56,
      daysOfWeekHeight: 22,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerVisible: false,
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (day) => isSameDay(_selected, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selected = DateTime(
            selectedDay.year,
            selectedDay.month,
            selectedDay.day,
          );
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      calendarBuilders: CalendarBuilders(
        dowBuilder: (context, day) {
          final label = _capitalize(
            DateFormat.E(localeName).format(day),
          );
          return Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: day.weekday == DateTime.sunday
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            ),
          );
        },
        defaultBuilder: (context, day, _) => _cell(context, day),
        outsideBuilder: (context, day, _) =>
            _cell(context, day, isOutside: true),
        todayBuilder: (context, day, _) => _cell(context, day, isToday: true),
        selectedBuilder: (context, day, _) => _cell(
          context,
          day,
          isSelected: true,
          isToday: isSameDay(day, DateTime.now()),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime date, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final scheme = context.theme.colorScheme;
    final isSunday = date.weekday == DateTime.sunday;

    final lunar = LunarCalendar.solarToLunar(date.day, date.month, date.year);
    final showLunarMonth = lunar.day == 1;
    final lunarText = showLunarMonth
        ? '${lunar.day}/${lunar.month}'
        : '${lunar.day}';

    final baseColor = isSunday ? scheme.error : scheme.onSurface;
    final solarColor = isOutside ? baseColor.withValues(alpha: 0.3) : baseColor;
    // Mùng 1 & rằm stand out in red, like paper almanacs.
    final isSpecialLunar = lunar.day == 1 || lunar.day == 15;
    final lunarColor = isSpecialLunar ? scheme.error : scheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected ? scheme.primaryContainer : null,
        border: Border.all(
          color: isToday ? scheme.primary : Colors.transparent,
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isToday || isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isSelected ? scheme.onPrimaryContainer : solarColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lunarText,
            style: TextStyle(
              fontSize: 10,
              color: (isSelected ? scheme.onPrimaryContainer : lunarColor)
                  .withValues(alpha: isOutside ? 0.4 : 1),
              fontWeight: showLunarMonth || isSpecialLunar
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, AppLocalizations l10n) {
    final scheme = context.theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();
    final s = _selected;
    final lunar = LunarCalendar.solarToLunar(s.day, s.month, s.year);
    final canChiDay = LunarCalendar.canChiOfDay(s.day, s.month, s.year);
    final canChiMonth = LunarCalendar.canChiOfMonth(lunar.month, lunar.year);
    final canChiYear = LunarCalendar.canChiOfYear(lunar.year);
    final leapSuffix = lunar.isLeap ? ' (${l10n.lunarLeapMonth})' : '';
    final quality = LunarCalendar.dayQuality(s.day, s.month, s.year, lunar.month);
    final canChiHour = LunarCalendar.canChiOfZiHour(s.day, s.month, s.year);
    final solarTerm = LunarCalendar.solarTerm(s.day, s.month, s.year);
    final tide = LunarCalendar.tideLabel(lunar.day);
    final goodHours = LunarCalendar.goodHours(s.day, s.month, s.year);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _capitalize(DateFormat.yMMMMEEEEd(localeName).format(s)),
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _dayQualityBadge(context, l10n, quality.isGood, quality.star),
            const Divider(height: 24),
            _detailRow(
              context,
              l10n.lunarLunarDate,
              'Ngày ${lunar.day} tháng ${lunar.month}$leapSuffix năm $canChiYear',
              highlight: true,
            ),
            const SizedBox(height: 8),
            _detailRow(context, l10n.lunarCanChiDay, canChiDay),
            const SizedBox(height: 8),
            _detailRow(context, l10n.lunarCanChiMonth, canChiMonth),
            const SizedBox(height: 8),
            _detailRow(context, l10n.lunarCanChiHour, canChiHour),
            const SizedBox(height: 8),
            _detailRow(context, l10n.lunarSolarTerm, solarTerm),
            const SizedBox(height: 8),
            _detailRow(context, l10n.lunarTide, tide),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.lunarGoodHours,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in goodHours) _hourChip(context, h),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayQualityBadge(
    BuildContext context,
    AppLocalizations l10n,
    bool isGood,
    String star,
  ) {
    final scheme = context.theme.colorScheme;
    final color = isGood ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isGood ? l10n.lunarGoodDay : l10n.lunarBadDay,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            star,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _hourChip(BuildContext context, String label) {
    final scheme = context.theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final scheme = context.theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? scheme.primary : null,
            ),
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
