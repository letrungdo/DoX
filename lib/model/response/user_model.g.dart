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

  UserModel expiresIn(int? expiresIn);

  UserModel expiryTime(int? expiryTime);

  UserModel password(String? password);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `UserModel(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// UserModel(...).copyWith(id: 12, name: "My name")
  /// ```
  UserModel call({
    String? kind,
    String? localId,
    String? email,
    String? displayName,
    String? idToken,
    bool? registered,
    String? profilePicture,
    String? refreshToken,
    int? expiresIn,
    int? expiryTime,
    String? password,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfUserModel.copyWith(...)` or call `instanceOfUserModel.copyWith.fieldName(value)` for a single field.
class _$UserModelCWProxyImpl implements _$UserModelCWProxy {
  const _$UserModelCWProxyImpl(this._value);

  final UserModel _value;

  @override
  UserModel kind(String? kind) => call(kind: kind);

  @override
  UserModel localId(String? localId) => call(localId: localId);

  @override
  UserModel email(String? email) => call(email: email);

  @override
  UserModel displayName(String? displayName) => call(displayName: displayName);

  @override
  UserModel idToken(String? idToken) => call(idToken: idToken);

  @override
  UserModel registered(bool? registered) => call(registered: registered);

  @override
  UserModel profilePicture(String? profilePicture) =>
      call(profilePicture: profilePicture);

  @override
  UserModel refreshToken(String? refreshToken) =>
      call(refreshToken: refreshToken);

  @override
  UserModel expiresIn(int? expiresIn) => call(expiresIn: expiresIn);

  @override
  UserModel expiryTime(int? expiryTime) => call(expiryTime: expiryTime);

  @override
  UserModel password(String? password) => call(password: password);

  @override
  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `UserModel(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// UserModel(...).copyWith(id: 12, name: "My name")
  /// ```
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
    Object? expiryTime = const $CopyWithPlaceholder(),
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
              : expiresIn as int?,
      expiryTime:
          expiryTime == const $CopyWithPlaceholder()
              ? _value.expiryTime
              // ignore: cast_nullable_to_non_nullable
              : expiryTime as int?,
      password:
          password == const $CopyWithPlaceholder()
              ? _value.password
              // ignore: cast_nullable_to_non_nullable
              : password as String?,
    );
  }
}

extension $UserModelCopyWith on UserModel {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfUserModel.copyWith(...)` or `instanceOfUserModel.copyWith.fieldName(...)`.
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
  expiresIn: const StringToIntConverter().fromJson(json['expiresIn']),
  expiryTime: (json['expiryTime'] as num?)?.toInt(),
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
  'expiresIn': const StringToIntConverter().toJson(instance.expiresIn),
  'expiryTime': instance.expiryTime,
  'password': instance.password,
};
