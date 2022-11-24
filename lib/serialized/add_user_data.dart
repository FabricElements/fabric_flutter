import 'package:json_annotation/json_annotation.dart';

part 'add_user_data.g.dart';

@JsonSerializable(explicitToJson: true)
class AddUserData {
  @JsonKey(includeIfNull: false)
  String? firstName;
  @JsonKey(includeIfNull: false)
  String? lastName;
  @JsonKey(includeIfNull: false)
  String? email;
  @JsonKey(includeIfNull: false)
  String? phone;
  @JsonKey(includeIfNull: false)
  String? username;
  @JsonKey(includeIfNull: false)
  String? role;
  @JsonKey(includeIfNull: false)
  String? uid;
  @JsonKey(includeIfNull: false)
  Map<String, dynamic>? data;

  AddUserData({
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.phone,
    this.role,
    this.uid,
    this.data,
  });

  factory AddUserData.fromJson(Map<String, dynamic>? json) =>
      _$AddUserDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$AddUserDataToJson(this);
}
