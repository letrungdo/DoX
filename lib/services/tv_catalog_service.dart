import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/tv_country.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';

/// The `iptv-org` catalogue: which countries have a playlist.
///
/// One small JSON file from <https://github.com/iptv-org/api>, cached for a
/// week — the catalogue changes when a country is added, which is rare, and a
/// stale copy still points at the right playlist.
class _TvCatalogService {
  static const countriesUrl = '${Envs.tvApiUrl}/api/countries.json';

  static const cacheTtl = Duration(days: 7);

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
    ),
  );

  List<TvCountry>? _countries;

  /// Every country of the catalogue, sorted by name, Vietnam first — the app
  /// is Vietnamese, so the country most likely wanted is the one on top.
  ///
  /// Never throws: a catalogue that cannot be reached leaves the picker with
  /// the one country the page can always show.
  Future<List<TvCountry>> getCountries() async {
    final inMemory = _countries;
    if (inMemory != null) return inMemory;

    final stored = _read(
      storageService.getTvCountries(),
      storageService.getTvCountriesSavedAt(),
    );
    if (stored != null) {
      final countries = parseCountries(stored);
      if (countries.isNotEmpty) return _countries = countries;
    }

    try {
      final response = await _dio.get<String>(countriesUrl);
      final body = response.data ?? '';
      final countries = parseCountries(body);
      if (countries.isEmpty) throw const FormatException('Empty country list');
      await storageService.setTvCountries(body);
      return _countries = countries;
    } catch (e, st) {
      logger.e('TvCatalogService countries failed', error: e, stackTrace: st);
      final expired = storageService.getTvCountries();
      final countries = expired == null
          ? <TvCountry>[]
          : parseCountries(expired);
      return _countries = countries.isEmpty
          ? const [TvCountry.vietnam]
          : countries;
    }
  }

  /// [raw] while it is still fresh enough to serve.
  String? _read(String? raw, DateTime? savedAt) {
    if (raw == null || raw.isEmpty || savedAt == null) return null;
    if (DateTime.now().difference(savedAt) > cacheTtl) return null;
    return raw;
  }

  /// Turns `countries.json` into the picker's rows.
  ///
  /// Public so the catalogue can be tested without a network round trip.
  List<TvCountry> parseCountries(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return [];
    final countries =
        [
              for (final entry in decoded)
                if (entry is Map<String, dynamic>) TvCountry.fromJson(entry),
            ]
            .where(
              (country) => country.code.isNotEmpty && country.name.isNotEmpty,
            )
            .toList();

    countries.sort((a, b) {
      // Vietnam on top; the rest alphabetically, as the catalogue publishes
      // them in no particular order.
      if (a.code == TvCountry.vietnam.code) return -1;
      if (b.code == TvCountry.vietnam.code) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return countries;
  }
}

final tvCatalogService = _TvCatalogService();
