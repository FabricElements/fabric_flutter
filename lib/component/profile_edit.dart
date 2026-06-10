import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/media_helper.dart';
import '../state/state_user.dart';
import 'alert_data.dart';
import 'content_container.dart';
import 'input_data.dart';

/// Builds a profile editor for the authenticated user.
///
/// The widget stores staged name changes and avatar bytes locally so the wider
/// page can rebuild without discarding edits before the user saves them.
class ProfileEdit extends StatefulWidget {
  /// Creates a profile editor for the authenticated user.
  ///
  /// The optional [loader] lets parent layouts supply a custom busy widget, and
  /// [prefix] prepends a base URL to stored avatar paths when needed.
  const ProfileEdit({super.key, this.loader, this.prefix});

  /// Stores an optional loading widget for parent compositions.
  ///
  /// The current implementation does not render [loader] directly, but keeping
  /// it on the widget preserves compatibility with surrounding layouts.
  final Widget? loader;

  /// Stores an optional base path for remote avatar URLs.
  ///
  /// When [prefix] is not `null` and the user has an avatar path, the build
  /// logic joins both values before requesting the preview image.
  final String? prefix;

  /// Creates mutable editing state for names and avatar previews.
  ///
  /// Flutter calls this when inserting [ProfileEdit] into the tree so the form
  /// can track staged values independently from persisted user data.
  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

/// Stores staged profile edits and avatar preview data for [ProfileEdit].
///
/// The state keeps temporary text values, image bytes, and loading flags so the
/// widget can coordinate local validation and asynchronous updates.
class _ProfileEditState extends State<ProfileEdit> {
  /// Tracks whether the current form values differ from persisted user data.
  ///
  /// The save button becomes available only after [changed] is `true` and the
  /// required name fields satisfy the minimum length check.
  late bool changed;

  /// Stores the fallback avatar image used when no user image is available.
  ///
  /// The widget falls back to [defaultImage] when preview generation fails or no
  /// saved avatar exists for the current user.
  AssetImage? defaultImage;

  /// Tracks whether the widget is currently processing user actions.
  ///
  /// While [loading] is `true`, save and media-picking controls are disabled to
  /// avoid duplicate requests and inconsistent local state.
  late bool loading;

  /// Stores the image provider displayed by the avatar preview.
  ///
  /// The preview switches between a [MemoryImage], a [NetworkImage], or the
  /// fallback asset depending on the most recent available avatar source.
  ImageProvider? previewImage;

  /// Stores newly selected avatar bytes until the user saves the profile.
  ///
  /// Keeping the raw bytes in [_temporalImageBytes] allows the UI to preview a
  /// local selection before it is uploaded through Cloud Functions.
  Uint8List? _temporalImageBytes;

  /// Stores the resolved remote avatar path for the authenticated user.
  ///
  /// The build logic derives [userImage] from the serialized user record and the
  /// optional widget [ProfileEdit.prefix].
  String? userImage;

  /// Stores the staged first-name value.
  ///
  /// A `null` value means the field has not yet diverged from the current user
  /// record during this widget lifecycle.
  String? nameFirst;

  /// Stores the staged last-name value.
  ///
  /// A `null` value means the field has not yet diverged from the current user
  /// record during this widget lifecycle.
  String? nameLast;

  /// Stores the cache-busted avatar URL used for preview refreshes.
  ///
  /// Appending the user's updated timestamp helps force a fresh network image
  /// whenever the avatar changes remotely.
  String? _avatarFinalUrl;

  /// Initializes the editor with default loading, change, and avatar values.
  ///
  /// The initial state keeps both name fields at `null` so the first build can
  /// hydrate them from the current [StateUser] snapshot.
  @override
  void initState() {
    super.initState();
    loading = false;
    changed = false;
    defaultImage = const AssetImage('assets/placeholder.jpg');
    nameFirst = null;
    nameLast = null;
  }

  /// Builds the profile editing form for the current [BuildContext].
  ///
  /// The build pass resolves localized labels, derives the latest avatar source,
  /// and wires form actions that stage edits locally before persisting them.
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final stateUser = Provider.of<StateUser>(context, listen: false);
    userImage = widget.prefix != null && stateUser.serialized.avatar != null
        ? '${widget.prefix}/${stateUser.serialized.avatar}'
        : stateUser.serialized.avatar;
    if (!changed) {
      nameFirst = nameFirst ?? stateUser.serialized.firstName;
      nameLast = nameLast ?? stateUser.serialized.lastName;
    }

    /// Refreshes the avatar preview using staged bytes or persisted user data.
    ///
    /// The helper prefers local image bytes, then a cache-busted network URL,
    /// and finally falls back to [defaultImage] when no preview can be derived.
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
        debugPrint(LogColor.error(error));
      }

      previewImage = defaultImage;
    }

    refreshImage();

    /// Persists staged profile changes for the authenticated user.
    ///
    /// The handler validates required names, optionally encodes the staged avatar
    /// as base64, calls the `user-actions-update` function, and reports the
    /// result through localized alerts.
    updateUser() async {
      assert(nameFirst != null, 'First Name must be defined');
      assert(nameLast != null, 'Last Name must be defined');
      assert(changed, 'No changes detected');
      loading = true;
      alertData(
        context: context,
        body: locales.get('notification--please-wait'),
        duration: 4,
      );
      if (nameFirst!.isEmpty) {
        loading = false;
        if (mounted) setState(() {});
        alertData(
          context: context,
          body: locales.get('label--too-short', {
            'label': locales.get('label--first-name'),
            'number': '3',
          }),
          type: AlertType.critical,
        );
        return;
      }
      if (nameLast!.isEmpty) {
        loading = false;
        if (mounted) setState(() {});
        alertData(
          context: context,
          body: locales.get('label--too-short', {
            'label': locales.get('label--last-name'),
            'number': '3',
          }),
          type: AlertType.critical,
        );
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
          newData.addAll({'avatar': photoURL});
        }
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'user-actions-update',
        );
        await callable.call(newData);
        _temporalImageBytes = null;
        changed = false;
        refreshImage();
        if (!context.mounted) return;
        alertData(
          context: context,
          body: locales.get('page-profile--alert--profile-updated'),
          type: AlertType.success,
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
      loading = false;
      if (mounted) setState(() {});
    }

    /// Loads avatar bytes from the requested [MediaOrigin].
    ///
    /// The handler updates [_temporalImageBytes] when selection succeeds and
    /// surfaces localized warnings or errors when media selection fails.
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
        alertData(
          context: context,
          body: locales.get(errorMessage),
          type: errorType,
          duration: 5,
        );
      }
      loading = false;
      if (mounted) setState(() {});
    }

    final readyToSave =
        changed &&
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
                            Navigator.pushNamed(
                              context,
                              '/hero',
                              arguments: {'url': userImage},
                            );
                          }
                        : null,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 100,
                        maxWidth: 300,
                      ),
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
                                            MediaOrigin.gallery,
                                          );
                                        },
                                  child: Icon(
                                    Icons.image,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
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
                                                  MediaOrigin.camera,
                                                );
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
        ContentContainer(
          size: ContentContainerSize.small,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InputData(
            autofillHints: const [AutofillHints.givenName],
            disabled: loading,
            maxLength: 35,
            type: InputDataType.string,
            value: nameFirst,
            label: locales.get('label--first-name'),
            onChanged: (newValue) {
              String value = newValue?.toString() ?? '';
              value = value.replaceAll(RegExp(r'[0-9!@#$%^*()_+={}<>~]'), '');
              if (stateUser.serialized.firstName == value) return;
              nameFirst = value;
              changed = true;
              if (mounted) setState(() {});
            },
          ),
        ),
        ContentContainer(
          size: ContentContainerSize.small,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InputData(
            autofillHints: const [AutofillHints.familyName],
            disabled: loading,
            maxLength: 35,
            type: InputDataType.string,
            value: nameLast,
            label: locales.get('label--last-name'),
            onChanged: (newValue) {
              String value = newValue?.toString() ?? '';
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
