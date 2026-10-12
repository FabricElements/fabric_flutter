import 'package:flutter/widgets.dart';

/// Builds an automation key for a control that is unique to its screen.
///
/// The key is `<screen>.<control>`, where the screen comes from the active
/// named route (for example `/dashboard?filters=...` becomes `dashboard`).
/// Routes can stay mounted under the active one, so the screen prefix keeps
/// the same control name from colliding across screens. Returns [control]
/// unchanged when the context has no named route; give such screens a route
/// name so their keys stay unique.
String scopedAutomationKey(BuildContext context, String control) {
  final routeName = ModalRoute.of(context)?.settings.name;
  if (routeName == null || routeName.isEmpty) return control;
  final path = Uri.tryParse(routeName)?.path ?? routeName;
  final screen = path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map((segment) => segment.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_'))
      .join('.')
      .toLowerCase();
  if (screen.isEmpty) return control;
  return '$screen.$control';
}
