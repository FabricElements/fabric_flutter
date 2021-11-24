import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/foundation.dart';

/// [EnumData] provides extended support for enums
class EnumData {
  const EnumData({
    this.locales,
  });

  final AppLocalizations? locales;

  /// Get Value from enum
  String stringFromEnum(dynamic base, {bool debug = false}) {
    String _label = debug ? "unknown" : "";
    if (base == null) return _label;
    try {
      _label = describeEnum(base);
    } catch (error) {}
    return _label;
  }

  /// Get locales from enum
  String localesFromEnum(dynamic base) {
    if (base == null) return "";
    String text = stringFromEnum(base).replaceAll("_", "-");
    RegExp exp = RegExp(r'(?<=[a-z])[A-Z]');
    // Handle camelCase
    String result = text
        .replaceAllMapped(exp, (Match m) => ('-' + m.group(0)!))
        .toLowerCase();
    return locales != null
        ? locales!.get("label--$result")
        : "LOCALES NOT INCLUDED";
  }
}
