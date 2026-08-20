import 'package:intl/intl.dart';

/// Creates shared number and date formatters used across the app.
///
/// Centralizing these format factories keeps display formatting consistent and
/// makes it easier to update locale defaults in one place.
class FormatData {
  /// Creates a [FormatData] helper instance.
  FormatData();

  /// Caches formatters keyed by their arguments so hot paths (data tables,
  /// filter labels, currency cells) reuse a single instance instead of
  /// constructing a new [NumberFormat]/[DateFormat] on every call.
  ///
  /// `intl` formatters are safe to reuse for repeated `format` calls, so the
  /// cached instances behave identically to freshly built ones.
  static final Map<String, NumberFormat> _numberFormatCache = {};
  static final Map<String, DateFormat> _dateFormatCache = {};

  /// Returns a decimal formatter with two fractional digits.
  ///
  /// Use this for general numeric values that should always display a fixed
  /// precision, such as measurements or calculated totals.
  static NumberFormat numberFormat({String locale = 'en_US'}) =>
      _numberFormatCache.putIfAbsent(
        'number|$locale',
        () =>
            NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2),
      );

  /// Returns an integer-style formatter without decimal places.
  ///
  /// This is useful when values should remain grouped for readability but must
  /// not show trailing fractional zeros.
  static NumberFormat numberClearFormat({String locale = 'en_US'}) =>
      _numberFormatCache.putIfAbsent(
        'numberClear|$locale',
        () => NumberFormat('#,###', locale),
      );

  /// Returns a locale-aware currency formatter.
  ///
  /// Override [symbol] when a screen needs a specific currency marker instead
  /// of the locale default.
  static NumberFormat currencyFormat({
    String locale = 'en_US',
    String symbol = '\$',
  }) => _numberFormatCache.putIfAbsent(
    'currency|$locale|$symbol',
    () => NumberFormat.currency(locale: locale, symbol: symbol),
  );

  /// Returns a percentage formatter using the locale default precision.
  static NumberFormat percentFormat({String locale = 'en_US'}) =>
      _numberFormatCache.putIfAbsent(
        'percent|$locale',
        () => NumberFormat.percentPattern(locale),
      );

  /// Returns a percentage formatter with two decimal places.
  ///
  /// This is helpful for analytics or finance views where whole-number percent
  /// rounding would hide meaningful differences.
  static NumberFormat decimalPercentFormat({String locale = 'en_US'}) =>
      _numberFormatCache.putIfAbsent(
        'decimalPercent|$locale',
        () => NumberFormat.decimalPercentPattern(
          decimalDigits: 2,
          locale: locale,
        ),
      );

  /// Returns a long, locale-aware calendar date formatter.
  static DateFormat formatDate({String locale = 'en_US'}) => _dateFormatCache
      .putIfAbsent('date|$locale', () => DateFormat.yMMMMd(locale));

  /// Returns a compact month/day/year date formatter.
  ///
  /// This fixed pattern is useful where space is limited or a short numeric
  /// date is required regardless of the locale's long-form convention.
  static DateFormat formatDateShort({String locale = 'en_US'}) =>
      _dateFormatCache.putIfAbsent(
        'dateShort|$locale',
        () => DateFormat('MM/dd/yyyy'),
      );

  /// Returns a formatter for a long date combined with local time.
  static DateFormat formatDateTime({String locale = 'en_US'}) =>
      _dateFormatCache.putIfAbsent(
        'dateTime|$locale',
        () => DateFormat.yMMMMd(locale).add_jm(),
      );

  /// Returns a locale-aware formatter for times only.
  static DateFormat formatHour({String locale = 'en_US'}) =>
      _dateFormatCache.putIfAbsent('hour|$locale', () => DateFormat.jm(locale));

  /// Returns a human-readable size string for a byte count.
  ///
  /// The value is scaled to the largest unit that keeps the number below 1024
  /// (`B`, `KB`, `MB`, `GB`, `TB`) and rounded to [fractionDigits] decimals, with
  /// trailing zeros trimmed so whole values read as `4 KB` rather than `4.0 KB`.
  /// A non-positive [bytes] returns `0 B`.
  static String formatBytes(int bytes, {int fractionDigits = 1}) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final text = unit == 0
        ? bytes.toString()
        : size
              .toStringAsFixed(fractionDigits)
              .replaceFirst(RegExp(r'\.?0+$'), '');
    return '$text ${units[unit]}';
  }
}
