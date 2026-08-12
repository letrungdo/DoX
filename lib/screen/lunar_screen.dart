import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/lunar_calendar_grid.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

@RoutePage()
class LunarScreen extends StatefulWidget {
  const LunarScreen({super.key});

  @override
  State<LunarScreen> createState() => _LunarScreenState();
}

class _LunarScreenState extends State<LunarScreen> with TabReselect {
  /// Month currently focused in the calendar (drives the header + page).
  late DateTime _focusedDay;
  late DateTime _selected;
  final _scrollController = ScrollController();

  static final _firstDay = DateTime(2000);
  static final _lastDay = DateTime(2100, 12, 31);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _focusedDay = _selected;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  String get tabRouteName => LunarRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  /// This page has nothing to fetch, so "reload" means jumping the calendar
  /// back to today.
  @override
  Future<void> onTabRefresh() async => _goToToday();

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
    return AppScaffold(
      bottom: true,
      appBar: DoAppBar(
        title: l10n.lunarCalendar,
        actions: [
          NeuIconButton(
            size: Dimens.appBarActionSize,
            iconSize: 18,
            depth: Dimens.appBarActionDepth,
            icon: Icons.today_rounded,
            tooltip: l10n.lunarToday,
            onPressed: _goToToday,
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        // Padding inside the cap, never around it: that is what keeps a card
        // here the same width as a card on any other page.
        child: Padding(
          padding: Dimens.screenPadding,
          child: Column(
            children: [
              _buildCalendarCard(context),
              const SizedBox(height: 14),
              _buildDetailCard(context, l10n),
            ],
          ),
        ).contentConstrainedBox(),
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context) {
    return NeuCard(
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
    final lunar = LunarCalendar.solarToLunar(
      1,
      _focusedDay.month,
      _focusedDay.year,
    );
    final canChiYear = LunarCalendar.canChiOfYear(lunar.year);

    return Row(
      children: [
        NeuIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: () => _shiftMonth(-1),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _capitalize(title),
                style: context.theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Năm $canChiYear',
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        NeuIconButton(
          icon: Icons.chevron_right_rounded,
          onPressed: () => _shiftMonth(1),
        ),
      ],
    );
  }

  Widget _buildTableCalendar(BuildContext context) {
    return LunarCalendarGrid(
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      selectedDay: _selected,
      onDaySelected: (selected, focused) {
        setState(() {
          _selected = DateTime(selected.year, selected.month, selected.day);
          _focusedDay = focused;
        });
      },
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
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
    final quality = LunarCalendar.dayQuality(
      s.day,
      s.month,
      s.year,
      lunar.month,
    );
    final canChiHour = LunarCalendar.canChiOfZiHour(s.day, s.month, s.year);
    final solarTerm = LunarCalendar.solarTerm(s.day, s.month, s.year);
    final tide = LunarCalendar.tideLabel(lunar.day);
    final goodHours = LunarCalendar.goodHours(s.day, s.month, s.year);

    return NeuCard(
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
              children: [for (final h in goodHours) _hourChip(context, h)],
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
        color: context.neuTint(color, amount: 0.14),
        borderRadius: BorderRadius.circular(Dimens.radiusPanel),
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
          Text(star, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _hourChip(BuildContext context, String label) {
    final scheme = context.theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.neuTint(scheme.primary, amount: 0.14),
        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
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
          child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
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
