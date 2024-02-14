import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ProviderHelper {
  /// Detects if a provider is defined in the context
  static bool isProviderDefined<T>(BuildContext? context) {
    if (context == null) {
      return false;
    }
    try {
      Provider.of<T>(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }
}
