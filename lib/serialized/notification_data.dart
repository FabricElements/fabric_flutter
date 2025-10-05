import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_data.g.dart';

@JsonSerializable(explicitToJson: true)
class NotificationData {
  String? title;
  String? body;
  String? imageUrl;
  String? type;
  String? path;
  @JsonKey(includeIfNull: true)
  bool clear;
  @JsonKey(includeIfNull: true, unknownEnumValue: UserOS.unknown)
  UserOS os;
  String? typeString;
  @JsonKey(includeIfNull: true)
  int duration;
  @JsonKey(includeIfNull: false)
  String? account;
  @JsonKey(includeIfNull: false)
  String? id;
  @JsonKey(includeIfNull: false)
  String? origin;

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

  factory NotificationData.fromJson(Map<String, dynamic>? json) =>
      _$NotificationDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$NotificationDataToJson(this);
}
