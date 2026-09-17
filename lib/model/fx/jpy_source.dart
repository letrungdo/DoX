/// The JPY→VND providers the news page quotes, keyed by their row in
/// `fx_rates`. The order here is the order the expanded grid shows them in.
enum JpySource {
  google('google_jpy_vnd', 'Google'),
  smile('smile_jpy_vnd', 'Smile'),
  moneyGram('moneygram_jpy_vnd', 'MoneyGram'),
  dcom('dcom_jpy_vnd', 'Dcom');

  const JpySource(this.code, this.label);

  final String code;
  final String label;

  /// Whichever provider is paying the most đồng per yen — the one question the
  /// collapsed row has to answer. Null when no provider has reported yet.
  ///
  /// A provider missing from [rates] is skipped rather than treated as zero: a
  /// source that failed to fetch should drop out of the comparison, not lose
  /// it.
  static ({JpySource source, double rate})? best(Map<String, double> rates) {
    ({JpySource source, double rate})? best;
    for (final source in JpySource.values) {
      final rate = rates[source.code];
      if (rate == null) continue;
      if (best == null || rate > best.rate) {
        best = (source: source, rate: rate);
      }
    }

    return best;
  }
}
