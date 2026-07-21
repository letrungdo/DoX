import 'dart:math' as math;

/// A date on the Vietnamese lunar calendar.
class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool isLeap;

  const LunarDate(this.day, this.month, this.year, this.isLeap);
}

/// Solar <-> lunar conversion using Hồ Ngọc Đức's astronomical algorithm,
/// pinned to Vietnam's timezone (UTC+7) so results match the local lunar
/// calendar (which can differ from the Chinese one).
class LunarCalendar {
  LunarCalendar._();

  /// Vietnam timezone offset in hours.
  static const double _timeZone = 7.0;

  static const _canNames = [
    'Giáp',
    'Ất',
    'Bính',
    'Đinh',
    'Mậu',
    'Kỷ',
    'Canh',
    'Tân',
    'Nhâm',
    'Quý',
  ];

  static const _chiNames = [
    'Tý',
    'Sửu',
    'Dần',
    'Mão',
    'Thìn',
    'Tỵ',
    'Ngọ',
    'Mùi',
    'Thân',
    'Dậu',
    'Tuất',
    'Hợi',
  ];

  /// Julian day number from a solar (Gregorian/Julian) date.
  static int _jdFromDate(int dd, int mm, int yy) {
    final a = ((14 - mm) / 12).floor();
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    var jd = dd +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;
    if (jd < 2299161) {
      jd = dd + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() - 32083;
    }
    return jd;
  }

  static double _newMoon(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    final dr = math.pi / 180;
    var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 = jd1 + 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) +
        0.0021 * math.sin(2 * dr * m);
    c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
    c1 = c1 - 0.0004 * math.sin(dr * 3 * mpr);
    c1 = c1 + 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
    c1 = c1 - 0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m));
    c1 = c1 - 0.0004 * math.sin(dr * (2 * f - m)) - 0.0006 * math.sin(dr * (2 * f + mpr));
    c1 = c1 + 0.0010 * math.sin(dr * (2 * f - mpr)) + 0.0005 * math.sin(dr * (2 * mpr + m));
    double deltat;
    if (t < -11) {
      deltat = 0.001 +
          0.000839 * t +
          0.0002261 * t2 -
          0.00000845 * t3 -
          0.000000081 * t * t3;
    } else {
      deltat = -0.000278 + 0.000265 * t + 0.000262 * t2;
    }
    return jd1 + c1 - deltat;
  }

  static double _sunLongitude(double jdn) {
    final t = (jdn - 2451545.0) / 36525;
    final t2 = t * t;
    final dr = math.pi / 180;
    final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
    dl = dl +
        (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) +
        0.000290 * math.sin(dr * 3 * m);
    var l = l0 + dl;
    l = l * dr;
    l = l - math.pi * 2 * (l / (math.pi * 2)).floor();
    return l;
  }

  static int _getSunLongitude(int dayNumber, double timeZone) {
    return (_sunLongitude(dayNumber - 0.5 - timeZone / 24) / math.pi * 6).floor();
  }

  static int _getNewMoonDay(int k, double timeZone) {
    return (_newMoon(k) + 0.5 + timeZone / 24).floor();
  }

  static int _getLunarMonth11(int yy, double timeZone) {
    final off = _jdFromDate(31, 12, yy) - 2415021;
    final k = (off / 29.530588853).floor();
    var nm = _getNewMoonDay(k, timeZone);
    final sunLong = _getSunLongitude(nm, timeZone);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1, timeZone);
    }
    return nm;
  }

  static int _getLeapMonthOffset(int a11, double timeZone) {
    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var last = 0;
    var i = 1;
    var arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
    do {
      last = arc;
      i++;
      arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
    } while (arc != last && i < 14);
    return i - 1;
  }

  /// Converts a solar date to the Vietnamese lunar date.
  static LunarDate solarToLunar(int dd, int mm, int yy) {
    const timeZone = _timeZone;
    final dayNumber = _jdFromDate(dd, mm, yy);
    final k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    var monthStart = _getNewMoonDay(k + 1, timeZone);
    if (monthStart > dayNumber) {
      monthStart = _getNewMoonDay(k, timeZone);
    }
    var a11 = _getLunarMonth11(yy, timeZone);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = yy;
      a11 = _getLunarMonth11(yy - 1, timeZone);
    } else {
      lunarYear = yy + 1;
      b11 = _getLunarMonth11(yy + 1, timeZone);
    }
    final lunarDay = dayNumber - monthStart + 1;
    final diff = ((monthStart - a11) / 29).floor();
    var lunarLeap = false;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final leapMonthDiff = _getLeapMonthOffset(a11, timeZone);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          lunarLeap = true;
        }
      }
    }
    if (lunarMonth > 12) {
      lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }
    return LunarDate(lunarDay, lunarMonth, lunarYear, lunarLeap);
  }

  /// Solar (Gregorian/Julian) date from a Julian day number — the inverse of
  /// [_jdFromDate]. Returns (day, month, year).
  static (int, int, int) _jdToDate(int jd) {
    int a, b, c;
    if (jd > 2299160) {
      // After 5/10/1582, Gregorian calendar.
      a = jd + 32044;
      b = ((4 * a + 3) / 146097).floor();
      c = a - ((b * 146097) / 4).floor();
    } else {
      b = 0;
      c = jd + 32082;
    }
    final d = ((4 * c + 3) / 1461).floor();
    final e = c - ((1461 * d) / 4).floor();
    final m = ((5 * e + 2) / 153).floor();
    final day = e - ((153 * m + 2) / 5).floor() + 1;
    final month = m + 3 - 12 * (m / 10).floor();
    final year = b * 100 + d - 4800 + (m / 10).floor();
    return (day, month, year);
  }

  /// Converts a Vietnamese lunar date to its solar (Gregorian) date.
  /// The inverse of [solarToLunar].
  static DateTime lunarToSolar(
    int lunarDay,
    int lunarMonth,
    int lunarYear, {
    bool isLeap = false,
  }) {
    const timeZone = _timeZone;
    int a11, b11;
    if (lunarMonth < 11) {
      a11 = _getLunarMonth11(lunarYear - 1, timeZone);
      b11 = _getLunarMonth11(lunarYear, timeZone);
    } else {
      a11 = _getLunarMonth11(lunarYear, timeZone);
      b11 = _getLunarMonth11(lunarYear + 1, timeZone);
    }
    final k = (0.5 + (a11 - 2415021.076998695) / 29.530588853).floor();
    var off = lunarMonth - 11;
    if (off < 0) off += 12;
    if (b11 - a11 > 365) {
      final leapOff = _getLeapMonthOffset(a11, timeZone);
      var leapMonth = leapOff - 2;
      if (leapMonth < 0) leapMonth += 12;
      if (isLeap && lunarMonth != leapMonth) {
        // Requested leap month doesn't exist this year; fall back to the
        // regular month rather than throwing.
      } else if (isLeap || off >= leapOff) {
        off += 1;
      }
    }
    final monthStart = _getNewMoonDay(k + off, timeZone);
    final (d, m, y) = _jdToDate(monthStart + lunarDay - 1);
    return DateTime(y, m, d);
  }

  /// Reinterprets a [DateTime] whose day/month/year are a lunar date and
  /// returns the matching solar date. Time-of-day is dropped.
  static DateTime lunarDateTimeToSolar(DateTime lunar, {bool isLeap = false}) =>
      lunarToSolar(lunar.day, lunar.month, lunar.year, isLeap: isLeap);

  /// Converts a solar [DateTime] to a lunar-valued [DateTime] (its day/month/
  /// year hold the lunar date). Time-of-day is dropped. The leap flag is not
  /// representable in a [DateTime] and is therefore lost.
  static DateTime solarToLunarDateTime(DateTime solar) {
    final l = solarToLunar(solar.day, solar.month, solar.year);
    return DateTime(l.year, l.month, l.day);
  }

  /// Number of days (29 or 30) in a given lunar month.
  static int daysInLunarMonth(int month, int year, {bool isLeap = false}) {
    // If lunar day 30 exists it round-trips to day 30 of the same month;
    // otherwise the month is short and day 30 rolls into the next month.
    final solar = lunarToSolar(30, month, year, isLeap: isLeap);
    final back = solarToLunar(solar.day, solar.month, solar.year);
    return (back.day == 30 && back.month == month) ? 30 : 29;
  }

  /// Can-Chi (sexagenary) name of a lunar year, e.g. "Giáp Thìn".
  static String canChiOfYear(int lunarYear) {
    final can = _canNames[(lunarYear + 6) % 10];
    final chi = _chiNames[(lunarYear + 8) % 12];
    return '$can $chi';
  }

  /// Can-Chi name of a solar day.
  static String canChiOfDay(int dd, int mm, int yy) {
    final jd = _jdFromDate(dd, mm, yy);
    final can = _canNames[(jd + 9) % 10];
    final chi = _chiNames[(jd + 1) % 12];
    return '$can $chi';
  }

  /// Can-Chi name of a lunar month within its year.
  static String canChiOfMonth(int lunarMonth, int lunarYear) {
    final can = _canNames[(lunarYear * 12 + lunarMonth + 3) % 10];
    final chi = _chiNames[(lunarMonth + 1) % 12];
    return '$can $chi';
  }

  /// Chi (earthly branch) index of a solar day, 0 = Tý.
  static int _dayChiIndex(int dd, int mm, int yy) {
    return (_jdFromDate(dd, mm, yy) + 1) % 12;
  }

  /// Can-Chi of the Tý (23h–1h) hour — the day's first hour pillar, derived
  /// from the day's can ("ngũ tý nguyên độn"), e.g. "Nhâm Tý".
  static String canChiOfZiHour(int dd, int mm, int yy) {
    final dayCan = (_jdFromDate(dd, mm, yy) + 9) % 10;
    return '${_canNames[(dayCan % 5) * 2]} Tý';
  }

  /// Hourly time ranges for each của the 12 earthly-branch double-hours.
  static const _hourRanges = [
    '23-1',
    '1-3',
    '3-5',
    '5-7',
    '7-9',
    '9-11',
    '11-13',
    '13-15',
    '15-17',
    '17-19',
    '19-21',
    '21-23',
  ];

  /// Auspicious double-hours (giờ hoàng đạo) grouped by the day's chi.
  /// Values are chi indices (0 = Tý).
  static const _goodHoursByDayChi = <List<int>>[
    [0, 1, 3, 6, 8, 9], // Tý
    [2, 3, 5, 8, 10, 11], // Sửu
    [0, 1, 4, 5, 7, 10], // Dần
    [0, 2, 3, 6, 7, 9], // Mão
    [2, 4, 5, 8, 9, 11], // Thìn
    [1, 4, 6, 7, 10, 11], // Tỵ
    [0, 1, 3, 6, 8, 9], // Ngọ
    [2, 3, 5, 8, 10, 11], // Mùi
    [0, 1, 4, 5, 7, 10], // Thân
    [0, 2, 3, 6, 7, 9], // Dậu
    [2, 4, 5, 8, 9, 11], // Tuất
    [1, 4, 6, 7, 10, 11], // Hợi
  ];

  /// Good (giờ hoàng đạo) hours for a solar day: each entry is
  /// "Chi (start-end h)", e.g. "Tý (23-1)".
  static List<String> goodHours(int dd, int mm, int yy) {
    final chi = _dayChiIndex(dd, mm, yy);
    return [
      for (final h in _goodHoursByDayChi[chi]) '${_chiNames[h]} (${_hourRanges[h]}h)',
    ];
  }

  /// The 12 auspicious/inauspicious day stars in cycle order.
  static const _dayStars = [
    ('Thanh Long', true),
    ('Minh Đường', true),
    ('Thiên Hình', false),
    ('Chu Tước', false),
    ('Kim Quỹ', true),
    ('Bảo Quang', true),
    ('Bạch Hổ', false),
    ('Ngọc Đường', true),
    ('Thiên Lao', false),
    ('Huyền Vũ', false),
    ('Tư Mệnh', true),
    ('Câu Trần', false),
  ];

  /// Whether a solar day is a "good day" (hoàng đạo) plus its star name.
  /// Requires the lunar month the day falls in.
  static ({bool isGood, String star}) dayQuality(
    int dd,
    int mm,
    int yy,
    int lunarMonth,
  ) {
    final baseChi = ((lunarMonth - 1) % 6) * 2;
    final dayChi = _dayChiIndex(dd, mm, yy);
    final starIndex = (dayChi - baseChi + 12) % 12;
    final star = _dayStars[starIndex];
    return (isGood: star.$2, star: star.$1);
  }

  static const _solarTerms = [
    'Xuân phân',
    'Thanh minh',
    'Cốc vũ',
    'Lập hạ',
    'Tiểu mãn',
    'Mang chủng',
    'Hạ chí',
    'Tiểu thử',
    'Đại thử',
    'Lập thu',
    'Xử thử',
    'Bạch lộ',
    'Thu phân',
    'Hàn lộ',
    'Sương giáng',
    'Lập đông',
    'Tiểu tuyết',
    'Đại tuyết',
    'Đông chí',
    'Tiểu hàn',
    'Đại hàn',
    'Lập xuân',
    'Vũ thủy',
    'Kinh trập',
  ];

  /// Solar term (tiết khí) name for a solar day.
  static String solarTerm(int dd, int mm, int yy) {
    final jd = _jdFromDate(dd, mm, yy);
    final longitude = _sunLongitude(jd - 0.5 - _timeZone / 24) / math.pi * 180;
    final index = (longitude / 15).floor() % 24;
    return _solarTerms[index < 0 ? index + 24 : index];
  }

  /// Traditional tide strength (con nước) from the lunar day. Spring tides
  /// (nước rong / triều cường) cluster around new and full moon; neap tides
  /// (nước kém) around the quarters. This is a folk almanac approximation,
  /// not a location-specific tide prediction.
  static String tideLabel(int lunarDay) {
    const spring = {30, 1, 2, 3, 15, 16, 17, 18};
    const neap = {7, 8, 9, 10, 22, 23, 24, 25};
    if (spring.contains(lunarDay)) return 'Nước rong (triều cường)';
    if (neap.contains(lunarDay)) return 'Nước kém';
    return 'Nước trung bình';
  }
}
