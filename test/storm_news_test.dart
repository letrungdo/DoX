import 'package:do_x/model/news/storm_news.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  bool active = true,
  String? summaryVi = 'Bão số 5 đang tiến vào vịnh Bắc Bộ.',
  Duration age = Duration.zero,
}) {
  final now = DateTime.now().toUtc();
  return {
    'id': 1,
    'date': now.toIso8601String().substring(0, 10),
    'active': active,
    'name_vi': 'Bão số 5 (Kajiki)',
    'name_en': 'Typhoon Kajiki',
    'severity': 'warning',
    'headline_vi': 'Gió mạnh cấp 12',
    'headline_en': 'Winds at 118 km/h',
    'summary_vi': summaryVi,
    'summary_en': 'Storm No. 5 is closing on the Gulf of Tonkin.',
    'advice_vi': 'Người dân ven biển nên vào bờ trước tối nay.',
    'advice_en': 'Coastal residents should come ashore before tonight.',
    'highlights': [
      {
        'title_vi': 'Đổ bộ chiều mai',
        'title_en': 'Landfall tomorrow afternoon',
        'detail_vi': 'Dự báo vào đất liền Quảng Ninh - Hải Phòng.',
        'detail_en': 'Forecast to hit Quang Ninh - Hai Phong.',
        'source_index': 0,
      },
    ],
    'sources': [
      {
        'title': 'Tin bão',
        'url': 'https://vnexpress.net/a',
        'source': 'VnExpress',
      },
    ],
    'updated_at': now.subtract(age).toIso8601String(),
  };
}

void main() {
  test('a live bulletin rebuilt just now is shown', () {
    final news = StormNews.fromJson(_json());

    expect(news.shouldShow, isTrue);
    expect(news.severity, StormSeverity.warning);
    expect(news.name('vi'), 'Bão số 5 (Kajiki)');
    expect(news.name('en'), 'Typhoon Kajiki');
  });

  test('no storm means no card', () {
    final news = StormNews.fromJson(_json(active: false, summaryVi: null));

    expect(news.shouldShow, isFalse);
  });

  test('a bulletin nobody has refreshed for half a day is dropped', () {
    final news = StormNews.fromJson(_json(age: const Duration(hours: 13)));

    expect(news.isCurrent, isFalse);
    expect(news.shouldShow, isFalse);
  });

  test('an active row with no text to show is treated as no storm', () {
    final news = StormNews.fromJson(_json(summaryVi: ''));

    expect(news.shouldShow, isFalse);
  });

  test('an unknown severity falls back to the mildest one', () {
    final news = StormNews.fromJson({..._json(), 'severity': 'apocalypse'});

    expect(news.severity, StormSeverity.watch);
  });

  test('a highlight resolves the article it was drawn from', () {
    final news = StormNews.fromJson(_json());

    expect(news.sourceOf(news.highlights.first)?.source, 'VnExpress');
  });
}
