import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  String get formattedDate => DateFormat('dd/MM/yyyy').format(this);
  String get formattedDateTime => DateFormat('dd/MM/yyyy HH:mm').format(this);
  String get formattedTime => DateFormat('HH:mm').format(this);
  String get formattedShort => DateFormat('dd MMM', 'pt_BR').format(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }

  String get relativeLabel {
    if (isToday) return 'Hoje';
    if (isTomorrow) return 'Amanhã';
    return formattedShort;
  }
}

extension StringExt on String {
  String get capitalize =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';

  String get initials {
    final parts = trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return length >= 2 ? substring(0, 2).toUpperCase() : toUpperCase();
  }
}

extension DoubleExt on double {
  String get formattedKm => '${toStringAsFixed(1)} km';
}

extension ContextExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;

  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : null,
      ),
    );
  }
}
