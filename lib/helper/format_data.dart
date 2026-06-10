import 'package:intl/intl.dart';

/// Creates shared number and date formatters used across the app.
///
/// Centralizing these format factories keeps display formatting consistent and
/// makes it easier to update locale defaults in one place.
class FormatData {
  /// Creates a [FormatData] helper instance.
  FormatData();

  /// Returns a decimal formatter with two fractional digits.
  ///
  /// Use this for general numeric values that should always display a fixed
  /// precision, such as measurements or calculated totals.
  static NumberFormat numberFormat({String locale = 'en_US'}) =>
      NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);

  /// Returns an integer-style formatter without decimal places.
  ///
  /// This is useful when values should remain grouped for readability but must
  /// not show trailing fractional zeros.
  static NumberFormat numberClearFormat({String locale = 'en_US'}) =>
      NumberFormat('#,###', locale);

  /// Returns a locale-aware currency formatter.
  ///
  /// Override [symbol] when a screen needs a specific currency marker instead
  /// of the locale default.
  static NumberFormat currencyFormat({
    String locale = 'en_US',
    String symbol = '\$',
  }) =>
      NumberFormat.currency(locale: locale, symbol: symbol);

  /// Returns a percentage formatter using the locale default precision.
  static NumberFormat percentFormat({String locale = 'en_US'}) =>
      NumberFormat.percentPattern(locale);

  /// Returns a percentage formatter with two decimal places.
  ///
  /// This is helpful for analytics or finance views where whole-number percent
  /// rounding would hide meaningful differences.
  static NumberFormat decimalPercentFormat({String locale = 'en_US'}) =>
      NumberFormat.decimalPercentPattern(decimalDigits: 2, locale: locale);

  // static NumberFormat decimalPercentFormat({String locale = 'en_US'}) =>
  //     new NumberFormat('#%', locale);

  /// Returns a long, locale-aware calendar date formatter.
  static DateFormat formatDate({String locale = 'en_US'}) =>
      DateFormat.yMMMMd(locale);

  /// Returns a compact month/day/year date formatter.
  ///
  /// This fixed pattern is useful where space is limited or a short numeric
  /// date is required regardless of the locale's long-form convention.
  static DateFormat formatDateShort({String locale = 'en_US'}) =>
      DateFormat('MM/dd/yyyy');

  /// Returns a formatter for a long date combined with local time.
  static DateFormat formatDateTime({String locale = 'en_US'}) =>
      DateFormat.yMMMMd(locale).add_jm();

  /// Returns a locale-aware formatter for times only.
  static DateFormat formatHour({String locale = 'en_US'}) =>
      DateFormat.jm(locale);
}
