/// The user's profile as stored by the backend. The email isn't part of it:
/// that comes from the signed-in account ([AccountInfo]).
class UserProfile {
  final String displayName;
  final String? phone;
  // Firebase Storage path of an uploaded photo.
  final String? photoStoragePath;
  // Id of a built-in avatar (see avatars.dart). At most one of photo/avatar.
  final String? avatarId;

  const UserProfile({
    required this.displayName,
    this.phone,
    this.photoStoragePath,
    this.avatarId,
  });

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'phone': phone,
        'photo_storage_path': photoStoragePath,
        'avatar_id': avatarId,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        displayName: json['display_name'] as String,
        phone: json['phone'] as String?,
        photoStoragePath: json['photo_storage_path'] as String?,
        avatarId: json['avatar_id'] as String?,
      );
}

/// What the sign-in provider (Google) tells us about the account. Used to
/// prefill the profile and show the email.
class AccountInfo {
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AccountInfo({this.email, this.displayName, this.photoUrl});
}
