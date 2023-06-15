import 'package:json_annotation/json_annotation.dart';

part 'user_status.g.dart';

@JsonSerializable(explicitToJson: true)
class UserStatus {
  @JsonKey(includeIfNull: false)
  bool signedIn;
  @JsonKey(includeIfNull: false)
  bool admin;
  @JsonKey(includeIfNull: true)
  String role;
  @JsonKey(includeIfNull: false)
  dynamic uid;
  @JsonKey(includeFromJson: false, includeToJson: false)
  DateTime? timestamp;

  UserStatus({
    this.signedIn = false,
    this.admin = false,
    this.role = 'user',
    this.uid,
    this.timestamp,
  });

  factory UserStatus.fromJson(Map<String, dynamic>? json) =>
      _$UserStatusFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserStatusToJson(this);
}
