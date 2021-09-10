import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../component/user_avatar.dart';
import '../component/user_invite.dart';
import '../component/user_role_update.dart';
import '../helper/alert.dart';
import '../helper/app_localizations_delegate.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/user_data.dart';
import '../state/state_user.dart';

/// Invite and manage Users and their roles
/// [loader] Widget displayed when a process is in progress
/// [roles] Replaces default roles with your custom roles
class ViewAdminUsers extends StatefulWidget {
  ViewAdminUsers({
    Key? key,
    this.empty,
    this.loader,
    this.roles,
  }) : super(key: key);
  final Widget? empty;
  final Widget? loader;
  final List<String>? roles;

  @override
  _ViewAdminUsersState createState() => _ViewAdminUsersState();
}

class _ViewAdminUsersState extends State<ViewAdminUsers> {
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
    } catch (error) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    AppLocalizations locales = AppLocalizations.of(context)!;
    StateUser stateUser = Provider.of<StateUser>(context);
    stateUser.ping("admin-users");
    Query query = FirebaseFirestore.instance.collection("user");

    /// Get data from navigation arguments
    Map<String, dynamic> args = Map.from(
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {});
    String? collectionId = args["collectionId"] ?? null;
    String? collection = args["collection"] ?? null;
    // Get roles from navigation first
    List<String>? _roles = args["roles"] ?? widget.roles ?? null;
    Map<String, dynamic>? collectionData = args["collectionData"] ?? null;
    bool fromCollection = collectionId != null && collection != null;
    Widget space = Container(width: 16);
    Map<String, dynamic> inviteMetadata = {};
    Alert alert = Alert(
      context: context,
      mounted: mounted,
    );
    Map<String?, dynamic> removeOptions = {};

    query = query.orderBy("role");
    inviteMetadata = {
      "admin": true,
    };
    if (fromCollection) {
      query = query.where(collection, arrayContains: collectionId);
      inviteMetadata = {
        "collection": collection,
        "collectionId": collectionId,
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
        "uid": documentId,
      });
      // Type indicates the data field to use in the function, admin level or collection.
      await callable.call(removeOptions); // USER DATA
      alert.show(title: locales.get("alert--user-removed"), type: AlertTypes.success);
    }

    _changeUserRole(String uid, String name) {
      return showModalBottomSheet(
        context: context,
        builder: (BuildContext _context) {
          return UserRoleUpdate(
            user: stateUser.object,
            data: inviteMetadata,
            roles: _roles,
            uid: uid,
            name: name,
          );
        },
      );
    }

    /// Shows the widget to invite a new user to a collection through a bottom sheet.
    void _inviteUser() {
      showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext _context) {
          return FractionallySizedBox(
            heightFactor: 0.8,
            child: UserInvite(
              user: stateUser.object,
              data: inviteMetadata,
              roles: _roles,
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(locales.get("label--users")),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        tooltip: locales.get("label--new-user"),
        icon: Icon(Icons.add),
        label: Text('${locales.get("label--add-more")}'.toUpperCase()),
        onPressed: () {
          _inviteUser();
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return Text('Error: ${snapshot.error}');
          }
          if (snapshot.connectionState == ConnectionState.none) {
            return widget.loader ?? LoadingScreen();
          }
          int totalDocs = snapshot.data?.size ?? 0;
          if (totalDocs == 0) {
            return widget.empty ?? Container();
          }
          return ListView.builder(
            padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 100),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              DocumentSnapshot userDocument = snapshot.data!.docs[index];
              Map<String, dynamic> userData =
                  userDocument.data()! as Map<String, dynamic>;
              userData.addAll({"id": userDocument.id});
              UserData _itemData = UserData.fromJson(userData);
              bool _sameUser = stateUser.id == _itemData.id;
              // Don't allow a user to change anything about itself on the "admin" view
              bool _canUpdateUser = !_sameUser;
              Color statusColor = Colors.grey.shade600;
              switch (_itemData.presence) {
                case "active":
                  statusColor = Colors.green;
                  break;
                case "inactive":
                  statusColor = Colors.deepOrange;
              }
              if (_sameUser) {
                statusColor = Colors.green;
              }
              String _role = _itemData.role;
              if (collectionId != null) {
                _role = stateUser.roleFromData(
                  compareData: collectionData,
                  uid: _itemData.id,
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
              String name = _itemData.name.isNotEmpty
                  ? _itemData.name
                  : locales.get("label--unknown");
              if (_itemData.name.isEmpty) {
                if (_itemData.phone.isNotEmpty) {
                  name = _itemData.phone;
                } else if (_itemData.email.isNotEmpty) {
                  name = _itemData.email;
                }
              }
              List<Widget> _roleChips = [
                Chip(
                  padding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 0,
                  ),
                  label: Text(locales.get("label--$_role")),
                ),
              ];
              return Wrap(
                children: <Widget>[
                  AbsorbPointer(
                    absorbing: !_canUpdateUser,
                    child: Dismissible(
                      key: Key(_itemData.id!),
                      child: ListTile(
                        onTap: () async {
                          _changeUserRole(_itemData.id!, name);
                        },
                        isThreeLine: true,
                        leading: UserAvatar(
                          avatar: _itemData.avatar,
                          name: _itemData.name.isNotEmpty
                              ? _itemData.name
                              : locales.get("label--unknown"),
                        ),
                        title: Text(
                          name,
                          style: textTheme.headline6,
                        ),
                        subtitle: Wrap(
                          children: _roleChips,
                          crossAxisAlignment: WrapCrossAlignment.center,
                        ),
                        trailing: Wrap(
                          children: trailing,
                          crossAxisAlignment: WrapCrossAlignment.center,
                        ),
                      ),
                      background: Container(
                        color: Colors.deepOrangeAccent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Icon(Icons.delete, color: Colors.white),
                            space,
                            Text(locales.get("label--remove"),
                                style: TextStyle(color: Colors.white)),
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
                          }
                        } on FirebaseFunctionsException catch (error) {
                          alert.show(
                              title: error.message ?? error.details["message"],
                              type: AlertTypes.critical);
                        } catch (error) {
                          alert.show(title: error.toString(), type: AlertTypes.critical);
                        }
                        return response;
                      },
                    ),
                  ),
                  Divider(height: 0),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
