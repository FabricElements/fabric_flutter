import 'package:ansicolor/ansicolor.dart';

/// Use this class to print colored text in the console
/// Example:
/// ```dart
/// print(PrintColor.info('This is an info message'));
/// print(PrintColor.success('This is a success message'));
/// print(PrintColor.warning('This is a warning message'));
/// print(PrintColor.error('This is an error message'));
/// ```
class PrintColor {
  static AnsiPen info = AnsiPen()..blue(bold: true);
  static AnsiPen success = AnsiPen()..green(bold: true);
  static AnsiPen warning = AnsiPen()..yellow(bold: true);
  static AnsiPen error = AnsiPen()..red(bold: true);
}
