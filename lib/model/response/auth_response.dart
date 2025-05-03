import 'package:json_annotation/json_annotation.dart';

part 'auth_response.g.dart';

@JsonSerializable(explicitToJson: true)
class AuthResponse {
  @JsonKey(name: "access_token")
  final String? accessToken;

  @JsonKey(name: "expires_in")
  final String? expiresIn;

  @JsonKey(name: "token_type")
  final String? tokenType;

  @JsonKey(name: "refresh_token")
  final String? refreshToken;

  @JsonKey(name: "id_token")
  final String? idToken;

  @JsonKey(name: "user_id")
  final String? userId;

  @JsonKey(name: "project_id")
  final String? projectId;

  const AuthResponse({
    this.accessToken, //
    this.expiresIn,
    this.tokenType,
    this.refreshToken,
    this.idToken,
    this.userId,
    this.projectId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}
