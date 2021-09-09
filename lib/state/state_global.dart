import 'package:flutter/cupertino.dart';

/// This is a change notifier class which keeps track of state within the widgets.
class StateGlobal extends ChangeNotifier {
  StateGlobal();

  /// [_context] app global context
  BuildContext? _context;

  set context(BuildContext? context) => _context = context;

  BuildContext? get context => _context;
}
