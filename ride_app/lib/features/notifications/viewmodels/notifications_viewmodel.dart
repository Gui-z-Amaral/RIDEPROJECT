import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/services/supabase_notification_service.dart';

class NotificationsViewModel extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  RealtimeChannel? _channel;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications =
          await SupabaseNotificationService.getNotifications();
    } catch (_) {
      _notifications = [];
    }
    _isLoading = false;
    notifyListeners();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    try {
      _channel = SupabaseNotificationService.subscribeToNotifications(
        (notif) {
          _notifications = [notif, ..._notifications];
          notifyListeners();
        },
      );
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    try {
      await SupabaseNotificationService.markAsRead(id);
      _notifications = _notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await SupabaseNotificationService.markAllAsRead();
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Remove uma notificação (otimista, com rollback se falhar).
  Future<void> remove(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0) return;
    final removed = _notifications[index];
    _notifications = List.of(_notifications)..removeAt(index);
    notifyListeners();
    try {
      await SupabaseNotificationService.delete(id);
    } catch (_) {
      _notifications = List.of(_notifications)..insert(index, removed);
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    if (_notifications.isEmpty) return;
    final previous = _notifications;
    _notifications = [];
    notifyListeners();
    try {
      await SupabaseNotificationService.clearAll();
    } catch (_) {
      _notifications = previous;
      notifyListeners();
    }
  }

  /// Limpa estado e cancela canal — chamado no logout.
  void reset() {
    _channel?.unsubscribe();
    _channel = null;
    _notifications = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
