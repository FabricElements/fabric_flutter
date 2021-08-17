import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fabric_flutter/fabric_flutter.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../splash/loading.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class ProfilePage extends StatefulWidget {
  ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late bool changed;
  AssetImage? defaultImage;
  late bool loading;
  var previewImage;
  String? _temporalImagePath;
  String? userImage;
  String nameFirst = "";
  String nameLast = "";
  TextEditingController nameFirstController = TextEditingController();
  TextEditingController nameLastController = TextEditingController();

  void refreshImage() {
    if (_temporalImagePath != null) {
      previewImage = FileImage(File(_temporalImagePath!));
      return;
    }
    if (userImage != null) {
      previewImage = NetworkImage(userImage!);
      return;
    }
    previewImage = defaultImage;
  }

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
    if (!changed) {
      nameFirstController.text = nameFirst;
      nameLastController.text = nameLast;
      changed = false;
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

    uploadImage() async {
      if (_temporalImagePath == null) {
        return null;
      }
      String uid = stateUser.id!;
      Map<String, String> metadata = {"type": "avatar", "user": uid};
      _temporalImagePath = await ImageHelper()
          .resize(imagePath: _temporalImagePath!, imageType: "jpeg");
      if (_temporalImagePath == null) return null;
      try {
        TaskSnapshot taskSnapshot = await FirebaseStorageHelper(
          reference: FirebaseStorage.instance.ref(),
        ).upload(
          File(_temporalImagePath!),
          "images/user",
          uid,
          "image/jpeg",
          metadata,
        );
        return await taskSnapshot.ref.getDownloadURL();
      } catch (error) {
        alert.show(text: error.toString(), type: "error");
        print(error.toString());
      }
      return null;
    }

    updateUser() async {
      AppLocalizations? locales = AppLocalizations.of(context);
      if (!changed) {
        alert.show(
            text: locales!.get("page-profile--alert--nothing-to-update"));
        return;
      }
      String newNameFirst = nameFirstController.text;
      newNameFirst = newNameFirst.trim();
      String newNameLast = nameLastController.text;
      newNameLast = newNameLast.trim();
      if (newNameFirst.length < 2 || newNameLast.length < 2) {
        alert.show(
          text: locales!.get("page-profile--alert--name-too-short"),
          type: "error",
        );
        return;
      }
      loading = true;
      if (mounted) setState(() {});
      var imageUrl = await uploadImage();
      String? photoURL = imageUrl ?? null;
      final User userRef = _auth.currentUser!;
      Map<String, dynamic> onboardingData = {
        "name": true,
      };
      Map<String, dynamic> newData = {
        "nameFirst": newNameFirst,
        "nameLast": newNameLast,
        "backup": false,
        "onboarding": onboardingData,
      };
      String newName = "$newNameFirst $newNameLast";
      try {
        if (photoURL != null) {
          await userRef.updatePhotoURL(photoURL);
          newData.addAll({
            "avatar": photoURL,
          });
          onboardingData.addAll({
            "avatar": true,
          });
        }
        await userRef.updateDisplayName(newName);
        stateUser.set(newData, merge: true);
        if (imageUrl != null) {
          _temporalImagePath = null;
        }
        changed = false;
        loading = false;
        if (mounted) setState(() {});
        alert.show(
          text: locales!.get("page-profile--alert--profile-updated"),
          type: "success",
        );
        if (!stateUser.serialized.onboarding.name) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        print(error);
        loading = false;
        if (mounted) setState(() {});
        await Future.delayed(Duration(seconds: 3));
        alert.show(
          text: locales!.get("notifications--try-again"),
          type: "error",
        );
      }
    }

    Widget getBody() {
      AppLocalizations locales = AppLocalizations.of(context)!;
      if (loading) {
        return LoadingScreen();
      }
      double width = MediaQuery.of(context).size.width;
      double height = MediaQuery.of(context).size.height;
      double smallerSize =
          math.min(width >= 150 ? width : 150, height >= 150 ? height : 150);
      return Container(
        child: ListView(
          children: <Widget>[
            Container(
              width: width,
              height: smallerSize,
              child: AspectRatio(
                aspectRatio: 1 / 1,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: RawMaterialButton(
                      onPressed: () async {
                        String basePath =
                            await ImageHelper().getImage(origin: "camera");
                        _temporalImagePath = basePath;
                        if (_temporalImagePath != null) {
                          changed = true;
                        }
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        height: smallerSize,
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
                                        String basePath = await ImageHelper()
                                            .getImage(origin: "gallery");
                                        _temporalImagePath = basePath;
                                        if (_temporalImagePath != null) {
                                          changed = true;
                                        }
                                        if (mounted) setState(() {});
                                      }),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 15,
                                  child: FloatingActionButton(
                                    heroTag: "camera",
                                    child: Icon(Icons.photo_camera),
                                    onPressed: () async {
                                      String basePath = await ImageHelper()
                                          .getImage(origin: "camera");
                                      _temporalImagePath = basePath;
                                      if (_temporalImagePath != null) {
                                        changed = true;
                                      }
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ),
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
              padding: EdgeInsets.all(16),
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
              padding: EdgeInsets.all(16),
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
        ),
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
      floatingActionButton: changed
          ? FloatingActionButton.extended(
              label: Text(locales.get("label--update")),
              onPressed: updateUser,
              heroTag: "image",
            )
          : null,
    );
  }
}
