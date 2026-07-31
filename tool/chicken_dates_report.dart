// Chuyển ngày của dữ liệu gà trên Supabase từ ÂM LỊCH sang DƯƠNG LỊCH.
//
// App từng lưu ngày âm lịch; nay lưu ngày dương (âm lịch chỉ để hiển thị).
// Mọi bản ghi hiện có — cả nhập tay lẫn nhập từ import_data/*.json — đều đang là
// ngày âm, nên phải chuyển hết.
//
//   # 1. Xem trước, không ghi gì cả
//   fvm dart run tool/chicken_dates_report.dart --email=... --password=...
//
//   # 2. Ghi thật
//   fvm dart run tool/chicken_dates_report.dart --email=... --password=... --yes
//
// Trước khi ghi, tool lưu toàn bộ kế hoạch + dữ liệu gốc vào
// tool/.chicken_dates_migrated.json. Nếu mạng/process lỗi giữa chừng, chạy lại
// đúng lệnh --yes sẽ tiếp tục từ phần chưa ghi thay vì chuyển trùng.
//
// Hai chỗ cần biết:
//
// * NGÀY ẤP không có trong sổ tay — file import lấy ngày nở trừ 21 bằng phép trừ
//   ngày dương, nên nhiều giá trị không phải ngày âm hợp lệ (có cả ngày 31).
//   Chuyển thẳng chúng là chuyển rác, nên ngày ấp được tính lại = ngày nở dương
//   trừ 21. Lứa nào không có ngày nở thì mới chuyển trực tiếp.
//
// * THÁNG NHUẬN không lưu được trong một DateTime, nên bản ghi rơi vào tháng có
//   nhuận là hai nghĩa: tháng thường hay tháng nhuận đều ra cùng con số. Công cụ
//   đánh dấu [NHUẬN?] cho từng bản ghi như vậy; những bản ghi anh ghi "sau"
//   trong sổ đã liệt kê sẵn ở _knownLeapRecords. Bản ghi nào cần đổi lại thì
//   thêm --leap=<mã> hoặc --no-leap=<mã> (mã in ở cột đầu).
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:do_x/utils/lunar_calendar.dart';

const _supabaseUrl = 'https://fyyrgwohjgvsmwqgxiga.supabase.co';
const _supabaseKey = 'sb_publishable_INnX8-J4b0vgHJlkD5lE3A_xG1S1SDs';

const _ledgerPath = 'tool/.chicken_dates_migrated.json';

/// Các cột ngày cần chuyển, theo từng bảng.
const _dateColumns = {
  'chicken_batches': ['incubation_date', 'actual_hatch_date'],
  'batch_sales': ['date'],
  'expenses': ['date'],
  'cock_sales': ['date'],
  'vaccinations': ['scheduled_date'],
};

/// Những bản ghi sổ tay ghi rõ là tháng nhuận ("6 sau"), nhận diện theo ngày âm
/// đang lưu + số tiền. 2025 nhuận tháng 6; các dòng "6 trước" thì không có ở
/// đây vì mặc định đã là tháng thường.
const _knownLeapRecords = {
  ('2025-06-05', 3900000), // Nhỏ, sổ ghi "5/6 sau"
  ('2025-06-06', 1900000), // Hòa Hậu, "6/6 sau"
  ('2025-06-10', 1080000), // 30 con x 36k, "10/6 sau"
  ('2025-06-17', 1400000), // Hòa Hậu, "17/6 sau"
  ('2025-06-22', 1900000), // Hòa Hậu, "22/6 sau"
};

late final Dio _dio;

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options == null) return;

  _dio = Dio(
    BaseOptions(
      baseUrl: _supabaseUrl,
      headers: {'apikey': _supabaseKey},
      // Lỗi HTTP được xử lý ở dưới, không ném ra giữa chừng.
      validateStatus: (_) => true,
    ),
  );

  final token = await _signIn(options.email, options.password);
  if (token == null) return;
  _dio.options.headers['Authorization'] = 'Bearer $token';

  final data = await _fetchAll();
  if (data == null) return;

  final ledger = _readLedger();
  if (exitCode != 0) return;
  if (ledger?.status == _LedgerStatus.complete && !options.force) {
    stderr.writeln(
      'Dừng lại: dữ liệu đã được chuyển trước đó ($_ledgerPath). Chuyển lần nữa '
      'sẽ đẩy mọi ngày sai thêm khoảng một tháng. Thêm --force nếu chắc chắn.',
    );
    exitCode = 1;
    return;
  }

  final changes = ledger?.status == _LedgerStatus.running && !options.force
      ? ledger!.changes
      : _plan(data, options);
  _printPlan(changes);

  if (!options.yes) {
    if (ledger?.status == _LedgerStatus.running) {
      stdout.writeln(
        '\nCó một lần chuyển chưa hoàn tất. Chạy lại với --yes để tool đối '
        'chiếu DB và tiếp tục an toàn.',
      );
      return;
    }
    stdout.writeln(
      '\nChưa ghi gì cả. Xem kỹ các dòng [NHUẬN?] ở trên; nếu cần sửa thì thêm '
      '--leap=<mã> / --no-leap=<mã>. Thêm --yes để ghi thật.',
    );
    return;
  }

  if (ledger?.status != _LedgerStatus.running || options.force) {
    _writeLedger(
      _Ledger(status: _LedgerStatus.running, changes: changes, backup: data),
    );
  }
  await _apply(changes, data);
}

// --- Đăng nhập & đọc dữ liệu ------------------------------------------------

Future<String?> _signIn(String email, String password) async {
  final response = await _dio.post<Map<String, dynamic>>(
    '/auth/v1/token',
    queryParameters: {'grant_type': 'password'},
    data: {'email': email, 'password': password},
  );
  final token = response.data?['access_token'] as String?;
  if (token == null) {
    stderr.writeln(
      'Đăng nhập thất bại: ${response.statusCode} ${response.data}',
    );
    exitCode = 1;
  }
  return token;
}

typedef _Rows = Map<String, List<Map<String, dynamic>>>;

Future<_Rows?> _fetchAll() async {
  final rows = <String, List<Map<String, dynamic>>>{};
  for (final table in _dateColumns.keys) {
    final response = await _dio.get<List<dynamic>>(
      '/rest/v1/$table',
      queryParameters: {'select': '*'},
    );
    if (response.statusCode != 200 || response.data == null) {
      stderr.writeln(
        'Đọc bảng $table thất bại: ${response.statusCode} ${response.data}',
      );
      exitCode = 1;
      return null;
    }
    rows[table] = response.data!.cast<Map<String, dynamic>>();
  }
  return rows;
}

// --- Lập kế hoạch chuyển ----------------------------------------------------

/// Một cột ngày của một dòng, kèm giá trị mới.
class _Change {
  final String code;
  final String table;
  final String rowId;
  final String column;
  final DateTime from;
  final DateTime to;
  final String label;

  /// Tháng âm của [from] là tháng có nhuận, nên con số đang lưu không nói được
  /// nó thuộc tháng thường hay tháng nhuận.
  final bool ambiguous;
  final bool treatedAsLeap;

  /// Ngày ấp được tính lại từ ngày nở thay vì chuyển thẳng, vì giá trị đang lưu
  /// không phải ngày âm có thật.
  final bool recomputed;

  _Change({
    required this.code,
    required this.table,
    required this.rowId,
    required this.column,
    required this.from,
    required this.to,
    required this.label,
    required this.ambiguous,
    required this.treatedAsLeap,
    this.recomputed = false,
  });

  factory _Change.fromJson(Map<String, dynamic> json) => _Change(
    code: json['code'] as String,
    table: json['table'] as String,
    rowId: json['rowId'] as String,
    column: json['column'] as String,
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
    label: json['label'] as String,
    ambiguous: json['ambiguous'] as bool,
    treatedAsLeap: json['treatedAsLeap'] as bool,
    recomputed: json['recomputed'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'table': table,
    'rowId': rowId,
    'column': column,
    'from': _fmt(from),
    'to': _fmt(to),
    'label': label,
    'ambiguous': ambiguous,
    'treatedAsLeap': treatedAsLeap,
    'recomputed': recomputed,
  };
}

List<_Change> _plan(_Rows data, _Options options) {
  final changes = <_Change>[];
  var counter = 0;

  for (final entry in _dateColumns.entries) {
    final table = entry.key;
    for (final row in data[table]!) {
      final amount = (row['amount'] as num?)?.toInt();

      // Mã và cờ nhuận được chốt cho cả dòng trước, vì ngày ấp đi theo cờ nhuận
      // của NGÀY NỞ chứ không phải của chính nó.
      final codes = <String, String>{};
      final leaps = <String, bool>{};
      for (final column in entry.value) {
        final stored = _parse(row[column]);
        if (stored == null) continue;
        final code = 'r${++counter}';
        codes[column] = code;
        leaps[column] =
            options.leap.contains(code) ||
            (_knownLeapRecords.contains((_fmt(stored), amount)) &&
                !options.noLeap.contains(code));
      }

      // Ngày ấp chỉ được tính lại khi giá trị đang lưu KHÔNG phải ngày âm hợp lệ
      // — dấu hiệu của phép trừ 21 lúc dựng file import. Ngày ấp anh tự bấm
      // trong app luôn là ngày âm hợp lệ và được giữ nguyên, vì nó là mốc thật
      // và không nhất thiết cách ngày nở đúng 21 ngày.
      final hatch = _parse(row['actual_hatch_date']);
      final incubation = _parse(row['incubation_date']);
      final derivesIncubation =
          table == 'chicken_batches' &&
          hatch != null &&
          incubation != null &&
          !_isValidLunarDate(incubation);

      // Trứng nở sau khoảng 21 ngày, nên với một lứa có đủ ngày ấp và ngày nở,
      // cách đọc tháng nhuận nào cho ra khoảng cách gần 21 nhất là cách đọc
      // đúng — một lứa "ấp 12/6, nở 3/7" của năm nhuận tháng 6 mà đọc cả hai là
      // tháng thường thì thành 50 ngày, vô lý. Chỉ suy khi anh không tự chỉ định.
      if (!derivesIncubation && incubation != null && hatch != null) {
        final touched = [
          codes['incubation_date'],
          codes['actual_hatch_date'],
        ].any((c) => options.leap.contains(c) || options.noLeap.contains(c));
        if (!touched) {
          final (incLeap, hatchLeap) = _inferLeapPair(incubation, hatch);
          leaps['incubation_date'] = incLeap;
          leaps['actual_hatch_date'] = hatchLeap;
        }
      }

      for (final column in entry.value) {
        final stored = _parse(row[column]);
        if (stored == null) continue;
        final derived = derivesIncubation && column == 'incubation_date';
        // Cột quyết định cách đọc: ngày ấp mượn cờ nhuận và tính mập mờ của ngày nở.
        final source = derived ? 'actual_hatch_date' : column;
        final leap = leaps[source] ?? false;

        changes.add(
          _Change(
            code: codes[column]!,
            table: table,
            rowId: row['id'] as String,
            column: column,
            from: stored,
            to: derived
                ? _toSolar(hatch, leap: leap).subtract(const Duration(days: 21))
                : _toSolar(stored, leap: leap),
            label: _labelOf(table, row),
            ambiguous: _hasLeapMonth(derived ? hatch : stored),
            treatedAsLeap: leap,
            recomputed: derived,
          ),
        );
      }
    }
  }
  changes.sort((a, b) => a.from.compareTo(b.from));
  return changes;
}

String _labelOf(String table, Map<String, dynamic> row) {
  final name = row['name'] ?? row['title'] ?? row['note'] ?? '';
  final amount = row['amount'];
  final money = amount == null ? '' : ' · ${(amount as num).toInt()}đ';
  return '$table: $name$money';
}

/// Cách đọc tháng nhuận cho cặp (ngày ấp, ngày nở) đưa khoảng cách thật về gần
/// 21 ngày nhất. Hòa thì chọn tháng thường, vì đó là cách đọc mặc định.
(bool, bool) _inferLeapPair(DateTime incubation, DateTime hatch) {
  var best = (false, false);
  var bestError = 1 << 30;
  for (final incLeap in [false, true]) {
    for (final hatchLeap in [false, true]) {
      // Bỏ qua cách đọc "nhuận" ở tháng không hề có nhuận: nó ra đúng ngày như
      // tháng thường, chỉ làm nhiễu.
      if (incLeap && !_hasLeapMonth(incubation)) continue;
      if (hatchLeap && !_hasLeapMonth(hatch)) continue;
      final gap = _toSolar(
        hatch,
        leap: hatchLeap,
      ).difference(_toSolar(incubation, leap: incLeap)).inDays;
      final error = (gap - 21).abs();
      if (error < bestError) {
        bestError = error;
        best = (incLeap, hatchLeap);
      }
    }
  }
  return best;
}

/// Đúng khi [lunar] là một ngày âm có thật: tháng âm chỉ có 29 hoặc 30 ngày,
/// nên "ngày 30" của một tháng thiếu, hay ngày 31, là con số do tính toán sinh
/// ra chứ không phải ngày ai đó chọn trên lịch.
bool _isValidLunarDate(DateTime lunar) =>
    lunar.day >= 1 &&
    lunar.month >= 1 &&
    lunar.month <= 12 &&
    lunar.day <= LunarCalendar.daysInLunarMonth(lunar.month, lunar.year);

/// Đúng khi tháng âm của [lunar] là tháng có nhuận trong năm đó — tức con số
/// đang lưu có hai cách đọc.
bool _hasLeapMonth(DateTime lunar) =>
    LunarCalendar.lunarToSolar(
      lunar.day,
      lunar.month,
      lunar.year,
      isLeap: true,
    ) !=
    LunarCalendar.lunarToSolar(lunar.day, lunar.month, lunar.year);

void _printPlan(List<_Change> changes) {
  final ambiguous = changes.where((c) => c.ambiguous).toList();
  stdout.writeln('${changes.length} ngày sẽ được chuyển:\n');
  for (final change in changes) {
    final mark = [
      if (change.ambiguous) change.treatedAsLeap ? '[NHUẬN]' : '[NHUẬN?]',
      if (change.recomputed) '[TÍNH LẠI]',
    ].join(' ');
    stdout.writeln(
      '${change.code.padRight(5)} ${_fmt(change.from)} → ${_fmt(change.to)}'
      '${mark.isEmpty ? '' : '  $mark'}  ${change.label}',
    );
  }

  final recomputed = changes.where((c) => c.recomputed).length;
  if (recomputed > 0) {
    stdout.writeln(
      '\n$recomputed ngày ấp được tính lại = ngày nở trừ 21, vì giá trị đang lưu '
      'không phải ngày âm có thật (do file import trừ ra). Ngày ấp nhập tay qua '
      'app không nằm trong số này — chúng được chuyển thẳng và giữ nguyên khoảng '
      'cách thật tới ngày nở.',
    );
  }
  if (ambiguous.isEmpty) return;
  stdout.writeln(
    '\n${ambiguous.length} bản ghi rơi vào tháng có nhuận. [NHUẬN] là những bản '
    'ghi sổ tay ghi "sau" (đã nhận ra sẵn); [NHUẬN?] đang được hiểu là tháng '
    'thường — bản ghi anh nhập tay trong tháng nhuận sẽ hiện ở đây và cần anh '
    'quyết. Sai chỗ nào thì thêm --leap=<mã> hoặc --no-leap=<mã>.',
  );
}

// --- Ghi lên Supabase -------------------------------------------------------

Future<void> _apply(List<_Change> changes, _Rows currentData) async {
  // Gom theo dòng: một dòng có thể có hai cột ngày (lứa gà).
  final byRow = <(String, String), List<_Change>>{};
  for (final change in changes) {
    byRow.putIfAbsent((change.table, change.rowId), () => []).add(change);
  }

  var updated = 0;
  var alreadyDone = 0;
  for (final entry in byRow.entries) {
    final (table, rowId) = entry.key;
    final current = currentData[table]!.where((row) => row['id'] == rowId);
    if (current.length != 1) {
      stderr.writeln(
        'Dừng an toàn: không tìm thấy đúng một dòng $table/$rowId. '
        'Backup và kế hoạch vẫn nằm ở $_ledgerPath.',
      );
      exitCode = 1;
      return;
    }

    final patch = <String, dynamic>{};
    var rowAlreadyDone = true;
    for (final change in entry.value) {
      final value = _parse(current.single[change.column]);
      if (value == change.to) continue;
      rowAlreadyDone = false;
      if (value != change.from) {
        stderr.writeln(
          'Dừng an toàn: $table/$rowId.${change.column} hiện là '
          '${value == null ? 'null' : _fmt(value)}, không khớp cả giá trị gốc '
          '${_fmt(change.from)} lẫn giá trị đích ${_fmt(change.to)}. Không ghi '
          'đè thay đổi mới; backup vẫn nằm ở $_ledgerPath.',
        );
        exitCode = 1;
        return;
      }
      patch[change.column] = _fmt(change.to);
    }
    if (rowAlreadyDone) {
      alreadyDone++;
      continue;
    }

    final response = await _dio.patch<dynamic>(
      '/rest/v1/$table',
      queryParameters: {'id': 'eq.$rowId'},
      data: patch,
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      stderr.writeln(
        'Ghi $table/$rowId thất bại: ${response.statusCode} ${response.data}. '
        'Đã ghi được $updated dòng — sổ ghi nhận KHÔNG được đánh dấu, nên hãy '
        'kiểm tra dữ liệu trước khi chạy lại.',
      );
      exitCode = 1;
      return;
    }
    updated++;
  }

  final after = await _fetchAll();
  if (after == null || !_verify(changes, after)) {
    stderr.writeln(
      'Ghi đã chạy nhưng bước kiểm tra cuối không khớp. Không đánh dấu hoàn '
      'tất; chạy lại cùng lệnh --yes để kiểm tra/tiếp tục. Backup nằm ở '
      '$_ledgerPath.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Đã chuyển $updated dòng mới, bỏ qua $alreadyDone dòng đã xong '
    '(${changes.length} ngày) sang dương và kiểm tra lại thành công.',
  );
  _writeLedger(
    _Ledger(
      status: _LedgerStatus.complete,
      changes: changes,
      backup: _readLedger()!.backup,
    ),
  );
  stdout.writeln('Đã đánh dấu $_ledgerPath là hoàn tất.');
}

// --- Sổ ghi nhận đã chuyển --------------------------------------------------

enum _LedgerStatus { running, complete }

class _Ledger {
  final _LedgerStatus status;
  final List<_Change> changes;
  final _Rows backup;

  const _Ledger({
    required this.status,
    required this.changes,
    required this.backup,
  });

  factory _Ledger.fromJson(Map<String, dynamic> json) => _Ledger(
    status: _LedgerStatus.values.byName(json['status'] as String),
    changes: (json['changes'] as List)
        .map((item) => _Change.fromJson(item as Map<String, dynamic>))
        .toList(),
    backup: (json['backup'] as Map<String, dynamic>).map(
      (table, rows) =>
          MapEntry(table, (rows as List).cast<Map<String, dynamic>>()),
    ),
  );

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'dateCount': changes.length,
    'changes': changes.map((change) => change.toJson()).toList(),
    'backup': backup,
  };
}

_Ledger? _readLedger() {
  final file = File(_ledgerPath);
  if (!file.existsSync()) return null;
  try {
    return _Ledger.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  } on Object catch (error) {
    stderr.writeln(
      'Không đọc được $_ledgerPath: $error. Không tiếp tục để tránh chuyển '
      'trùng dữ liệu.',
    );
    exitCode = 1;
    return null;
  }
}

void _writeLedger(_Ledger ledger) {
  File(_ledgerPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(ledger.toJson()),
    flush: true,
  );
}

bool _verify(List<_Change> changes, _Rows data) {
  final rowsByKey = <(String, String), Map<String, dynamic>>{};
  for (final entry in data.entries) {
    for (final row in entry.value) {
      rowsByKey[(entry.key, row['id'] as String)] = row;
    }
  }
  for (final change in changes) {
    final row = rowsByKey[(change.table, change.rowId)];
    if (row == null || _parse(row[change.column]) != change.to) {
      return false;
    }
  }
  return true;
}

// --- Phụ trợ ----------------------------------------------------------------

DateTime _toSolar(DateTime lunar, {bool leap = false}) =>
    LunarCalendar.lunarDateTimeToSolar(lunar, isLeap: leap);

DateTime? _parse(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

String _fmt(DateTime date) => date.toIso8601String().substring(0, 10);

class _Options {
  final String email;
  final String password;
  final Set<String> leap;
  final Set<String> noLeap;
  final bool yes;
  final bool force;

  _Options(
    this.email,
    this.password,
    this.leap,
    this.noLeap,
    this.yes,
    this.force,
  );

  static _Options? parse(List<String> args) {
    String? valueOf(String name) => args
        .firstWhere((a) => a.startsWith('--$name='), orElse: () => '')
        .split('=')
        .skip(1)
        .join('=')
        .nullIfEmpty;

    Set<String> codesOf(String name) =>
        (valueOf(name) ?? '').split(',').map((e) => e.trim()).toSet()
          ..removeWhere((e) => e.isEmpty);

    final email = valueOf('email') ?? Platform.environment['DO_X_EMAIL'];
    final password =
        valueOf('password') ?? Platform.environment['DO_X_PASSWORD'];
    if (email == null || password == null) {
      stderr.writeln(
        'Thiếu tài khoản. Dùng --email=... --password=... hoặc đặt biến môi '
        'trường DO_X_EMAIL / DO_X_PASSWORD.',
      );
      exitCode = 1;
      return null;
    }
    return _Options(
      email,
      password,
      codesOf('leap'),
      codesOf('no-leap'),
      args.contains('--yes'),
      args.contains('--force'),
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
