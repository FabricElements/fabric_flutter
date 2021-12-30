import 'package:flutter_web_plugins/flutter_web_plugins.dart';

bool _isUrlStrategySet = false;

void configureApp() {
  if (!_isUrlStrategySet) {
    setUrlStrategy(PathUrlStrategy());
    _isUrlStrategySet = true;
  }
}
