import 'package:json_annotation/json_annotation.dart';

part 'password_data.g.dart';

@JsonSerializable(explicitToJson: true)
class PasswordData {
  String currentPassword;
  String newPassword;

  PasswordData({required this.currentPassword, required this.newPassword});

  factory PasswordData.fromJson(Map<String, dynamic>? json) =>
      _$PasswordDataFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$PasswordDataToJson(this);
}
