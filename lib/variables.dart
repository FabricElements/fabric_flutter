import 'dart:io';

import 'package:flutter/foundation.dart';

bool kIsTest = (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));
