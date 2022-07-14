library fabric_flutter;

import 'package:intl/intl.dart';

/// [FormatData] provides helpful value formats used to display data
class FormatData {
  FormatData();

  static NumberFormat numberFormat({String locale = 'en_US'}) =>
      NumberFormat('#,###.00', locale);

  static NumberFormat numberClearFormat({String locale = 'en_US'}) =>
      NumberFormat('#,###', locale);

  static NumberFormat currencyFormat({
    String locale = 'en_US',
    String symbol = '\$',
  }) =>
      NumberFormat.currency(locale: locale, symbol: symbol);

  static NumberFormat percentFormat({String locale = 'en_US'}) =>
      NumberFormat.percentPattern(locale);

  static NumberFormat decimalPercentFormat({String locale = 'en_US'}) =>
      NumberFormat.decimalPercentPattern(decimalDigits: 2, locale: locale);

  // static NumberFormat decimalPercentFormat({String locale = 'en_US'}) =>
  //     new NumberFormat('#%', locale);

  static DateFormat formatDate({String locale = 'en_US'}) =>
      DateFormat.yMMMMd(locale);

  static DateFormat formatDateShort({String locale = 'en_US'}) =>
      DateFormat('MM/dd/yyyy');

  static DateFormat formatDateTime({String locale = 'en_US'}) =>
      DateFormat.yMMMMd(locale).add_jm();

  static DateFormat formatHour({String locale = 'en_US'}) =>
      DateFormat.jm(locale);
}
