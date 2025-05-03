// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UserModelCWProxy {
  UserModel kind(String? kind);

  UserModel localId(String? localId);

  UserModel email(String? email);

  UserModel displayName(String? displayName);

  UserModel idToken(String? idToken);

  UserModel registered(bool? registered);

  UserModel profilePicture(String? profilePicture);

  UserModel refreshToken(String? refreshToken);

  UserModel expiresIn(String? expiresIn);

  UserModel password(String? password);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UserModel(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UserModel(...).copyWith(id: 12, name: "My name")
  /// ````
  UserModel call({
    String? kind,
    String? localId,
    String? email,
    String? displayName,
    String? idToken,
    bool? registered,
    String? profilePicture,
    String? refreshToken,
    String? expiresIn,
    String? password,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUserModel.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUserModel.copyWith.fieldName(...)`
class _$UserModelCWProxyImpl implements _$UserModelCWProxy {
  const _$UserModelCWProxyImpl(this._value);

  final UserModel _value;

  @override
  UserModel kind(String? kind) => this(kind: kind);

  @override
  UserModel localId(String? localId) => this(localId: localId);

  @override
  UserModel email(String? email) => this(email: email);

  @override
  UserModel displayName(String? displayName) => this(displayName: displayName);

  @override
  UserModel idToken(String? idToken) => this(idToken: idToken);

  @override
  UserModel registered(bool? registered) => this(registered: registered);

  @override
  UserModel profilePicture(String? profilePicture) =>
      this(profilePicture: profilePicture);

  @override
  UserModel refreshToken(String? refreshToken) =>
      this(refreshToken: refreshToken);

  @override
  UserModel expiresIn(String? expiresIn) => this(expiresIn: expiresIn);

  @override
  UserModel password(String? password) => this(password: password);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UserModel(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UserModel(...).copyWith(id: 12, name: "My name")
  /// ````
  UserModel call({
    Object? kind = const $CopyWithPlaceholder(),
    Object? localId = const $CopyWithPlaceholder(),
    Object? email = const $CopyWithPlaceholder(),
    Object? displayName = const $CopyWithPlaceholder(),
    Object? idToken = const $CopyWithPlaceholder(),
    Object? registered = const $CopyWithPlaceholder(),
    Object? profilePicture = const $CopyWithPlaceholder(),
    Object? refreshToken = const $CopyWithPlaceholder(),
    Object? expiresIn = const $CopyWithPlaceholder(),
    Object? password = const $CopyWithPlaceholder(),
  }) {
    return UserModel(
      kind:
          kind == const $CopyWithPlaceholder()
              ? _value.kind
              // ignore: cast_nullable_to_non_nullable
              : kind as String?,
      localId:
          localId == const $CopyWithPlaceholder()
              ? _value.localId
              // ignore: cast_nullable_to_non_nullable
              : localId as String?,
      email:
          email == const $CopyWithPlaceholder()
              ? _value.email
              // ignore: cast_nullable_to_non_nullable
              : email as String?,
      displayName:
          displayName == const $CopyWithPlaceholder()
              ? _value.displayName
              // ignore: cast_nullable_to_non_nullable
              : displayName as String?,
      idToken:
          idToken == const $CopyWithPlaceholder()
              ? _value.idToken
              // ignore: cast_nullable_to_non_nullable
              : idToken as String?,
      registered:
          registered == const $CopyWithPlaceholder()
              ? _value.registered
              // ignore: cast_nullable_to_non_nullable
              : registered as bool?,
      profilePicture:
          profilePicture == const $CopyWithPlaceholder()
              ? _value.profilePicture
              // ignore: cast_nullable_to_non_nullable
              : profilePicture as String?,
      refreshToken:
          refreshToken == const $CopyWithPlaceholder()
              ? _value.refreshToken
              // ignore: cast_nullable_to_non_nullable
              : refreshToken as String?,
      expiresIn:
          expiresIn == const $CopyWithPlaceholder()
              ? _value.expiresIn
              // ignore: cast_nullable_to_non_nullable
              : expiresIn as String?,
      password:
          password == const $CopyWithPlaceholder()
              ? _value.password
              // ignore: cast_nullable_to_non_nullable
              : password as String?,
    );
  }
}

extension $UserModelCopyWith on UserModel {
  /// Returns a callable class that can be used as follows: `instanceOfUserModel.copyWith(...)` or like so:`instanceOfUserModel.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UserModelCWProxy get copyWith => _$UserModelCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  kind: json['kind'] as String?,
  localId: json['localId'] as String?,
  email: json['email'] as String?,
  displayName: json['displayName'] as String?,
  idToken: json['idToken'] as String?,
  registered: json['registered'] as bool?,
  profilePicture: json['profilePicture'] as String?,
  refreshToken: json['refreshToken'] as String?,
  expiresIn: json['expiresIn'] as String?,
  password: json['password'] as String?,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'kind': instance.kind,
  'localId': instance.localId,
  'email': instance.email,
  'displayName': instance.displayName,
  'idToken': instance.idToken,
  'registered': instance.registered,
  'profilePicture': instance.profilePicture,
  'refreshToken': instance.refreshToken,
  'expiresIn': instance.expiresIn,
  'password': instance.password,
};
