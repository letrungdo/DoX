// One-time converter for the legacy chicken import file.
//
// The old JSON stored lunar day/month/year values. The app now stores solar
// dates, so importing that file unchanged would reintroduce ambiguous leap
// months. This tool rewrites every date and marks the file as solar.
//
//   fvm dart run tool/convert_chicken_import_dates.dart
//   fvm dart run tool/convert_chicken_import_dates.dart --yes
library;

import 'dart:convert';
import 'dart:io';

import 'package:do_x/utils/lunar_calendar.dart';

const _defaultPath = 'import_data/chicken_import_2023_2026.json';
const _defaultManifestPath = 'tool/.chicken_dates_migrated.json';

const _knownLeapRecords = {
  ('2025-06-05', 3900000),
  ('2025-06-06', 1900000),
  ('2025-06-10', 1080000),
  ('2025-06-17', 1400000),
  ('2025-06-22', 1900000),
};

void main(List<String> args) {
  final path = args
      .firstWhere(
        (arg) => arg.startsWith('--path='),
        orElse: () => '--path=$_defaultPath',
      )
      .substring('--path='.length);
  final file = File(path);
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  if (root['dateCalendar'] == 'solar') {
    stdout.writeln('$path đã là ngày dương; không cần chuyển.');
    return;
  }

  final manifestPath = args
      .firstWhere(
        (arg) => arg.startsWith('--manifest='),
        orElse: () => '--manifest=$_defaultManifestPath',
      )
      .substring('--manifest='.length);
  final manifestTargets = _readManifestTargets(manifestPath);

  var convertedFromManifest = 0;
  var convertedByCalendar = 0;
  var keptInvalid = 0;

  DateTime convert(
    String table,
    DateTime lunar, {
    int? amount,
    bool leap = false,
  }) {
    final manifestTarget = manifestTargets[(table, _fmt(lunar))];
    if (manifestTarget != null) {
      convertedFromManifest++;
      return manifestTarget;
    }
    if (!_isValidLunarDate(lunar)) {
      keptInvalid++;
      return lunar;
    }
    convertedByCalendar++;
    final knownLeap = _knownLeapRecords.contains((_fmt(lunar), amount));
    return LunarCalendar.lunarDateTimeToSolar(lunar, isLeap: leap || knownLeap);
  }

  void convertField(
    Map<String, dynamic> json,
    String table,
    String key, {
    int? amount,
    bool leap = false,
  }) {
    final value = json[key] as String?;
    if (value == null) return;
    json[key] = _fmt(
      convert(table, DateTime.parse(value), amount: amount, leap: leap),
    );
  }

  for (final rawBatch in (root['batches'] as List?) ?? const []) {
    final batch = rawBatch as Map<String, dynamic>;
    final incubation = DateTime.parse(batch['incubationDate'] as String);
    final hatchValue = batch['actualHatchDate'] as String?;
    if (hatchValue == null) {
      convertField(batch, 'chicken_batches', 'incubationDate');
    } else {
      final hatch = DateTime.parse(hatchValue);
      final (incLeap, hatchLeap) = _inferLeapPair(incubation, hatch);
      convertField(batch, 'chicken_batches', 'incubationDate', leap: incLeap);
      convertField(
        batch,
        'chicken_batches',
        'actualHatchDate',
        leap: hatchLeap,
      );
    }

    for (final rawSale in (batch['sales'] as List?) ?? const []) {
      final sale = rawSale as Map<String, dynamic>;
      convertField(
        sale,
        'batch_sales',
        'date',
        amount: (sale['amount'] as num?)?.toInt(),
      );
    }
    for (final rawVaccination in (batch['vaccinations'] as List?) ?? const []) {
      convertField(
        rawVaccination as Map<String, dynamic>,
        'vaccinations',
        'date',
      );
    }
    for (final rawExpense in (batch['expenses'] as List?) ?? const []) {
      final expense = rawExpense as Map<String, dynamic>;
      convertField(
        expense,
        'expenses',
        'date',
        amount: (expense['amount'] as num?)?.toInt(),
      );
    }
    for (final rawSale in (batch['cockSales'] as List?) ?? const []) {
      final sale = rawSale as Map<String, dynamic>;
      convertField(
        sale,
        'cock_sales',
        'date',
        amount: (sale['amount'] as num?)?.toInt(),
      );
    }
  }

  for (final rawSale in (root['cockSales'] as List?) ?? const []) {
    final sale = rawSale as Map<String, dynamic>;
    convertField(
      sale,
      'cock_sales',
      'date',
      amount: (sale['amount'] as num?)?.toInt(),
    );
  }
  for (final rawExpense in (root['expenses'] as List?) ?? const []) {
    final expense = rawExpense as Map<String, dynamic>;
    convertField(
      expense,
      'expenses',
      'date',
      amount: (expense['amount'] as num?)?.toInt(),
    );
  }

  root['dateCalendar'] = 'solar';
  stdout.writeln(
    '$convertedFromManifest ngày khớp manifest DB, $convertedByCalendar ngày '
    'còn lại được đổi theo lịch; $keptInvalid ngày không phải ngày âm hợp lệ '
    'được giữ nguyên.',
  );
  if (!args.contains('--yes')) {
    stdout.writeln('Chưa ghi file. Thêm --yes sau khi xem số lượng.');
    return;
  }

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(root)}\n',
    flush: true,
  );
  stdout.writeln('Đã cập nhật $path và đánh dấu dateCalendar=solar.');
}

(bool, bool) _inferLeapPair(DateTime incubation, DateTime hatch) {
  var best = (false, false);
  var bestError = 1 << 30;
  for (final incLeap in [false, true]) {
    for (final hatchLeap in [false, true]) {
      if (incLeap && !_hasLeapMonth(incubation)) continue;
      if (hatchLeap && !_hasLeapMonth(hatch)) continue;
      final gap = LunarCalendar.lunarDateTimeToSolar(hatch, isLeap: hatchLeap)
          .difference(
            LunarCalendar.lunarDateTimeToSolar(incubation, isLeap: incLeap),
          )
          .inDays;
      final error = (gap - 21).abs();
      if (error < bestError) {
        bestError = error;
        best = (incLeap, hatchLeap);
      }
    }
  }
  return best;
}

bool _isValidLunarDate(DateTime lunar) =>
    lunar.day >= 1 &&
    lunar.month >= 1 &&
    lunar.month <= 12 &&
    lunar.day <= LunarCalendar.daysInLunarMonth(lunar.month, lunar.year);

bool _hasLeapMonth(DateTime lunar) =>
    LunarCalendar.lunarToSolar(
      lunar.day,
      lunar.month,
      lunar.year,
      isLeap: true,
    ) !=
    LunarCalendar.lunarToSolar(lunar.day, lunar.month, lunar.year);

String _fmt(DateTime date) => date.toIso8601String().substring(0, 10);

Map<(String, String), DateTime> _readManifestTargets(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final targets = <(String, String), DateTime>{};
  for (final raw in (root['changes'] as List?) ?? const []) {
    final change = raw as Map<String, dynamic>;
    final key = (change['table'] as String, change['from'] as String);
    final target = DateTime.parse(change['to'] as String);
    final previous = targets[key];
    if (previous != null && previous != target) {
      throw StateError(
        'Manifest có hai cách đổi khác nhau cho ${key.$1} ${key.$2}.',
      );
    }
    targets[key] = target;
  }
  return targets;
}
