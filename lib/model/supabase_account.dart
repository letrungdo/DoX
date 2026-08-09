/// Credentials for a Do X account that has signed in successfully before.
///
/// Instances are persisted only through FlutterSecureStorage. Keeping this as
/// a small model also lets the storage service migrate the old single-account
/// JSON format without leaking that detail into the login screen.
class SupabaseAccount {
  const SupabaseAccount({required this.email, required this.password});

  final String email;
  final String password;

  factory SupabaseAccount.fromJson(Map<String, dynamic> json) =>
      SupabaseAccount(
        email: json['email'] as String,
        password: json['password'] as String,
      );

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}
