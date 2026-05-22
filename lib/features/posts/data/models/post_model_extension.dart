import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'post_model.dart';

extension PostModelUIExtension on PostModel {
  Color get statusColor {
    switch (status) {
      case 'open':
        return AppColors.primary;
      case 'accepted':
      case 'in_progress':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'declined':
        return AppColors.error;
      case 'admin_rejected':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.textSecondary;
    }
  }

  String get statusText {
    switch (status) {
      case 'open':
        return 'قيد الانتظار';
      case 'accepted':
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
      case 'ملغي':
        return 'تم الرفض من قبل الحرفي';
      case 'declined':
        return 'تم الرفض من قبل الحرفي';
      case 'admin_rejected':
        return '⛔ مرفوض من قبل الإدارة';
      default:
        return status;
    }
  }
}
