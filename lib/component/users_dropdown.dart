import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../serialized/user_data.dart';
import '../state/state_users.dart';

/// Dropdown control for selecting an user.
///
/// Shows user name, image and optional status chip and reports selection
/// via [onChanged]. Implements [PreferredSizeWidget] to be used in AppBar.
class UsersDropdown extends StatelessWidget implements PreferredSizeWidget {
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

  /// [onChanged]
  /// Never use expression body or value won't be update correctly
  final ValueChanged<UserData>? onChanged;

  final String? uid;

  final String? label;
  final IconData? icon;
  final bool showTrailing;
  final EdgeInsetsGeometry padding;
  final String? prefix;

  @override
  Size get preferredSize => const Size(double.maxFinite, kToolbarHeight + 16);

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
