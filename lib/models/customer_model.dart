import 'user_session.dart';

class CustomerModel {
  final String customerId;
  final String firstName;
  final String lastName;
  final String email;
  final String contactNo;
  final DateTime birthDate;
  final String idType;
  final String idNumber;
  final String address;
  final KycStatus kycStatus;
  final DateTime createdAt;

  CustomerModel({
    required this.customerId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.contactNo,
    required this.birthDate,
    required this.idType,
    required this.idNumber,
    required this.address,
    required this.kycStatus,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get kycStatusLabel {
    switch (kycStatus) {
      case KycStatus.verified:
        return 'VERIFIED';
      case KycStatus.pendingVerification:
        return 'PENDING REVIEW';
      case KycStatus.rejected:
        return 'REJECTED';
    }
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    DateTime bday;
    try {
      bday = json['birthDate'] != null ? DateTime.parse(json['birthDate'].toString()) : DateTime(1990, 1, 1);
    } catch (_) {
      bday = DateTime(1990, 1, 1);
    }

    DateTime created;
    try {
      created = json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now();
    } catch (_) {
      created = DateTime.now();
    }

    KycStatus status = KycStatus.verified;
    final kStr = (json['kycStatus'] ?? 'VERIFIED').toString().toUpperCase();
    if (kStr.contains('PEND')) {
      status = KycStatus.pendingVerification;
    } else if (kStr.contains('REJ')) {
      status = KycStatus.rejected;
    }

    return CustomerModel(
      customerId: json['customerId']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      contactNo: json['contactNo']?.toString() ?? '',
      birthDate: bday,
      idType: json['idType']?.toString() ?? 'Passport',
      idNumber: json['idNumber']?.toString() ?? 'P-12345678',
      address: json['address']?.toString() ?? 'Metro Manila, Philippines',
      kycStatus: status,
      createdAt: created,
    );
  }
}
