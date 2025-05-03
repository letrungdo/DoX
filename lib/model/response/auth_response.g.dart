// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
  accessToken: json['access_token'] as String?,
  expiresIn: const StringToIntConverter().fromJson(json['expires_in']),
  tokenType: json['token_type'] as String?,
  refreshToken: json['refresh_token'] as String?,
  idToken: json['id_token'] as String?,
  userId: json['user_id'] as String?,
  projectId: json['project_id'] as String?,
);

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'expires_in': const StringToIntConverter().toJson(instance.expiresIn),
      'token_type': instance.tokenType,
      'refresh_token': instance.refreshToken,
      'id_token': instance.idToken,
      'user_id': instance.userId,
      'project_id': instance.projectId,
    };
