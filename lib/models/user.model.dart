// lib/models/user.model.dart

class UserProfile {
  final String id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;

  final String? bio;
  final String? avatar;
  final String? gender;
  final String? address;
  final String? phone;
  final String? dob;

  final int friendsCount;
  final int postsCount;
  final int followersCount;
  final int followingCount;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.bio,
    this.avatar,
    this.gender,
    this.address,
    this.phone,
    this.dob,
    this.friendsCount = 0,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  /// Helper convert dynamic -> int an toàn
  static int _toInt(dynamic v, {int defaultValue = 0}) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? json['firstName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      bio: json['bio'],
      avatar: json['avatar_url'],
      gender: json['gender'],
      address: json['address'],
      phone: json['phone'],
      dob: json['dob'] ?? json['date_of_birth'],

      friendsCount: _toInt(json['friendsCount'] ?? json['friends_count']),
      postsCount: _toInt(json['postsCount'] ?? json['posts_count']),
      followersCount: _toInt(json['followersCount'] ?? json['followers_count']),
      followingCount: _toInt(json['followingCount'] ?? json['following_count']),
    );
  }

  /// Dùng khi cần serialize full object (nếu cần)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'bio': bio,
      'avatar_url': avatar,
      'gender': gender,
      'address': address,
      'phone': phone,
      'dob': dob,
      'friendsCount': friendsCount,
      'postsCount': postsCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }

  /// Dùng riêng cho API update profile
  /// (giống kiểu toUpdateJson cũ của bạn)
  Map<String, dynamic> toUpdateJson() {
    return {
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'bio': bio,
      'avatar_url': avatar,
      'gender': gender,
      'address': address,
      'phone': phone,
      'dob': dob,
    };
  }
}
