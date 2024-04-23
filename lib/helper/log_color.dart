import 'package:ansicolor/ansicolor.dart';

/// Use this class to print colored text in the console
/// Example:
/// ```dart
/// print(LogColor.info('This is an info message'));
/// print(LogColor.success('This is a success message'));
/// print(LogColor.warning('This is a warning message'));
/// print(LogColor.error('This is an error message'));
/// ```
class LogColor {
  static AnsiPen info = AnsiPen()..blue(bold: true);
  static AnsiPen success = AnsiPen()..green(bold: true);
  static AnsiPen warning = AnsiPen()..yellow(bold: true);
  static AnsiPen error = AnsiPen()..red(bold: true);
}
