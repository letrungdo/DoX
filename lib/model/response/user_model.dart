import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@CopyWith()
@JsonSerializable(explicitToJson: true)
class UserModel {
  final String? kind;
  final String? localId;
  final String? email;
  final String? displayName;
  final String? idToken;
  final bool? registered;
  final String? profilePicture;
  final String? refreshToken;
  final String? expiresIn;
  final String? password;

  const UserModel({
    this.kind,
    this.localId,
    this.email,
    this.displayName,
    this.idToken,
    this.registered,
    this.profilePicture,
    this.refreshToken,
    this.expiresIn,
    this.password,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
