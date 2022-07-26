library fabric_flutter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../serialized/user_data.dart';
import '../state/state_alert.dart';
import '../state/state_user.dart';
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
  }) : super(key: key);
  final Widget? empty;
  final Widget? loader;
  final List<String>? roles;
  final bool primary;
  final bool disabled;

  /// Firestore Document [id]
  final String? id;

  /// Firestore [collection]
  final String? collection;

  /// Firestore [data]
  final Map<String, dynamic>? data;
  final PreferredSizeWidget? appBar;
  final double maxWidth;

  @override
  State<UserAdmin> createState() => _UserAdminState();
}

class _UserAdminState extends State<UserAdmin> {
  Stream<QuerySnapshot>? _usersStream;
  List<DocumentSnapshot>? items;
  int? totalItems;

  @override
  void initState() {
    totalItems = 0;
    items = [];
    super.initState();
  }

  @override
  void dispose() {
    try {
      _usersStream!.drain();
    } catch (error) {
      //
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    AppLocalizations locales = AppLocalizations.of(context)!;
    final stateUser = Provider.of<StateUser>(context);
    Query baseQuery = FirebaseFirestore.instance.collection('user');
    Query query = baseQuery;

    /// Get data from navigation arguments
    Map<String, dynamic> args = Map.from(
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {});
    String? id = widget.id ?? args['document'];
    String? collection = widget.collection;
    Map<String, dynamic>? documentData = widget.data ?? args['data'];
    if (collection != null || id != null || documentData != null) {
      assert(collection != null && id != null,
          'collection, document and documentData can\'t be null when including one of them.');
    }
    bool fromCollection = collection != null && id != null;
    Widget space = Container(width: 16);
    Map<String, dynamic> inviteMetadata = {};
    final alert = Provider.of<StateAlert>(context, listen: false);
    Map<String?, dynamic> removeOptions = {};

    /// Order By role for global users, the role key is only available for parent users
    query = query.orderBy('role');
    inviteMetadata = {
      'admin': true,
    };
    if (fromCollection) {
      query = baseQuery.orderBy('$collection.$id');
      inviteMetadata = {
        'collection': collection,
        'document': id,
      };
    }
    removeOptions.addAll(inviteMetadata);
    // Init here after finishing query
    _usersStream = query.snapshots();

    /// Deletes the related user listed user, the documentId is the users uid
    _removeUser(String documentId) async {
      HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('user-actions-remove');
      removeOptions.addAll({
        'uid': documentId,
      });
      // Type indicates the data field to use in the function, admin level or collection.
      await callable.call(removeOptions); // USER DATA
      alert.show(AlertData(
        body: locales.get('alert--user-removed'),
        type: AlertType.success,
        duration: 3,
      ));
    }

    Widget _buildItem(DocumentSnapshot data) {
      DocumentSnapshot userDocument = data;
      Map<String, dynamic> userData =
          userDocument.data()! as Map<String, dynamic>;
      userData.addAll({'id': userDocument.id});
      UserData itemData = UserData.fromJson(userData);
      bool sameUser = stateUser.id == itemData.id;
      // Don't allow a user to change anything about itself on the 'admin' view
      bool canUpdateUser = !sameUser;
      if (widget.disabled) canUpdateUser = false;
      Color statusColor = Colors.grey.shade600;
      switch (itemData.presence) {
        case 'active':
          statusColor = Colors.green;
          break;
        case 'inactive':
          statusColor = Colors.deepOrange;
      }
      if (sameUser) {
        statusColor = Colors.green;
      }
      String roleFinal = itemData.role;
      if (id != null) {
        roleFinal = stateUser.roleFromDataAny(
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
      String name = itemData.name.isNotEmpty
          ? itemData.name
          : locales.get('label--unknown');
      if (itemData.phone.isNotEmpty) {
        roleChips.add(Chip(
          avatar: Icon(Icons.phone, color: Colors.grey.shade600),
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.all(0),
          label: Text(itemData.phone),
        ));
      } else if (itemData.email.isNotEmpty) {
        roleChips.add(Chip(
          avatar: Icon(Icons.email, color: Colors.grey.shade600),
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.all(0),
          label: Text(itemData.email),
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
                  key: Key(itemData.id!),
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
                        await _removeUser(userDocument.id);
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
                          uid: itemData.id!,
                          name: name,
                        ),
                      );
                    },
                    isThreeLine: true,
                    leading: UserAvatar(
                      avatar: itemData.avatar,
                      name: itemData.name.isNotEmpty
                          ? itemData.name
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
    }

    Widget content = StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          if (kDebugMode) print(snapshot.error);
          return Text('Error: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.none) {
          return widget.loader ?? Container();
        }
        int totalDocs = snapshot.data?.size ?? 0;
        if (totalDocs == 0) {
          return widget.empty ?? Container();
        }
        if (widget.primary) {
          return ListView.builder(
            primary: widget.primary,
            padding: widget.primary
                ? const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 100)
                : const EdgeInsets.only(bottom: 100),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              return _buildItem(snapshot.data!.docs[index]);
            },
          );
        }
        return Flex(
          direction: Axis.vertical,
          children: snapshot.data!.docs.map((e) => _buildItem(e)).toList(),
        );
      },
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
                    builder: (context) =>
                        UserAdd(data: inviteMetadata, roles: widget.roles),
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
                builder: (context) =>
                    UserAdd(data: inviteMetadata, roles: widget.roles),
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
