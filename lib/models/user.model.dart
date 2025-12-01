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

  // Thông tin sinh viên
  final String? mssv;
  final String? course;
  final String? major;

  final int friendsCount;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final List<String> favorites;

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
    this.mssv,
    this.course,
    this.major,
    List<String>? favorites,
    this.friendsCount = 0,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  }) : favorites = favorites ?? const [];

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
      mssv: json['mssv']?.toString(),
      course: json['course']?.toString(),
      major: json['major']?.toString(),
      favorites:
          (json['favorites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      friendsCount: _toInt(json['friendsCount'] ?? json['friends_count']),
      postsCount: _toInt(json['postsCount'] ?? json['posts_count']),
      followersCount: _toInt(json['followersCount'] ?? json['followers_count']),
      followingCount: _toInt(json['followingCount'] ?? json['following_count']),
    );
  }

  /// Serialize full object nếu cần
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'bio': bio,
      'avatar_url': avatar,
      'gender': gender,
      'address': address,
      'phone': phone,
      'dob': dob,
      'mssv': mssv,
      'course': course,
      'major': major,
      'friendsCount': friendsCount,
      'postsCount': postsCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'favorites': favorites,
    };
  }

  /// Body gửi cho API update profile
  Map<String, dynamic> toUpdateJson() {
    String _normalizedUsername() {
      String u = (username ?? '').trim();
      if (u.startsWith('@')) {
        u = u.substring(1);
      }
      return u;
    }

    return {
      'username': _normalizedUsername(),
      'firstName': firstName,
      'lastName': lastName,
      'gender': (gender == null || gender!.trim().isEmpty) ? 'Khác' : gender,
      'avatar_url': avatar ?? '',
      'bio': bio ?? '',
      'address': address ?? '',
      'phone': phone ?? '',
      'dob': dob ?? '',
      'mssv': mssv ?? '',
      'course': course ?? '',
      'major': major ?? '',
      'favorites': favorites,
    };
  }
}
