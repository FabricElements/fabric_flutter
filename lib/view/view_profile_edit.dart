import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fabric_flutter/fabric_flutter.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../placeholder/loading_screen.dart';

class ViewProfileEdit extends StatefulWidget {
  ViewProfileEdit({
    Key? key,
    this.loader,
  }) : super(key: key);
  final Widget? loader;

  @override
  _ViewProfileEditState createState() => _ViewProfileEditState();
}

class _ViewProfileEditState extends State<ViewProfileEdit> {
  late bool changed;
  AssetImage? defaultImage;
  late bool loading;
  ImageProvider? previewImage;
  Uint8List? _temporalImageBytes;
  String? userImage;
  String nameFirst = "";
  String nameLast = "";
  TextEditingController nameFirstController = TextEditingController();
  TextEditingController nameLastController = TextEditingController();
  String? _avatarFinalUrl;

  @override
  void initState() {
    super.initState();
    loading = false;
    changed = false;
    defaultImage = AssetImage("assets/placeholder.jpg");
    nameFirstController.text = "";
    nameLastController.text = "";
    nameFirst = "";
    nameLast = "";
  }

  @override
  void didChangeDependencies() {
    nameFirstController.addListener(_nameFirstChanged);
    nameLastController.addListener(_nameLastChanged);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    nameFirstController.dispose();
    nameLastController.dispose();
    super.dispose();
  }

  _nameFirstChanged() {
    var newName = nameFirstController.text;
    if (newName.length < 1 || newName == nameFirst) {
      return;
    }
    changed = true;
    if (mounted) setState(() {});
  }

  _nameLastChanged() {
    var newName = nameLastController.text;
    if (newName.length < 1 || newName == nameLast) {
      return;
    }
    changed = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations locales = AppLocalizations.of(context)!;
    StateUser stateUser = Provider.of<StateUser>(context);
    userImage = stateUser.serialized.avatar;
    nameFirst = stateUser.serialized.nameFirst;
    nameLast = stateUser.serialized.nameLast;
    if (!changed) {
      nameFirstController.text = nameFirst;
      nameLastController.text = nameLast;
      changed = false;
    }
    void refreshImage() {
      _avatarFinalUrl = null;
      try {
        if (_temporalImageBytes != null) {
          // String base64Image = base64UrlEncode(_temporalImageBytes!);
          // previewImage = NetworkImage(base64Image);
          // previewImage = FileImage(File(base64Image));
          previewImage = MemoryImage(_temporalImageBytes!);
          return;
        }
        if (userImage != null) {
          String userLastUpdate = stateUser.data["updated"] != null
              ? (stateUser.data["updated"] as Timestamp).seconds.toString()
              : "";
          _avatarFinalUrl = "$userImage?size=medium&t=" + userLastUpdate;
          previewImage = NetworkImage(_avatarFinalUrl!);
          return;
        }
      } catch (error) {
        print(error);
      }

      previewImage = defaultImage;
    }

    refreshImage();
    Alert alert = Alert(
      context: context,
      mounted: mounted,
    );
    void _closeKeyboard() {
      try {
        FocusScope.of(context).requestFocus(FocusNode());
      } catch (error) {}
    }

    updateUser() async {
      loading = false;
      if (mounted) setState(() {});
      AppLocalizations? locales = AppLocalizations.of(context)!;
      if (!changed) {
        alert.show(text: locales.get("page-profile--alert--nothing-to-update"));
        return;
      }
      String newNameFirst = nameFirstController.text;
      newNameFirst = newNameFirst.trim();
      String newNameLast = nameLastController.text;
      newNameLast = newNameLast.trim();
      if (newNameFirst.length < 3) {
        alert.show(
          text: locales.get("label--too-short", {
            "label": locales.get("label--name-first"),
            "number": "3",
          }),
          type: "error",
        );
        return;
      }
      if (newNameLast.length < 3) {
        alert.show(
          text: locales.get("label--too-short", {
            "label": locales.get("label--name-last"),
            "number": "3",
          }),
          type: "error",
        );
        return;
      }
      loading = true;
      if (mounted) setState(() {});

      Map<String, dynamic> newData = {
        "nameFirst": newNameFirst,
        "nameLast": newNameLast,
      };
      try {
        if (_temporalImageBytes != null) {
          String base64Image = base64Encode(_temporalImageBytes!);
          String photoURL = base64Image;
          newData.addAll({
            "avatar": photoURL,
          });
        }
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable("user-actions-update");
        await callable.call(newData);
        _temporalImageBytes = null;
        changed = false;
        loading = false;
        if (mounted) setState(() {});
        alert.show(
          text: locales.get("page-profile--alert--profile-updated"),
          type: "success",
        );
        if (!stateUser.serialized.onboarding.name) {
          Navigator.of(context).pop();
        }
        refreshImage();
      } on FirebaseFunctionsException catch (error) {
        alert.show(
            text: error.message ?? error.details["message"], type: "error");
      } catch (error) {
        alert.show(
          text: error.toString(),
          type: "error",
        );
      }
      loading = false;
      if (mounted) setState(() {});
    }

    Future<void> getImageFromOrigin(String origin) async {
      loading = true;
      if (mounted) setState(() {});
      try {
        _temporalImageBytes = await ImageHelper().getImage(origin: origin);
        if (_temporalImageBytes != null) {
          changed = _temporalImageBytes != null;
        }
      } catch (error) {
        alert.show(
          text: error.toString(),
          type: "error",
        );
      }

      loading = false;
      if (mounted) setState(() {});
    }

    Widget getBody() {
      AppLocalizations locales = AppLocalizations.of(context)!;
      if (loading) {
        return widget.loader ?? LoadingScreen();
      }
      double width = MediaQuery.of(context).size.width;
      double height = MediaQuery.of(context).size.height;
      double smallerSize =
          math.min(width >= 150 ? width : 150, height >= 150 ? height : 150);
      return ListView(
        children: <Widget>[
          Container(
            constraints: BoxConstraints(maxWidth: 300, maxHeight: 300),
            child: AspectRatio(
              aspectRatio: 1 / 1,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: RawMaterialButton(
                    hoverColor: Colors.transparent,
                    onPressed: _temporalImageBytes == null
                        ? () async {
                            Navigator.pushNamed(context, '/hero',
                                arguments: {"url": userImage});
                          }
                        : null,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 100, maxWidth: 300),
                      child: AspectRatio(
                        aspectRatio: 1 / 1,
                        child: CircleAvatar(
                          backgroundImage: previewImage,
                          child: Stack(
                            children: <Widget>[
                              Positioned(
                                bottom: 0,
                                left: 15,
                                child: FloatingActionButton(
                                  backgroundColor: Colors.grey.shade50,
                                  heroTag: "image",
                                  child: Icon(
                                    Icons.image,
                                    color: Theme.of(context).accentColor,
                                  ),
                                  onPressed: () async {
                                    await getImageFromOrigin("gallery");
                                  },
                                ),
                              ),
                              !kIsWeb
                                  ? Positioned(
                                      bottom: 0,
                                      right: 15,
                                      child: FloatingActionButton(
                                        heroTag: "camera",
                                        child: Icon(Icons.photo_camera),
                                        onPressed: () async {
                                          await getImageFromOrigin("camera");
                                        },
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: nameFirstController,
              decoration: InputDecoration(
                labelText: locales.get("label--name-first"),
                hintText: locales.get("label--name-first"),
              ),
              maxLines: 1,
              keyboardType: TextInputType.text,
              maxLength: 15,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.singleLineFormatter,
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z ]")),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: nameLastController,
              decoration: InputDecoration(
                labelText: locales.get("label--name-last"),
                hintText: locales.get("label--name-last"),
              ),
              maxLines: 1,
              keyboardType: TextInputType.text,
              maxLength: 15,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.singleLineFormatter,
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z '-]")),
              ],
            ),
          ),
          Container(height: 32),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(locales.get("page-profile--title")),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.navigate_before),
          onPressed: () {
            Navigator.popUntil(context, ModalRoute.withName("/"));
          },
        ),
      ),
      body: GestureDetector(onTap: _closeKeyboard, child: getBody()),
      floatingActionButton: changed && !loading
          ? FloatingActionButton.extended(
              label: Text(locales.get("label--update")),
              onPressed: updateUser,
              heroTag: "update-button",
            )
          : null,
    );
  }
}