enum UserRole {
  customer,
  admin,
}

enum KycStatus {
  verified,
  pendingVerification,
  rejected,
}

class UserSession {
  final String customerId;
  final String email;
  final String fullName;
  final UserRole role;
  final String token;
  final KycStatus kycStatus;

  final String phoneNumber;

  UserSession({
    required this.customerId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.token,
    this.kycStatus = KycStatus.verified,
    this.phoneNumber = '+63 917 123 4567',
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isCustomer => role == UserRole.customer;
  String get contactNo => phoneNumber;

  factory UserSession.fromJson(Map<String, dynamic> json, String token) {
    final roleStr = (json['role'] ?? 'CUSTOMER').toString().toUpperCase();
    final role = roleStr.contains('ADMIN') ? UserRole.admin : UserRole.customer;
    final email = json['email'] ?? '';
    final name = '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim();
    final phone = json['phoneNumber'] ?? json['contactNo'] ?? '+63 917 123 4567';

    return UserSession(
      customerId: json['customerId'] ?? '',
      email: email,
      fullName: name.isNotEmpty ? name : email,
      role: role,
      token: token,
      kycStatus: KycStatus.verified,
      phoneNumber: phone,
    );
  }
}
