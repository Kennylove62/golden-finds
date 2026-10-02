class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? whatsappNumber;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.whatsappNumber,
  });

  bool get isClient {
    return role.trim().toLowerCase() == 'client';
  }

  bool get isSeller {
    return role.trim().toLowerCase() == 'seller';
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'whatsappNumber': whatsappNumber,
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? whatsappNumber,
    bool clearWhatsappNumber = false,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      whatsappNumber: clearWhatsappNumber
          ? null
          : whatsappNumber ?? this.whatsappNumber,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: (map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: (map['role'] ?? 'client').toString(),
      whatsappNumber: map['whatsappNumber']?.toString(),
    );
  }
}
