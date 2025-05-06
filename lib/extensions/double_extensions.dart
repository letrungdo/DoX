extension DoubleNullableExtensions on double? {
  double? celsiusToFahrenheit() {
    final value = this;
    if (value == null) return null;
    return (value * 9 / 5) + 32;
  }
}
