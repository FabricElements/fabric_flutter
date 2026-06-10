import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

/// Provides lightweight utilities for working with `provider`.
class ProviderHelper {
  /// Returns whether a provider of type `T` can be read from [context].
  ///
  /// This is useful in shared widgets and helpers that may be mounted in
  /// multiple parts of the tree, some of which do not register the provider.
  /// A `null` context or a missing provider both produce `false`.
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
