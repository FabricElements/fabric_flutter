import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fabric_flutter/component/content_container.dart';
import 'package:fabric_flutter/component/input_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/media_helper.dart';
import '../state/state_alert.dart';
import '../state/state_user.dart';

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({
    super.key,
    this.loader,
    this.prefix,
  });

  final Widget? loader;
  final String? prefix;

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  late bool changed;
  AssetImage? defaultImage;
  late bool loading;
  ImageProvider? previewImage;
  Uint8List? _temporalImageBytes;
  String? userImage;
  String? nameFirst;
  String? nameLast;
  String? _avatarFinalUrl;

  @override
  void initState() {
    loading = false;
    changed = false;
    defaultImage = const AssetImage('assets/placeholder.jpg');
    nameFirst = null;
    nameLast = null;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final alert = Provider.of<StateAlert>(context, listen: false);
    final locales = AppLocalizations.of(context);
    final stateUser = Provider.of<StateUser>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stateUser.ping('profile');
    });
    userImage = widget.prefix != null && stateUser.serialized.avatar != null
        ? '${widget.prefix}/${stateUser.serialized.avatar}'
        : stateUser.serialized.avatar;
    if (!changed) {
      nameFirst = nameFirst ?? stateUser.serialized.firstName;
      nameLast = nameLast ?? stateUser.serialized.lastName;
    }
    void refreshImage() {
      _avatarFinalUrl = null;
      try {
        if (_temporalImageBytes != null) {
          previewImage = MemoryImage(_temporalImageBytes!);
          return;
        }
        if (userImage != null) {
          String userLastUpdate = stateUser.data['updated'] != null
              ? (stateUser.data['updated'] as Timestamp).seconds.toString()
              : '';
          _avatarFinalUrl = '$userImage?size=medium&t=$userLastUpdate';
          previewImage = NetworkImage(_avatarFinalUrl!);
          return;
        }
      } catch (error) {
        if (kDebugMode) print(error);
      }

      previewImage = defaultImage;
    }

    refreshImage();
    updateUser() async {
      assert(nameFirst != null, 'First Name must be defined');
      assert(nameLast != null, 'Last Name must be defined');
      assert(changed, 'No changes detected');
      loading = true;
      alert.show(AlertData(
        body: locales.get('notification--please-wait'),
        duration: 4,
        clear: true,
      ));
      if (nameFirst!.isEmpty) {
        loading = false;
        if (mounted) setState(() {});
        alert.show(AlertData(
          body: locales.get('label--too-short', {
            'label': locales.get('label--first-name'),
            'number': '3',
          }),
          type: AlertType.critical,
          clear: true,
        ));
        return;
      }
      if (nameLast!.isEmpty) {
        loading = false;
        if (mounted) setState(() {});
        alert.show(AlertData(
          body: locales.get('label--too-short', {
            'label': locales.get('label--last-name'),
            'number': '3',
          }),
          type: AlertType.critical,
          clear: true,
        ));
        return;
      }
      Map<String, dynamic> newData = {
        'firstName': nameFirst!,
        'lastName': nameLast!,
      };
      try {
        if (_temporalImageBytes != null) {
          String base64Image = base64Encode(_temporalImageBytes!);
          String photoURL = base64Image;
          newData.addAll({
            'avatar': photoURL,
          });
        }
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('user-actions-update');
        await callable.call(newData);
        _temporalImageBytes = null;
        changed = false;
        alert.show(AlertData(
          body: locales.get('page-profile--alert--profile-updated'),
          type: AlertType.success,
          clear: true,
        ));
        refreshImage();
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
      }
      loading = false;
      if (mounted) setState(() {});
    }

    Future<void> getImageFromOrigin(MediaOrigin origin) async {
      loading = true;
      if (mounted) setState(() {});
      try {
        final imageSelected = await MediaHelper.getImage(origin: origin);
        _temporalImageBytes = base64Decode(imageSelected.data);
        if (_temporalImageBytes != null) {
          changed = _temporalImageBytes != null;
        }
      } catch (error) {
        String errorMessage = error.toString();
        final errorType = errorMessage == 'alert--no-chosen-files'
            ? AlertType.warning
            : AlertType.critical;
        alert.show(AlertData(
          body: locales.get(errorMessage),
          type: errorType,
          duration: 5,
          clear: true,
        ));
      }
      loading = false;
      if (mounted) setState(() {});
    }

    final readyToSave = changed &&
        !loading &&
        ((nameFirst ?? '').length > 1 && (nameLast ?? '').length > 1);
    return ListView(
      padding: const EdgeInsets.only(bottom: 64, left: 16, right: 16, top: 16),
      children: <Widget>[
        ContentContainer(
          size: ContentContainerSize.small,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
            child: AspectRatio(
              aspectRatio: 1 / 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: RawMaterialButton(
                    hoverColor: Colors.transparent,
                    onPressed: _temporalImageBytes == null
                        ? () async {
                            Navigator.pushNamed(context, '/hero',
                                arguments: {'url': userImage});
                          }
                        : null,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 100, maxWidth: 300),
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
                                  tooltip: locales.get('label--gallery'),
                                  backgroundColor: Colors.grey.shade50,
                                  heroTag: 'image',
                                  onPressed: loading
                                      ? null
                                      : () async {
                                          await getImageFromOrigin(
                                              MediaOrigin.gallery);
                                        },
                                  child: Icon(
                                    Icons.image,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                              !kIsWeb
                                  ? Positioned(
                                      bottom: 0,
                                      right: 15,
                                      child: FloatingActionButton(
                                        heroTag: 'camera',
                                        tooltip: locales.get('label--camera'),
                                        onPressed: loading
                                            ? null
                                            : () async {
                                                await getImageFromOrigin(
                                                    MediaOrigin.camera);
                                              },
                                        child: const Icon(Icons.photo_camera),
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
        ),
        // First Name
        ContentContainer(
          size: ContentContainerSize.small,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InputData(
            disabled: loading,
            maxLength: 35,
            type: InputDataType.string,
            value: nameFirst,
            label: locales.get('label--first-name'),
            onChanged: (newValue) {
              String value = newValue?.toString() ?? '';
              // Remove invalid characters
              value = value.replaceAll(RegExp(r'[0-9!@#$%^*()_+={}<>~]'), '');
              if (stateUser.serialized.firstName == value) return;
              nameFirst = value;
              changed = true;
              if (mounted) setState(() {});
            },
          ),
        ),
        // Last Name
        ContentContainer(
          size: ContentContainerSize.small,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InputData(
            disabled: loading,
            maxLength: 35,
            type: InputDataType.string,
            value: nameLast,
            label: locales.get('label--last-name'),
            onChanged: (newValue) {
              String value = newValue?.toString() ?? '';
              // Remove invalid characters
              value = value.replaceAll(RegExp(r'[0-9!@#$%^*()_+={}<>~]'), '');
              if (stateUser.serialized.lastName == value) return;
              nameLast = value;
              changed = true;
              if (mounted) setState(() {});
            },
          ),
        ),
        const SizedBox(height: 32),
        ContentContainer(
          size: ContentContainerSize.small,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FilledButton.icon(
            key: const Key('update-button'),
            label: Text(locales.get('label--update')),
            onPressed: readyToSave ? updateUser : null,
            icon: const Icon(Icons.save),
          ),
        ),
      ],
    );
  }
}
