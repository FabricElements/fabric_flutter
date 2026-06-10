import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../serialized/user_data.dart';
import '../state/state_users.dart';

/// Displays a searchable user dropdown backed by [StateUsers].
///
/// Converts serialized user records into [ButtonOptions] for [InputData],
/// including avatars and alternate search text. Because it implements
/// [PreferredSizeWidget], it can be placed directly in an [AppBar] or another
/// toolbar layout that expects a stable height.
class UsersDropdown extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a [UsersDropdown] that reads user choices from the nearest provider.
  ///
  /// Uses [uid] to preselect an item when available, and uses [prefix] to build
  /// avatar URLs for users whose image paths are relative.
  const UsersDropdown({
    super.key,
    this.onChanged,
    this.uid,
    this.label,
    this.icon,
    this.showTrailing = false,
    this.padding = EdgeInsets.zero,
    this.prefix,
  });

  /// Receives the selected [UserData] when the dropdown value changes.
  ///
  /// Remains `null` when selection changes do not need to notify parent
  /// widgets.
  final ValueChanged<UserData>? onChanged;

  /// Stores the identifier for the currently selected user.
  ///
  /// Passes the value through to [InputData] so the dropdown can restore a
  /// previously chosen record.
  final String? uid;

  /// Stores the localization key used for the field label.
  ///
  /// Falls back to the default search label when the value is `null`.
  final String? label;

  /// Stores the leading icon shown beside the search field.
  ///
  /// Falls back to [Icons.search] when no custom [IconData] is provided.
  final IconData? icon;

  /// Stores whether trailing UI should be shown by downstream widgets.
  ///
  /// Keeps the existing [InputData] configuration surface available even when
  /// the current dropdown layout does not read the value directly.
  final bool showTrailing;

  /// Stores the outer padding around the dropdown.
  ///
  /// Helps align the widget with surrounding toolbar or form content.
  final EdgeInsetsGeometry padding;

  /// Stores the base path used to resolve relative avatar image URLs.
  ///
  /// Prefixes each non-`null` avatar filename before it is passed to
  /// [UserAvatar].
  final String? prefix;

  /// Reports the preferred size for [PreferredSizeWidget] consumers.
  ///
  /// Adds extra vertical space so the dropdown fits comfortably in toolbar
  /// layouts.
  @override
  Size get preferredSize => const Size(double.maxFinite, kToolbarHeight + 16);

  /// Builds the dropdown from the current [StateUsers] provider contents.
  ///
  /// Returns a fixed-height placeholder when no users are loaded so toolbar
  /// layouts remain stable while asynchronous state is still resolving.
  @override
  Widget build(BuildContext context) {
    SearchController searchController = SearchController();
    final locales = AppLocalizations.of(context);
    final state = Provider.of<StateUsers>(context);
    List<ButtonOptions> items = List.generate(state.serialized.length, (index) {
      final item = state.serialized[index];
      String labelAlt = '';
      if (item.username != null) {
        labelAlt += item.username!;
      }
      if (item.name.isNotEmpty) {
        labelAlt += ' ${item.name}';
      }
      if (item.email != null) {
        labelAlt += ' ${item.email!}';
      }
      if (item.phone != null) {
        labelAlt += ' ${item.phone!}';
      }
      final nameForTitle =
          (item.firstName != null && item.lastName != null
              ? item.name
              : null) ??
          item.firstName ??
          item.lastName ??
          item.username ??
          item.phone ??
          item.email ??
          item.id ??
          locales.get('label--user');
      return ButtonOptions(
        id: item.id,
        value: item,
        label: nameForTitle,
        labelAlt: labelAlt,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: UserAvatar(
            avatar: prefix != null && item.avatar != null
                ? '$prefix/${item.avatar}'
                : null,
            name: item.name,
            firstName: item.firstName,
            lastName: item.lastName,
            presence: item.presence,
          ),
        ),
      );
    });
    if (items.isEmpty) {
      return const SizedBox(height: kToolbarHeight);
    }
    return Container(
      constraints: BoxConstraints(minHeight: kToolbarHeight),
      padding: padding,
      child: InputData(
        searchController: searchController,
        key: const Key('users-dropdown'),
        label: locales.get(label ?? 'label--search'),
        prefixIcon: Icon(icon ?? Icons.search),
        value: uid,
        options: items,
        type: InputDataType.dropdown,
        onChanged: (value) async {
          if (value == null) return;
          if (onChanged != null) onChanged!(value);
        },
      ),
    );
  }
}
