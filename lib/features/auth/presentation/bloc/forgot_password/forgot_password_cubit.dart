import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import '../../../../../core/constants/firebase_constants.dart';

import '../../../../../core/services/admin_auth_service.dart';
import 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ForgotPasswordCubit() : super(ForgotPasswordInitial());

  Future<void> sendOtpToPhone(String phone) async {
    emit(ForgotPasswordLoading());
    try {
      // 1. Find user by phone number
      final querySnapshot = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        emit(const ForgotPasswordError('رقم الهاتف غير مسجل في النظام.'));
        return;
      }

      final uid = querySnapshot.docs.first.id;

      // 2. Send OTP via Firebase
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          emit(ForgotPasswordError('فشل إرسال رمز التحقق: ${e.message}'));
        },
        codeSent: (String verificationId, int? resendToken) {
          emit(ForgotPasswordOtpSent(phone: phone, pinId: verificationId, uid: uid));
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      debugPrint('Error sending OTP for forgot password: $e');
      emit(ForgotPasswordError('حدث خطأ أثناء الاتصال: ${e.toString()}'));
    }
  }

  Future<void> verifyOtp(String enteredOtp) async {
    final currentState = state;
    if (currentState is! ForgotPasswordOtpSent) {
      emit(const ForgotPasswordError('حالة غير صالحة، يرجى إعادة طلب الرمز.'));
      return;
    }

    emit(ForgotPasswordLoading());
    try {
      bool isApproved = false;
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: currentState.pinId,
          smsCode: enteredOtp,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        isApproved = true;
      } catch (e) {
        isApproved = false;
      }

      if (isApproved) {
        emit(ForgotPasswordOtpVerified(uid: currentState.uid));
      } else {
        emit(const ForgotPasswordError('رمز التحقق غير صحيح أو منتهي الصلاحية.'));
        // Re-emit OTP sent state to allow retry
        emit(ForgotPasswordOtpSent(
          phone: currentState.phone,
          pinId: currentState.pinId,
          uid: currentState.uid,
        ));
      }
    } catch (e) {
      emit(ForgotPasswordError('حدث خطأ أثناء التحقق: ${e.toString()}'));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    final currentState = state;
    if (currentState is! ForgotPasswordOtpVerified) {
      emit(const ForgotPasswordError('حالة غير صالحة لتغيير كلمة المرور.'));
      return;
    }

    emit(ForgotPasswordLoading());
    try {
      // Use AdminAuthService locally instead of Cloud Functions
      final success = await AdminAuthService.instance.updateUserPassword(
        currentState.uid,
        newPassword,
      );

      if (success) {
        emit(ForgotPasswordSuccess());
      } else {
        emit(const ForgotPasswordError('فشل في تحديث كلمة المرور. حاول مجدداً.'));
      }
    } catch (e) {
      debugPrint('Error updating password via local admin service: $e');
      emit(ForgotPasswordError('حدث خطأ أثناء تحديث كلمة المرور. تأكد من اتصالك بالإنترنت.'));
    }
  }
}
