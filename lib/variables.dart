import 'dart:io';

import 'package:flutter/foundation.dart';

/// Determines if the current application is running in a test environment.
///
/// This flag is true when the app is running in a non-web environment where
/// the 'FLUTTER_TEST' environment variable is set. This is commonly used to
/// conditionally disable certain features during test execution, such as
/// analytics tracking or Firebase interactions.
bool kIsTest = (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));
