import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/notification_service.dart';
import '../models/report_model.dart';

class ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _reportsRef =>
      _firestore.collection(FirebaseConstants.reportsCollection);

  // ── إرسال بلاغ ────────────────────────────────────────────────
  Future<void> sendReport(ReportModel report) async {
    await _reportsRef.add(report.toMap());
    
    // إشعار للأدمنز بوجود بلاغ جديد
    NotificationService.instance.sendNotificationToAdmins(
      title: 'إشعار بلاغ جديد ⚠️',
      body: 'تم تقديم بلاغ ضد مستخدم جديد. يرجى المراجعة.',
      data: {
        'type': 'report',
        'reportedId': report.reportedId,
      },
    );
  }

  // ── جلب بلاغات مستخدم ──────────────────────────────────────────
  Stream<List<ReportModel>> getReportsAgainstUser(String reportedId) {
    return _reportsRef
        .where('reportedId', isEqualTo: reportedId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportModel.fromFirestore(doc))
            .toList());
  }

  // ── جلب كل البلاغات (للأدمن) ────────────────────────────────────
  Stream<List<ReportModel>> getAllReports() {
    return _reportsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportModel.fromFirestore(doc))
            .toList());
  }

  // ── تحديث حالة البلاغ (للأدمن) ──────────────────────────────────
  Future<void> updateReportStatus(String reportId, String status) async {
    await _reportsRef.doc(reportId).update({'status': status});
  }

  // ── حذف البلاغ (للأدمن) ──────────────────────────────────────────
  Future<void> deleteReport(String reportId) async {
    await _reportsRef.doc(reportId).delete();
  }
}
