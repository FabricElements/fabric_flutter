import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_data.g.dart';

/// Stores a serialized notification payload.
///
/// This model is used to move notification content between transport layers and
/// UI presentation logic while preserving delivery and routing metadata.
@JsonSerializable(explicitToJson: true)
class NotificationData {
  /// Stores the notification title shown to the user.
  String? title;

  /// Stores the notification body text.
  String? body;

  /// Stores an optional image URL displayed with the notification.
  String? imageUrl;

  /// Stores the notification type understood by the application.
  String? type;

  /// Stores the navigation target associated with the notification.
  String? path;

  /// Indicates whether existing notifications should be cleared first.
  @JsonKey(includeIfNull: true)
  bool clear;

  /// Stores the target operating system for platform-specific delivery logic.
  @JsonKey(includeIfNull: true, unknownEnumValue: UserOS.unknown)
  UserOS os;

  /// Stores an alternate string form of the notification type.
  ///
  /// This is useful when the transport source uses a custom discriminator that
  /// does not map directly to [type].
  String? typeString;

  /// Stores the display duration in seconds.
  @JsonKey(includeIfNull: true)
  int duration;

  /// Stores the associated account identifier when notifications are scoped.
  @JsonKey(includeIfNull: false)
  String? account;

  /// Stores the unique notification identifier when available.
  @JsonKey(includeIfNull: false)
  String? id;

  /// Stores the origin system that emitted the notification.
  @JsonKey(includeIfNull: false)
  String? origin;

  /// Creates a serialized notification payload.
  NotificationData({
    this.title,
    this.body,
    this.imageUrl,
    this.type,
    this.path,
    this.clear = false,
    this.os = UserOS.unknown,
    this.typeString,
    this.duration = 5,
    this.account,
    this.id,
    this.origin,
  });

  /// Builds [NotificationData] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so optional notifications can be
  /// deserialized with predictable defaults.
  factory NotificationData.fromJson(Map<String, dynamic>? json) =>
      _$NotificationDataFromJson(json ?? {});

  /// Converts this notification payload into JSON.
  Map<String, dynamic> toJson() => _$NotificationDataToJson(this);
}
