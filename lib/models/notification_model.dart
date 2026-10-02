class NotificationModel {
  final String notifId;
  final String customerId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notifId,
    required this.customerId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      notifId: notifId,
      customerId: customerId,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime dt;
    try {
      dt = json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }

    final sStr = (json['status'] ?? 'UNREAD').toString().toUpperCase();

    return NotificationModel(
      notifId: json['notifId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: sStr == 'READ',
      createdAt: dt,
    );
  }
}
