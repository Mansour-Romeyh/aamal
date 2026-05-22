import 'package:equatable/equatable.dart';

abstract class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object?> get props => [];
}

class ForgotPasswordInitial extends ForgotPasswordState {}

class ForgotPasswordLoading extends ForgotPasswordState {}

class ForgotPasswordOtpSent extends ForgotPasswordState {
  final String phone;
  final String pinId;
  final String uid;

  const ForgotPasswordOtpSent({
    required this.phone,
    required this.pinId,
    required this.uid,
  });

  @override
  List<Object?> get props => [phone, pinId, uid];
}

class ForgotPasswordOtpVerified extends ForgotPasswordState {
  final String uid;

  const ForgotPasswordOtpVerified({required this.uid});

  @override
  List<Object?> get props => [uid];
}

class ForgotPasswordSuccess extends ForgotPasswordState {}

class ForgotPasswordError extends ForgotPasswordState {
  final String message;

  const ForgotPasswordError(this.message);

  @override
  List<Object?> get props => [message];
}
