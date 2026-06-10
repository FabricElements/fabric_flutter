import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../serialized/user_data.dart';
import '../state/state_users.dart';

/// Displays a searchable dropdown for selecting a user from [StateUsers].
///
/// The widget converts serialized user records into [ButtonOptions] consumed by
/// [InputData], including avatars and extra searchable text. Because it also
/// implements [PreferredSizeWidget], it can be dropped directly into an [AppBar]
/// or other toolbar-like layout that expects a predictable height.
///
/// Shows user name, image and optional status chip and reports selection via
/// [onChanged]. Implements [PreferredSizeWidget] to be used in an [AppBar].
class UsersDropdown extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a [UsersDropdown] that reads user choices from the nearest provider.
  ///
  /// The optional [uid] preselects a user, while [prefix] can prepend a media
  /// base path before avatar filenames are resolved.
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

  /// Receives the selected [UserData] after the dropdown value changes.
  ///
  /// Keep callback logic in a block body when further customization is added so
  /// value propagation stays easy to extend alongside [InputData].
  final ValueChanged<UserData>? onChanged;

  /// Identifies the currently selected user value.
  final String? uid;

  /// Overrides the localized field label shown by [InputData].
  final String? label;

  /// Overrides the leading icon displayed beside the search field.
  final IconData? icon;

  /// Indicates whether trailing UI should be shown by downstream input widgets.
  final bool showTrailing;

  /// Adds outer padding so the dropdown can align with surrounding toolbar content.
  final EdgeInsetsGeometry padding;

  /// Prepends a base path used to resolve relative avatar image URLs.
  final String? prefix;

  /// Reports the preferred toolbar size for [PreferredSizeWidget] consumers.
  @override
  Size get preferredSize => const Size(double.maxFinite, kToolbarHeight + 16);

  /// Builds the dropdown from the current [StateUsers] provider contents.
  ///
  /// Empty user collections collapse to a fixed-height placeholder so app bars
  /// remain stable while asynchronous user data is still loading.
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
