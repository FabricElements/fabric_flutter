import 'package:ansicolor/ansicolor.dart';

/// Provides colorized ANSI text formatting for console logging.
///
/// Use these static pens to highlight debug output in terminal sessions. Each
/// pen applies bold styling and a semantic color to help distinguish log levels
/// at a glance.
///
/// Example:
/// ```dart
/// debugPrint(LogColor.info('This is an info message'));
/// debugPrint(LogColor.success('This is a success message'));
/// debugPrint(LogColor.warning('This is a warning message'));
/// debugPrint(LogColor.error('This is an error message'));
/// ```
class LogColor {
  /// Formats text in bold blue for informational messages.
  static AnsiPen info = AnsiPen()..blue(bold: true);

  /// Formats text in bold green for success confirmations.
  static AnsiPen success = AnsiPen()..green(bold: true);

  /// Formats text in bold yellow for warnings.
  static AnsiPen warning = AnsiPen()..yellow(bold: true);

  /// Formats text in bold red for errors and failures.
  static AnsiPen error = AnsiPen()..red(bold: true);
}
