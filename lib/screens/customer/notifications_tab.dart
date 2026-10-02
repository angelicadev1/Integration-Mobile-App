import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/constants.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = BankingRepository();
    final notifs = repo.currentNotifications;

    return RefreshIndicator(
      color: AppColors.primaryViolet,
      onRefresh: () => repo.refreshUserData(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications & Alerts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.plumCard),
                ),
                if (repo.unreadNotificationCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.magentaLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.magentaHot.withAlpha(80)),
                    ),
                    child: Text(
                      '${repo.unreadNotificationCount} Unread',
                      style: const TextStyle(
                        color: AppColors.magentaHot,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Security alerts, transaction receipts, and system events',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: notifs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No notifications yet.', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: notifs.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final notif = notifs[i];
                        return Card(
                          elevation: notif.isRead ? 0 : 2,
                          shadowColor: notif.isRead ? Colors.transparent : AppColors.primaryViolet.withAlpha(30),
                          color: notif.isRead ? Colors.white : AppColors.violetSubtle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: notif.isRead ? Colors.grey.shade200 : AppColors.primaryViolet.withAlpha(100),
                              width: notif.isRead ? 1 : 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              repo.markNotificationAsRead(notif.notifId);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: notif.isRead ? Colors.grey.shade100 : AppColors.primaryViolet.withAlpha(30),
                                    child: Icon(
                                      notif.isRead ? Icons.notifications_none : Icons.notifications_active,
                                      color: notif.isRead ? Colors.grey.shade600 : AppColors.primaryViolet,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif.message,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                            color: notif.isRead ? Colors.black87 : AppColors.plumCard,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          AppConstants.formatDateTime(notif.createdAt),
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!notif.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.magentaHot,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
