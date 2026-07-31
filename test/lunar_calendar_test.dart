import 'package:do_x/utils/lunar_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2025 nhuận tháng 6: tháng 6 thường rồi tới tháng 6 nhuận.
  group('leap month of 2025', () {
    test('reports the leap month number', () {
      expect(LunarCalendar.leapMonthOfYear(2025), 6);
      expect(LunarCalendar.leapMonthOfYear(2024), isNull);
    });

    test('the regular sixth month', () {
      expect(LunarCalendar.lunarToSolar(8, 6, 2025), DateTime(2025, 7, 2));
    });

    test('the leap sixth month is a month later', () {
      expect(
        LunarCalendar.lunarToSolar(8, 6, 2025, isLeap: true),
        DateTime(2025, 8, 1),
      );
    });

    test('a solar day inside it reports the leap flag', () {
      final lunar = LunarCalendar.solarToLunar(1, 8, 2025);
      expect((lunar.day, lunar.month, lunar.isLeap), (8, 6, true));
    });
  });

  // Asking for a leap month that does not exist has to give the regular month.
  // It used to skip the shift that every month after the leap one needs, so it
  // answered a month early — which silently moved dates when a caller passed
  // isLeap without checking whether that month is leap at all.
  group('a leap month that does not exist falls back', () {
    test('a month after the leap one, in a leap year', () {
      expect(
        LunarCalendar.lunarToSolar(25, 8, 2025, isLeap: true),
        LunarCalendar.lunarToSolar(25, 8, 2025),
      );
    });

    test('a month before the leap one, in a leap year', () {
      expect(
        LunarCalendar.lunarToSolar(10, 3, 2025, isLeap: true),
        LunarCalendar.lunarToSolar(10, 3, 2025),
      );
    });

    test('every month of a year with no leap month at all', () {
      for (var month = 1; month <= 12; month++) {
        expect(
          LunarCalendar.lunarToSolar(5, month, 2024, isLeap: true),
          LunarCalendar.lunarToSolar(5, month, 2024),
          reason: 'tháng $month năm 2024',
        );
      }
    });
  });

  test('solar -> lunar -> solar holds outside leap months', () {
    var date = DateTime(2025, 9, 1);
    for (var i = 0; i < 120; i++) {
      final lunar = LunarCalendar.solarToLunar(date.day, date.month, date.year);
      expect(
        LunarCalendar.lunarToSolar(
          lunar.day,
          lunar.month,
          lunar.year,
          isLeap: lunar.isLeap,
        ),
        date,
      );
      date = date.add(const Duration(days: 1));
    }
  });
}
