class UserModel {
  final String kind;
  final String localId;
  final String email;
  final String? displayName;
  final String idToken;
  final bool registered;
  final String? profilePicture;
  final String refreshToken;
  final String expiresIn;

  const UserModel({
    required this.kind,
    required this.localId,
    required this.email,
    this.displayName,
    required this.idToken,
    required this.registered,
    this.profilePicture,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      kind: json['kind'] as String,
      localId: json['localId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      idToken: json['idToken'] as String,
      registered: json['registered'] as bool,
      profilePicture: json['profilePicture'] as String?,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'localId': localId,
      'email': email,
      'displayName': displayName,
      'idToken': idToken,
      'registered': registered,
      'profilePicture': profilePicture,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
    };
  }
}
