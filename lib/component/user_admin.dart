import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../helper/user_roles.dart';
import '../serialized/user_data.dart';
import '../state/state_alert.dart';
import 'user_add_update.dart';
import 'user_avatar.dart';

/// Invite and manage Users and their roles
/// [loader] Widget displayed when a process is in progress
/// [roles] Replaces default roles with your custom roles
class UserAdmin extends StatefulWidget {
  const UserAdmin({
    Key? key,
    this.empty,
    this.loader,
    this.roles = const ['user', 'admin'],
    this.primary = false,
    this.group,
    this.groupId,
    this.appBar,
    this.maxWidth = 900,
    this.disabled = false,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    required this.uid,
    required this.getUsers,
    this.role = true,
    this.email = true,
    this.phone = false,
    this.username = false,
    this.name = false,
    this.emailUpdate = false,
    this.phoneUpdate = false,
    this.usernameUpdate = false,
    this.nameUpdate = false,
    this.roleUpdate = true,
    this.password = false,
  }) : super(key: key);
  final Widget? empty;
  final Widget? loader;
  final List<String> roles;
  final bool primary;
  final bool disabled;
  final Function(UserData data, {String? group, String? groupId}) onAdd;
  final Function(UserData data, {String? group, String? groupId}) onRemove;
  final Function(UserData data, {String? group, String? groupId}) onUpdate;
  final Future<List<Map<String, dynamic>>> Function(
      {String? group, String? groupId}) getUsers;

  /// Current user UID
  final dynamic uid;

  /// Firestore collection
  final String? group;

  /// Firestore Document id
  final String? groupId;
  final PreferredSizeWidget? appBar;
  final double maxWidth;
  final bool password;
  final bool role;
  final bool email;
  final bool phone;
  final bool username;
  final bool name;
  final bool emailUpdate;
  final bool phoneUpdate;
  final bool usernameUpdate;
  final bool nameUpdate;
  final bool roleUpdate;

  @override
  State<UserAdmin> createState() => _UserAdminState();
}

class _UserAdminState extends State<UserAdmin> {
  late List<Map<String, dynamic>> users;
  int? totalItems;

  void getUsers() async {
    try {
      users = await widget.getUsers(
        group: widget.group,
        groupId: widget.groupId,
      );
      if (mounted) setState(() {});
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    totalItems = 0;
    users = [];
    getUsers();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    AppLocalizations locales = AppLocalizations.of(context)!;
    if (widget.group != null || widget.groupId != null) {
      assert(widget.group != null && widget.groupId != null,
          'collection, document and documentData can\'t be null when including one of them.');
    }
    bool fromCollection = widget.group != null && widget.groupId != null;
    Widget space = Container(width: 16);
    final alert = Provider.of<StateAlert>(context, listen: false);

    /// Deletes the related user listed user, the documentId is the users uid
    removeUser(UserData data) async {
      alert.show(AlertData(
        clear: true,
        title: locales.get(
          'label--confirm-are-you-sure-remove-label',
          {
            'label':
                '${locales.get('label--user').toLowerCase()}: ${data.firstName ?? ''} ${data.lastName ?? ''}'
          },
        ),
        action: ButtonOptions(onTap: () async {
          await widget.onRemove(data,
              group: widget.group, groupId: widget.groupId);
          getUsers();
          if (mounted) setState(() {});
          // Type indicates the data field to use in the function, admin level or collection.
          alert.show(AlertData(
            clear: true,
            brightness: Brightness.dark,
            body: locales.get('alert--user-removed'),
            type: AlertType.success,
            duration: 3,
          ));
        }),
        type: AlertType.warning,
      ));
    }

    late Widget content;

    if (users.isEmpty) {
      content = widget.empty ?? Container();
    }

    content = Flex(
      direction: Axis.vertical,
      children: List.generate(users.length, (index) {
        final userData = users[index];
        UserData user = UserData.fromJson(userData);
        bool sameUser = widget.uid == user.id;
        // Don't allow a user to change anything about itself on the 'admin' view
        bool canUpdateUser = !sameUser;
        if (widget.disabled) canUpdateUser = false;
        user.role = user.role;
        if (fromCollection) {
          user.role = UserRoles.roleFromData(
            compareData: userData,
            group: widget.group,
            groupId: widget.groupId,
            clean: true, // Use clean: true to reduce the role locales
          );
        }
        List<Widget> trailing = [];
        if (canUpdateUser) {
          trailing.addAll([
            IconButton(
              onPressed: () async {
                showDialog<void>(
                  useRootNavigator: false,
                  barrierColor: Colors.transparent,
                  context: context,
                  builder: (context) => UserAddUpdate(
                    role: widget.roleUpdate,
                    roles: widget.roles,
                    onConfirm: widget.onUpdate,
                    email: widget.emailUpdate,
                    phone: widget.phoneUpdate,
                    username: widget.usernameUpdate,
                    name: widget.nameUpdate,
                    onChanged: getUsers,
                    user: user,
                    group: widget.group,
                    groupId: widget.groupId,
                  ),
                );
              },
              icon: Icon(
                Icons.edit,
                color: theme.colorScheme.primary,
              ),
            ),
            space,
            IconButton(
              onPressed: () async {
                try {
                  await removeUser(user);
                } on FirebaseFunctionsException catch (error) {
                  alert.show(AlertData(
                    clear: true,
                    brightness: Brightness.dark,
                    body: error.message ?? error.details['message'],
                    type: AlertType.critical,
                  ));
                } catch (error) {
                  alert.show(AlertData(
                    clear: true,
                    brightness: Brightness.dark,
                    body: error.toString(),
                    type: AlertType.critical,
                  ));
                }
              },
              icon: const Icon(
                Icons.person_remove,
                color: Colors.deepOrange,
              ),
            ),
          ]);
        }

        /// TODO add edit action
        List<Widget> roleChips = [
          Chip(
            padding: EdgeInsets.zero,
            label: Text(locales.get('label--${user.role}')),
          ),
        ];
        String name = user.name.isNotEmpty ? user.name : '';
        if (user.phone != null) {
          roleChips.add(Chip(
            avatar: Icon(Icons.phone, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: Text(user.phone!),
          ));
        }
        if (user.email != null) {
          roleChips.add(Chip(
            avatar: Icon(Icons.email, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: Text(user.email!),
          ));
        }
        if (user.username != null && user.username!.isNotEmpty) {
          roleChips.add(Chip(
            avatar: Icon(Icons.alternate_email, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: Text(user.username!),
          ));
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: ListTile(
              isThreeLine: true,
              leading: UserAvatar(
                avatar: user.avatar,
                name: user.name,
                firstName: user.firstName,
                lastName: user.lastName,
                presence: user.presence,
              ),
              title: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(name, style: textTheme.subtitle1),
              ),
              subtitle: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: roleChips,
              ),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: trailing,
              ),
            ),
          ),
        );
      }),
    );

    Widget userAddWidget = UserAddUpdate(
      roles: widget.roles,
      onConfirm: widget.onAdd,
      email: widget.email,
      phone: widget.phone,
      username: widget.username,
      name: widget.name,
      onChanged: getUsers,
      role: widget.role,
      password: widget.password,
      group: widget.group,
      groupId: widget.groupId,
    );

    if (widget.primary) {
      return Scaffold(
        primary: widget.primary,
        appBar: widget.appBar ??
            (widget.primary
                ? AppBar(title: Text(locales.get('label--users')))
                : null),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: widget.disabled
            ? null
            : FloatingActionButton.extended(
                icon: const Icon(Icons.person_add),
                label: Text(locales.get('label--add-label', {
                  'label': locales.get('label--user'),
                }).toUpperCase()),
                onPressed: () {
                  showDialog<void>(
                    // barrierColor: Colors.black12,
                    context: context,
                    builder: (context) => userAddWidget,
                  );
                },
              ),
        body: SingleChildScrollView(
          child: content,
        ),
      );
    }

    List<Widget> items = [
      content,
    ];
    if (!widget.disabled) {
      items.addAll([
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.center,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: Text(locales.get('label--add-label', {
              'label': locales.get('label--user'),
            }).toUpperCase()),
            onPressed: () {
              showDialog<void>(
                barrierColor: Colors.black12,
                context: context,
                builder: (context) => userAddWidget,
              );
            },
          ),
        ),
      ]);
    }

    return Flex(
      direction: Axis.vertical,
      children: items,
    );
  }
}
