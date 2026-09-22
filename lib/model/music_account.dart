/// A music service account signed in on this device, with the token every
/// personal endpoint (likes, play history) is called with.
class MusicAccount {
  const MusicAccount({
    required this.accessToken,
    required this.userId,
    this.username = '',
    this.avatarUrl = '',
  });

  factory MusicAccount.fromJson(Map<String, dynamic> json) {
    return MusicAccount(
      accessToken: json['accessToken']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
    );
  }

  final String accessToken;
  final String userId;
  final String username;
  final String avatarUrl;

  /// What the API expects in `Authorization`, in the service's own scheme.
  String get authorizationHeader => 'OAuth $accessToken';

  bool get isValid => accessToken.isNotEmpty && userId.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'userId': userId,
    'username': username,
    'avatarUrl': avatarUrl,
  };
}
