import 'package:flutter/material.dart';
import '../models/app_notification_item.dart';
import '../models/banner_item.dart';
import '../services/api_service.dart';

class BannerNotificationProvider extends ChangeNotifier {
  List<BannerItemModel> _banners = [];
  List<AppNotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<BannerItemModel> get banners => _banners;
  List<AppNotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> fetchAllData() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      fetchBanners(),
      fetchNotifications(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchBanners() async {
    final res = await ApiService.get('/banners');
    if (res['status'] == 'success' && res['data']?['banners'] is List) {
      _banners = (res['data']['banners'] as List)
          .map((b) => BannerItemModel.fromJson(b))
          .toList();
      notifyListeners();
    }
  }

  Future<void> fetchNotifications() async {
    final res = await ApiService.get('/notifications');
    if (res['status'] == 'success' && res['data'] != null) {
      final data = res['data'];
      _unreadCount = data['unread_count'] is int ? data['unread_count'] : 0;
      if (data['notifications'] is List) {
        _notifications = (data['notifications'] as List)
            .map((n) => AppNotificationItem.fromJson(n))
            .toList();
      }
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    await ApiService.post('/notifications/$id/read', {});
    fetchNotifications();
  }
}
