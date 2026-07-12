/// Minimal CSV helpers (RFC 4180 quoting).
library;

/// Quotes [value] for use as a single CSV field when needed: fields containing
/// commas, quotes or newlines are wrapped in double quotes with inner quotes
/// doubled. Plain values pass through unchanged.
String csvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Formats a millimetre value as metres with fixed decimals so exports don't
/// leak binary-double noise (e.g. 5.489999999999999).
String csvMetres(double mm, {int decimals = 3}) {
  return (mm / 1000).toStringAsFixed(decimals);
}
