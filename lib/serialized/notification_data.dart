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
  UserOS? os;
  String? typeString;
  @JsonKey(includeIfNull: true)
  int duration;

  NotificationData({
    this.title,
    this.body,
    this.imageUrl,
    this.type,
    this.path,
    this.clear = false,
    this.os,
    this.typeString,
    this.duration = 5,
  });

  factory NotificationData.fromJson(Map<String, dynamic>? json) =>
      _$NotificationDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$NotificationDataToJson(this);
}
