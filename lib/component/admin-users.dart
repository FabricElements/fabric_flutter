import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../component/role-selector.dart';
import '../component/user-avatar.dart';
import '../component/user-invite.dart';
import '../helper/alert.dart';
import '../helper/locales.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/user_data.dart';
import '../state/state-user.dart';

/// Invite and manage Users and their roles
/// [loader] Widget displayed when a process is in progress
/// [roles] Replaces default roles with your custom roles
class AdminUsers extends StatefulWidget {
  AdminUsers({
    Key? key,
    this.empty,
    this.loader,
    this.roles,
  }) : super(key: key);
  final Widget? empty;
  final Widget? loader;
  final Map<String, String>? roles;

  @override
  _AdminUsersState createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
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
    AppLocalizations? locales = AppLocalizations.of(context);
    StateUser stateUser = Provider.of<StateUser>(context);
    final args = Map.from(
        ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>? ??
            {});
    Query query = FirebaseFirestore.instance.collection("user");
    String? collectionId = args["collectionId"] ?? null;
    String? collection = args["collection"] ?? null;
    Map<String, dynamic>? collectionData = args["collectionData"] ?? null;
    bool fromCollection = collectionId != null && collection != null;
    Widget space = Container(width: 16);
    Map<String, dynamic> inviteMetadata = {};
    String? _newRole;
    Alert alert = Alert(
      context: context,
      mounted: mounted,
    );
    Map<String, String?> _roles = widget.roles ??
        {
          "admin": locales?.get("label--admin") ?? "Admin",
          "agent": locales?.get("label--agent") ?? "Agent",
        };
    Map<String?, dynamic> removeOptions = {};
    Map<String?, dynamic> updateOptions = {};

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
          FirebaseFunctions.instance.httpsCallable('user-remove');
      removeOptions.addAll({
        "uid": documentId,
      });
      // Type indicates the data field to use in the function, admin level or collection.
      await callable.call(removeOptions); // USER DATA
      alert.show(text: locales!.get("alert--user-removed"), type: "success");
    }

    DocumentReference? _updateReference = fromCollection
        ? FirebaseFirestore.instance.collection(collection).doc(collectionId)
        : null;

    _changeRole(String uid, String? role) async {
      if (collectionId == null) {
        return null;
      }
      if (_newRole == null) {
        Navigator.of(context).pop();
        return;
      }
      await _updateReference?.set({
        "backup": false,
        "roles": {
          uid: role,
        },
        "updated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('user-updateRole');
      updateOptions.addAll({
        "uid": uid,
      });
      // Type indicates the data field to use in the function, admin level or collection.
      await callable.call(updateOptions); // USER DATA

      Navigator.of(context).pop();
    }

    _changeUserRole(String uid) {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false,
              primary: false,
              title: Text(locales!.get("label--update-user")),
            ),
            body: Container(
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    RoleSelector(
                      list: _roles,
                      hintText: "Select you role",
                      onChange: (value) {
                        _newRole = value;
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          child: Text(
                            locales.get("label--update"),
                          ),
                          onPressed: () async {
                            await _changeRole(uid, _newRole);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          Alert _alert = Alert(
            context: context,
            mounted: mounted,
          );
          return FractionallySizedBox(
            heightFactor: 0.7,
            child: UserInvite(
              user: stateUser.object,
              data: inviteMetadata,
              showPhone: true,
              alert: (message) {
                _alert.show(text: message["text"], type: message["type"]);
              },
              roles: _roles as Map<String, String>,
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(locales!.get("label--users")),
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
              String _uid = userDocument.id;
              Map<String, dynamic> userData =
                  userDocument.data()! as Map<String, dynamic>;
              UserData serialized = UserData.fromJson(userData);
              Color statusColor = Colors.grey.shade600;
              String _role = stateUser.roleFromData(
                compareData: collectionData,
                uid: _uid,
              );
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
              String name = locales.get("label--unknown");
              if (serialized.name.isEmpty) {
                if (serialized.phone.isNotEmpty) {
                  name = serialized.phone;
                } else if (serialized.email.isNotEmpty) {
                  name = serialized.email;
                }
              }
              // Don't allow a user to change anything about itself on the "admin" view
              bool _canUpdateUser = stateUser.id != _uid;
              List<Widget> _roleChips = [
                Chip(
                  backgroundColor: Colors.indigo.shade500,
                  padding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 0,
                  ),
                  labelStyle: textTheme.caption!.copyWith(color: Colors.white),
                  labelPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 8,
                  ),
                  label: Text(_role),
                ),
              ];
              return Wrap(
                children: <Widget>[
                  AbsorbPointer(
                    absorbing: _canUpdateUser,
                    child: Dismissible(
                      key: Key(_uid),
                      child: ListTile(
                        onTap: () async {
                          _changeUserRole(_uid);
                        },
                        isThreeLine: true,
                        leading: UserAvatar(
                          avatar: userData["avatar"],
                          name: userData["name"] ?? locales.get("unknown"),
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
                        } catch (error) {
                          alert.show(text: error.toString(), type: "error");
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
