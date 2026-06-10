import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fabric_flutter/component/users_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../helper/user_roles.dart';
import '../helper/user_roles_firebase.dart';
import '../serialized/user_data.dart';
import '../state/state_user.dart';
import '../state/state_users.dart';
import 'alert_data.dart';
import 'content_container.dart';
import 'pagination_container.dart';
import 'user_add_update.dart';
import 'user_avatar.dart';

/// Builds a user administration interface for inviting and managing users.
///
/// Displays a paginated user list, opens add and update dialogs, and scopes
/// role management with [group], [roles], and the field visibility flags.
class UserAdmin extends StatelessWidget {
  /// Creates a user administration interface.
  ///
  /// Uses the provided flags to control which fields and role actions appear in
  /// the add and update dialogs.
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
    this.multipleRoles = false,
    this.multipleRolesUpdate = false,
    this.nameUpdate = false,
    this.roleUpdate = true,
    this.password = false,
    this.size = ContentContainerSize.medium,
    this.prefix,
    this.passwordError,
    this.passwordRegex,
  });

  /// Provides the empty-state widget when no users are available.
  ///
  /// Replaces the default content shown by [PaginationContainer] after the user
  /// query resolves without any results.
  final Widget? empty;

  /// Provides a custom loading widget for parent-managed loading states.
  ///
  /// Allows parent compositions to supply their own progress UI even though this
  /// widget currently renders the Firestore-backed content directly.
  final Widget? loader;

  /// Defines the roles that can be assigned in add and update flows.
  ///
  /// Supplies the selectable role values for [UserAddUpdate] when users are
  /// created or updated.
  final List<String> roles;

  /// Enables the primary scaffold layout.
  ///
  /// Wraps the content in a [Scaffold] with [appBar] and a floating add button
  /// when set to `true`.
  final bool primary;

  /// Disables add, update, and remove interactions.
  ///
  /// Prevents role-management actions and suppresses add controls when set to
  /// `true`.
  final bool disabled;

  /// Prefixes avatar paths so external image hosts can be resolved.
  ///
  /// Prepends the configured path to [UserData.avatar] before it is passed to
  /// [UserAvatar].
  final String? prefix;

  /// Restricts management to a specific role group.
  ///
  /// Switches the Firestore ordering and role resolution to the matching entry
  /// under `groups.<group>` when a non-empty value is provided.
  final String? group;

  /// Supplies the app bar used by the primary scaffold layout.
  ///
  /// Applies only when [primary] is `true` and the widget returns a [Scaffold].
  final PreferredSizeWidget? appBar;

  /// Includes password fields in the add-user dialog.
  ///
  /// Forwards the flag to [UserAddUpdate] so new users can be created with a
  /// password when set to `true`.
  final bool password;

  /// Shows the role selector in the add-user dialog.
  ///
  /// Controls whether [UserAddUpdate] exposes role assignment for new users.
  final bool role;

  /// Shows the email field in the add-user dialog.
  ///
  /// Controls whether [UserAddUpdate] collects an email address while creating
  /// a user.
  final bool email;

  /// Shows the phone field in the add-user dialog.
  ///
  /// Controls whether [UserAddUpdate] collects a phone number while creating a
  /// user.
  final bool phone;

  /// Shows the username field in the add-user dialog.
  ///
  /// Controls whether [UserAddUpdate] collects a username while creating a
  /// user.
  final bool username;

  /// Shows the name fields in the add-user dialog.
  ///
  /// Controls whether [UserAddUpdate] collects first and last name data while
  /// creating a user.
  final bool name;

  /// Shows the email field in the update dialog.
  ///
  /// Controls whether [UserAddUpdate] exposes email editing for existing users.
  final bool emailUpdate;

  /// Shows the phone field in the update dialog.
  ///
  /// Controls whether [UserAddUpdate] exposes phone editing for existing users.
  final bool phoneUpdate;

  /// Shows the username field in the update dialog.
  ///
  /// Controls whether [UserAddUpdate] exposes username editing for existing
  /// users.
  final bool usernameUpdate;

  /// Shows the name fields in the update dialog.
  ///
  /// Controls whether [UserAddUpdate] exposes name editing for existing users.
  final bool nameUpdate;

  /// Shows the role selector in the update dialog.
  ///
  /// Controls whether [UserAddUpdate] exposes role changes for existing users.
  final bool roleUpdate;

  /// Allows selecting multiple roles while creating a user.
  ///
  /// Forwards multi-role creation support to [UserAddUpdate] when set to
  /// `true`.
  final bool multipleRoles;

  /// Allows selecting multiple roles while updating a user.
  ///
  /// Forwards multi-role update support to [UserAddUpdate] when set to `true`.
  final bool multipleRolesUpdate;

  /// Controls the maximum content width for each rendered user card.
  ///
  /// Passes the selected [ContentContainerSize] to each outer
  /// [ContentContainer].
  final ContentContainerSize size;

  /// Overrides the password validation pattern used by [UserAddUpdate].
  ///
  /// Supplies a custom [RegExp] when add or update dialogs need validation rules
  /// beyond the default password requirements.
  final RegExp? passwordRegex;

  /// Overrides the password validation error shown by [UserAddUpdate].
  ///
  /// Provides custom localized feedback when [passwordRegex] rejects the entered
  /// password.
  final String? passwordError;

  /// Builds the user administration interface.
  ///
  /// Connects [StateUser] and [StateUsers] to a Firestore-backed query,
  /// configures localized error handling, and returns either a primary
  /// [Scaffold] or an inline layout depending on [primary].
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

    // Set default limit when you will use shrinkWrap
    if (!primary) state.limitDefault = 100;

    /// Reports provider and state errors with a localized critical alert.
    ///
    /// Returns `null` when [e] is `null` so empty error callbacks can be safely
    /// ignored.
    apiError(String? e) => (e != null)
        ? alertData(
            context: context,
            title: locales.get(e),
            type: AlertType.critical,
          )
        : null;
    stateUser.onError = apiError;
    state.onError = apiError;

    Query<Map<String, dynamic>> baseQuery = FirebaseFirestore.instance
        .collection('user');
    Query<Map<String, dynamic>> query = baseQuery;

    // Order by role for global users, because the role key is only available for
    // parent users.
    query = query.orderBy('name');
    bool fromCollection = group != null && group!.isNotEmpty;
    if (fromCollection) {
      query = baseQuery.orderBy('groups.$group');
    }
    state.query = query;
    state.listen();

    Widget space = Container(width: 16);

    /// Confirms and removes the selected user.
    ///
    /// Resolves the best available display name from [UserData] so the warning
    /// dialog stays recognizable before [UserRolesFirebase.onRemove] executes.
    removeUser(UserData data) {
      String? name = data.name.trim().length > 4 ? data.name : null;
      name ??=
          data.firstName ??
          data.username ??
          data.phone ??
          data.email ??
          data.id;
      alertData(
        context: context,
        title: locales.get('label--confirm-are-you-sure-remove-label', {
          'label': '${locales.get('label--user').toLowerCase()}: $name',
        }),
        action: ButtonOptions(
          onTap: () async {
            try {
              await UserRolesFirebase.onRemove(data, group: group);
              // Type indicates the data field to use in the function, admin level or collection.
              alertData(
                context: context,
                body: locales.get('alert--user-removed'),
                type: AlertType.success,
                duration: 3,
              );
            } on FirebaseFunctionsException catch (error) {
              alertData(
                context: context,
                body: error.message ?? error.details['message'],
                type: AlertType.critical,
              );
            } catch (error) {
              alertData(
                context: context,
                body: error.toString(),
                type: AlertType.critical,
              );
            }
          },
        ),
        type: AlertType.warning,
        widget: AlertWidget.dialog,
      );
    }

    /// Opens the update dialog for the selected user.
    ///
    /// Disables editing when the selected [user] matches the current
    /// [StateUser.serialized] identity or when [disabled] is `true`.
    showUpdateDialog(UserData user) {
      bool sameUser = stateUser.serialized.id == user.id;
      // Don't allow a user to change anything about itself on the 'admin' view
      bool canUpdateUser = !sameUser;
      if (disabled) canUpdateUser = false;
      showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        fullscreenDialog: true,
        builder: (context) => PointerInterceptor(
          child: UserAddUpdate(
            key: Key('user-update-component-${user.id}'),
            successMessage: 'notification--updated',
            role: roleUpdate,
            roles: roles,
            onConfirm: UserRolesFirebase.onUpdate,
            email: emailUpdate,
            phone: phoneUpdate,
            username: usernameUpdate,
            name: nameUpdate,
            multipleRoles: multipleRolesUpdate,
            onChanged: () {},
            user: user,
            group: group,
            passwordError: passwordError,
            passwordRegex: passwordRegex,
            disabled: !canUpdateUser,
          ),
        ),
      );
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
      empty: empty,
      initialData: state.data,
      shrinkWrap: !primary,
      top: ContentContainer(
        child: UsersDropdown(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          showTrailing: true,
          prefix: prefix,
          onChanged: (value) {
            showUpdateDialog(value);
          },
        ),
      ),
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
        List<Widget> trailing = [const Spacer()];
        if (canUpdateUser) {
          trailing.addAll([
            IconButton(
              key: Key('user-update-${user.id}'),
              onPressed: () => showUpdateDialog(user),
              icon: Icon(Icons.edit, color: theme.colorScheme.primary),
            ),
            space,
            IconButton(
              key: Key('user-remove-${user.id}'),
              color: Colors.deepOrange,
              onPressed: () => removeUser(user),
              icon: const Icon(Icons.person_remove),
            ),
          ]);
        }
        List<Widget> roleChips = [
          Chip(
            padding: EdgeInsets.zero,
            label: Text(locales.get('label--${user.role}')),
          ),
        ];
        String name = user.name.isNotEmpty ? user.name : '';
        if (user.phone != null) {
          roleChips.add(
            Chip(
              avatar: Icon(Icons.phone, color: Colors.grey.shade600),
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.all(0),
              label: SelectableText(user.phone!),
            ),
          );
        }
        if (user.email != null) {
          roleChips.add(
            Chip(
              avatar: Icon(Icons.email, color: Colors.grey.shade600),
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.all(0),
              label: SelectableText(user.email!),
            ),
          );
        }
        if (user.username != null && user.username!.isNotEmpty) {
          roleChips.add(
            Chip(
              avatar: Icon(Icons.alternate_email, color: Colors.grey.shade600),
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.all(0),
              label: SelectableText(user.username!),
            ),
          );
        }
        if (stateUser.admin) {
          roleChips.add(
            Chip(
              avatar: Icon(Icons.person, color: Colors.grey.shade600),
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.all(0),
              label: SelectableText(user.id),
            ),
          );
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
    Widget userAddWidget = PointerInterceptor(
      child: UserAddUpdate(
        key: const Key('user-add-update'),
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
        multipleRoles: multipleRoles,
        passwordError: passwordError,
        passwordRegex: passwordRegex,
      ),
    );

    if (primary) {
      return Scaffold(
        primary: primary,
        appBar: appBar,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: disabled
            ? null
            : PointerInterceptor(
                child: FloatingActionButton.extended(
                  icon: const Icon(Icons.person_add),
                  label: Text(
                    locales.get('label--add-label', {
                      'label': locales.get('label--user'),
                    }).toUpperCase(),
                  ),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false, // user must tap button!
                      builder: (context) => userAddWidget,
                    );
                  },
                ),
              ),
        body: content,
      );
    }

    List<Widget> items = [content];
    if (!disabled) {
      items.addAll([
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.center,
          child: PointerInterceptor(
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add),
              label: Text(
                locales.get('label--add-label', {
                  'label': locales.get('label--user'),
                }).toUpperCase(),
              ),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  barrierDismissible: false, // user must tap button!
                  builder: (c) => userAddWidget,
                );
              },
            ),
          ),
        ),
      ]);
    }

    return Flex(direction: Axis.vertical, children: items);
  }
}
