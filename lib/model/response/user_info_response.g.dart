// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserInfoResponse _$UserInfoResponseFromJson(Map<String, dynamic> json) =>
    UserInfoResponse(
      result: UserInfoResult.fromJson(json['result'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserInfoResponseToJson(UserInfoResponse instance) =>
    <String, dynamic>{'result': instance.result.toJson()};

UserInfoResult _$UserInfoResultFromJson(Map<String, dynamic> json) =>
    UserInfoResult(
      status: (json['status'] as num?)?.toInt(),
      data: UserInfoData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserInfoResultToJson(UserInfoResult instance) =>
    <String, dynamic>{
      'status': instance.status,
      'data': instance.data.toJson(),
    };

UserInfoData _$UserInfoDataFromJson(Map<String, dynamic> json) => UserInfoData(
  uid: json['uid'] as String?,
  firstName: json['first_name'] as String,
  lastName: json['last_name'] as String,
  badge: json['badge'] as String?,
  profilePictureUrl: json['profile_picture_url'] as String?,
  temp: json['temp'] as bool?,
  username: json['username'] as String?,
);

Map<String, dynamic> _$UserInfoDataToJson(UserInfoData instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'badge': instance.badge,
      'profile_picture_url': instance.profilePictureUrl,
      'temp': instance.temp,
      'username': instance.username,
    };
