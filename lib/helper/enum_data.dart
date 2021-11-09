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
      // _label = base.toString().split(".").last;
    } catch (error) {}
    return _label;
  }

  /// Get locales from enum
  String localesFromEnum(dynamic base) {
    if (base == null) return "";
    return locales != null
        ? locales!.get("label--${stringFromEnum(base).replaceAll("_", "-").toLowerCase()}")
        : "LOCALES NOT INCLUDED";
  }
}
