import 'package:json_annotation/json_annotation.dart';

part 'user_info_response.g.dart';


@JsonSerializable(explicitToJson: true)
class UserInfoResponse {
  final UserInfoResult result;

  const UserInfoResponse({required this.result});

  factory UserInfoResponse.fromJson(Map<String, dynamic> json) => _$UserInfoResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserInfoResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class UserInfoResult {
  final int? status;
  final UserInfoData data;

  const UserInfoResult({required this.status, required this.data});

  factory UserInfoResult.fromJson(Map<String, dynamic> json) => _$UserInfoResultFromJson(json);

  Map<String, dynamic> toJson() => _$UserInfoResultToJson(this);
}

@JsonSerializable(explicitToJson: true)
class UserInfoData {
  final String? uid;

  @JsonKey(name: "first_name")
  final String firstName;

  @JsonKey(name: "last_name")
  final String lastName;

  final String? badge;

  @JsonKey(name: "profile_picture_url")
  final String? profilePictureUrl;

  final bool? temp;
  final String? username;

  const UserInfoData({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.badge,
    required this.profilePictureUrl,
    required this.temp,
    required this.username,
  });

  factory UserInfoData.fromJson(Map<String, dynamic> json) => _$UserInfoDataFromJson(json);

  Map<String, dynamic> toJson() => _$UserInfoDataToJson(this);
}
