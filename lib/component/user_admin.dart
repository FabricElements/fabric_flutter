import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/user_roles.dart';
import '../serialized/add_user_data.dart';
import '../serialized/user_data.dart';
import '../state/state_alert.dart';
import 'user_add.dart';
import 'user_avatar.dart';
import 'user_role_update.dart';

/// Invite and manage Users and their roles
/// [loader] Widget displayed when a process is in progress
/// [roles] Replaces default roles with your custom roles
class UserAdmin extends StatefulWidget {
  const UserAdmin({
    Key? key,
    this.empty,
    this.loader,
    this.roles,
    this.primary = false,
    this.collection,
    this.data,
    this.id,
    this.appBar,
    this.maxWidth = 900,
    this.disabled = false,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    required this.uid,
    required this.getUsers,
    this.email = true,
    this.phone = true,
    this.username = true,
    this.name = true,
  }) : super(key: key);
  final Widget? empty;
  final Widget? loader;
  final List<String>? roles;
  final bool primary;
  final bool disabled;
  final Function(AddUserData data) onAdd;
  final Function(Map<String, dynamic> options) onRemove;
  final Function(Map<String, dynamic> options) onUpdate;
  final Future<List<Map<String, dynamic>>> Function() getUsers;

  /// Current user UID
  final dynamic uid;

  /// Firestore Document [id]
  final String? id;

  /// Firestore [collection]
  final String? collection;

  /// Firestore [data]
  final Map<String, dynamic>? data;
  final PreferredSizeWidget? appBar;
  final double maxWidth;
  final bool email;
  final bool phone;
  final bool username;
  final bool name;

  @override
  State<UserAdmin> createState() => _UserAdminState();
}

class _UserAdminState extends State<UserAdmin> {
  late List<Map<String, dynamic>> users;
  int? totalItems;

  void getUsers() async {
    try {
      users = await widget.getUsers();
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
    String? id = widget.id;
    String? collection = widget.collection;
    Map<String, dynamic>? documentData = widget.data;
    if (collection != null || id != null || documentData != null) {
      assert(collection != null && id != null,
          'collection, document and documentData can\'t be null when including one of them.');
    }
    bool fromCollection = collection != null && id != null;
    Widget space = Container(width: 16);
    Map<String, dynamic> inviteMetadata = {};
    final alert = Provider.of<StateAlert>(context, listen: false);
    Map<String, dynamic> removeOptions = {};
    inviteMetadata = {
      'admin': true,
    };
    if (fromCollection) {
      inviteMetadata = {
        'collection': collection,
        'document': id,
      };
    }
    removeOptions.addAll(inviteMetadata);

    /// Deletes the related user listed user, the documentId is the users uid
    _removeUser(String documentId) async {
      removeOptions.addAll({
        'uid': documentId,
      });
      widget.onRemove(removeOptions);
      // Type indicates the data field to use in the function, admin level or collection.
      alert.show(AlertData(
        body: locales.get('alert--user-removed'),
        type: AlertType.success,
        duration: 3,
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
        final user = UserData.fromJson(userData);
        bool sameUser = widget.uid == user.id;
        // Don't allow a user to change anything about itself on the 'admin' view
        bool canUpdateUser = !sameUser;
        if (widget.disabled) canUpdateUser = false;
        Color statusColor = Colors.grey.shade600;
        switch (user.presence) {
          case 'active':
            statusColor = Colors.green;
            break;
          case 'inactive':
            statusColor = Colors.deepOrange;
        }
        if (sameUser) {
          statusColor = Colors.green;
        }
        String roleFinal = user.role;
        if (id != null) {
          roleFinal = UserRoles.roleFromData(
            compareData: userData,
            level: collection,
            levelId: id,
            clean: true, // Use clean: true to reduce the role locales
          );
        }
        List<Widget> trailing = [];
        trailing.add(space);
        trailing.add(
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        );
        List<Widget> roleChips = [
          Chip(
            padding: EdgeInsets.zero,
            label: Text(locales.get('label--$roleFinal')),
          ),
        ];
        String name =
            user.name.isNotEmpty ? user.name : locales.get('label--unknown');
        if (user.phone.isNotEmpty) {
          roleChips.add(Chip(
            avatar: Icon(Icons.phone, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: Text(user.phone),
          ));
        } else if (user.email.isNotEmpty) {
          roleChips.add(Chip(
            avatar: Icon(Icons.email, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: Text(user.email),
          ));
        }

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: Wrap(
              children: <Widget>[
                AbsorbPointer(
                  absorbing: !canUpdateUser,
                  child: Dismissible(
                    key: Key(user.id!),
                    background: Container(
                      color: Colors.deepOrangeAccent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          const Icon(Icons.delete, color: Colors.white),
                          space,
                          Text(
                            locales.get('label--remove'),
                            style: const TextStyle(color: Colors.white),
                          ),
                          space,
                        ],
                      ),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (DismissDirection direction) async {
                      bool response = false;
                      try {
                        if (direction == DismissDirection.endToStart) {
                          await _removeUser(user.id!);
                          response = true;
                          if (mounted) setState(() {});
                        }
                      } on FirebaseFunctionsException catch (error) {
                        alert.show(AlertData(
                          body: error.message ?? error.details['message'],
                          type: AlertType.critical,
                        ));
                      } catch (error) {
                        alert.show(AlertData(
                          body: error.toString(),
                          type: AlertType.critical,
                        ));
                      }
                      return response;
                    },
                    child: ListTile(
                      onTap: () async {
                        showDialog<void>(
                          barrierColor: Colors.black12,
                          context: context,
                          builder: (context) => UserRoleUpdate(
                            data: inviteMetadata,
                            roles: widget.roles,
                            uid: user.id!,
                            name: name,
                            onUpdate: widget.onUpdate,
                          ),
                        );
                      },
                      isThreeLine: true,
                      leading: UserAvatar(
                        avatar: user.avatar,
                        name: user.name.isNotEmpty
                            ? user.name
                            : locales.get('label--unknown'),
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
                ),
                const Divider(height: 0),
              ],
            ),
          ),
        );
      }),
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
                    barrierColor: Colors.black12,
                    context: context,
                    builder: (context) => UserAdd(
                      data: inviteMetadata,
                      roles: widget.roles,
                      onAdd: widget.onAdd,
                      uid: widget.uid,
                      email: widget.email,
                      phone: widget.phone,
                      username: widget.username,
                      name: widget.name,
                      onChanged: getUsers,
                    ),
                  );
                },
              ),
        body: content,
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
                builder: (context) => UserAdd(
                  data: inviteMetadata,
                  roles: widget.roles,
                  onAdd: widget.onAdd,
                  uid: widget.uid,
                  onChanged: widget.getUsers,
                ),
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
