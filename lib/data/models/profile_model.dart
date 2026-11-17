class ProfileModel {
  final String id;
  final String? fullName;
  final String? email;
  final String? profileImage;
  final String currency;
  final String? country;
  final String themeMode;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    this.fullName,
    this.email,
    this.profileImage,
    this.currency = 'INR',
    this.country,
    this.themeMode = 'system',
    this.createdAt,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      profileImage: map['profile_image'] as String?,
      currency: map['currency'] as String? ?? 'INR',
      country: map['country'] as String?,
      themeMode: map['theme_mode'] as String? ?? 'system',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'email': email,
      'profile_image': profileImage,
      'currency': currency,
      'country': country,
      'theme_mode': themeMode,
    };
  }

  ProfileModel copyWith({
    String? fullName,
    String? email,
    String? profileImage,
    String? currency,
    String? country,
    String? themeMode,
  }) {
    return ProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      currency: currency ?? this.currency,
      country: country ?? this.country,
      themeMode: themeMode ?? this.themeMode,
      createdAt: createdAt,
    );
  }
}
