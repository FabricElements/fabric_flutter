import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../helper/user_roles.dart';
import '../helper/user_roles_firebase.dart';
import '../serialized/user_data.dart';
import '../state/state_alert.dart';
import '../state/state_user.dart';
import '../state/state_users.dart';
import 'content_container.dart';
import 'pagination_container.dart';
import 'user_add_update.dart';
import 'user_avatar.dart';

/// Invite and manage Users and their roles
/// [loader] Widget displayed when a process is in progress
/// [roles] Replaces default roles with your custom roles
class UserAdmin extends StatelessWidget {
  const UserAdmin({
    super.key,
    this.empty,
    this.loader,
    this.roles = const ['user', 'admin'],
    this.primary = false,
    this.group,
    this.appBar,
    this.disabled = false,
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
    this.size = ContentContainerSize.medium,
    this.prefix,
  });

  final Widget? empty;
  final Widget? loader;
  final List<String> roles;
  final bool primary;
  final bool disabled;
  final String? prefix;

  /// Role groups
  final String? group;
  final PreferredSizeWidget? appBar;
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
  final ContentContainerSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final locales = AppLocalizations.of(context);
    if (group != null) {
      assert(group != null && group!.isNotEmpty, 'group can\'t be empty');
    }
    final stateUser = Provider.of<StateUser>(context, listen: false);
    final state = Provider.of<StateUsers>(context, listen: false);
    final alert = Provider.of<StateAlert>(context, listen: false);
    alert.context = context;
    // Set default limit when you will use shrinkWrap
    if (!primary) state.limitDefault = 100;
    // Catch errors
    apiError(String? e) => (e != null)
        ? alert.show(AlertData(
            title: locales.get(e),
            type: AlertType.critical,
            clear: true,
          ))
        : null;
    stateUser.onError = apiError;
    state.onError = apiError;

    /// User collection
    Query<Map<String, dynamic>> baseQuery =
        FirebaseFirestore.instance.collection('user');
    Query<Map<String, dynamic>> query = baseQuery;

    /// Order By role for global users, the role key is only available for parent users
    query = query.orderBy('name');
    bool fromCollection = group != null && group!.isNotEmpty;
    if (fromCollection) {
      query = baseQuery.orderBy('groups.$group');
    }
    state.query = query;
    state.listen();

    Widget space = Container(width: 16);

    /// Deletes the related user listed user, the documentId is the users uid
    removeUser(UserData data) {
      String? name = data.name.trim().length > 4 ? data.name : null;
      name ??= data.firstName ??
          data.username ??
          data.phone ??
          data.email ??
          data.id;
      alert.show(AlertData(
        title: locales.get(
          'label--confirm-are-you-sure-remove-label',
          {'label': '${locales.get('label--user').toLowerCase()}: $name'},
        ),
        action: ButtonOptions(onTap: () async {
          try {
            await UserRolesFirebase.onRemove(data, group: group);
            // Type indicates the data field to use in the function, admin level or collection.
            alert.show(AlertData(
              clear: true,
              body: locales.get('alert--user-removed'),
              type: AlertType.success,
              duration: 3,
            ));
          } on FirebaseFunctionsException catch (error) {
            alert.show(AlertData(
              clear: true,
              body: error.message ?? error.details['message'],
              type: AlertType.critical,
            ));
          } catch (error) {
            alert.show(AlertData(
              clear: true,
              body: error.toString(),
              type: AlertType.critical,
            ));
          }
        }),
        type: AlertType.warning,
        widget: AlertWidget.dialog,
      ));
    }

    final content = PaginationContainer(
      padding: EdgeInsets.only(
        top: 32,
        right: 16,
        bottom: primary ? 80 : 16,
        left: 16,
      ),
      stream: state.stream,
      paginate: state.next,
      empty: empty ?? Container(),
      initialData: state.data,
      shrinkWrap: !primary,
      itemBuilder: (BuildContext c, index, dynamic data) {
        final userData = data as Map<String, dynamic>;
        final user = UserData.fromJson(userData);
        assert(user.id != null, 'user id is required');
        bool sameUser = stateUser.serialized.id == user.id;
        // Don't allow a user to change anything about itself on the 'admin' view
        bool canUpdateUser = !sameUser;
        if (disabled) canUpdateUser = false;
        user.role = user.role;
        if (fromCollection) {
          user.role = UserRoles.roleFromData(
            compareData: userData,
            group: group,
            clean: true, // Use clean: true to reduce the role locales
          );
        }
        List<Widget> trailing = [
          const Spacer(),
        ];
        if (canUpdateUser) {
          trailing.addAll([
            IconButton(
              onPressed: () async {
                showDialog<void>(
                  context: context,
                  builder: (context) => UserAddUpdate(
                    successMessage: 'notification--updated',
                    role: roleUpdate,
                    roles: roles,
                    onConfirm: UserRolesFirebase.onUpdate,
                    email: emailUpdate,
                    phone: phoneUpdate,
                    username: usernameUpdate,
                    name: nameUpdate,
                    onChanged: () {},
                    user: user,
                    group: group,
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
              color: Colors.deepOrange,
              onPressed: () => removeUser(user),
              icon: const Icon(Icons.person_remove),
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
            label: SelectableText(user.phone!),
          ));
        }
        if (user.email != null) {
          roleChips.add(Chip(
            avatar: Icon(Icons.email, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: SelectableText(user.email!),
          ));
        }
        if (user.username != null && user.username!.isNotEmpty) {
          roleChips.add(Chip(
            avatar: Icon(Icons.alternate_email, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: SelectableText(user.username!),
          ));
        }
        if (stateUser.admin) {
          roleChips.add(Chip(
            avatar: Icon(Icons.person, color: Colors.grey.shade600),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(0),
            label: SelectableText(user.id),
          ));
        }
        return SizedBox(
          key: ValueKey(user.id),
          child: ContentContainer(
            size: size,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Flex(
                  direction: Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: UserAvatar(
                        avatar: prefix != null && user.avatar != null
                            ? '$prefix/${user.avatar}'
                            : null,
                        name: user.name,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        presence: user.presence,
                      ),
                      title: SelectableText(name, style: textTheme.titleMedium),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.maxFinite,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: roleChips,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: trailing),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Widget userAddWidget = UserAddUpdate(
      successMessage: 'notification--added',
      roles: roles,
      onConfirm: UserRolesFirebase.onAdd,
      email: email,
      phone: phone,
      username: username,
      name: name,
      onChanged: () {},
      role: role,
      password: password,
      group: group,
    );

    if (primary) {
      return Scaffold(
        primary: primary,
        appBar: appBar,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: disabled
            ? null
            : FloatingActionButton.extended(
                icon: const Icon(Icons.person_add),
                label: Text(locales.get('label--add-label', {
                  'label': locales.get('label--user'),
                }).toUpperCase()),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => userAddWidget,
                  );
                },
              ),
        body: content,
      );
    }

    List<Widget> items = [
      content,
    ];
    if (!disabled) {
      items.addAll([
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.center,
          child: FilledButton.icon(
            icon: const Icon(Icons.person_add),
            label: Text(locales.get('label--add-label', {
              'label': locales.get('label--user'),
            }).toUpperCase()),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (c) => userAddWidget,
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
