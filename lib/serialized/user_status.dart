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

  UserStatus({
    this.signedIn = false,
    this.admin = false,
    this.role = 'user',
    this.uid,
  });

  factory UserStatus.fromJson(Map<String, dynamic>? json) =>
      _$UserStatusFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$UserStatusToJson(this);
}
