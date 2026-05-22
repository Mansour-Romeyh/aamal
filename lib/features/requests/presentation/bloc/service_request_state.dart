import 'package:equatable/equatable.dart';
import '../../data/models/service_request_model.dart';

abstract class ServiceRequestState extends Equatable {
  const ServiceRequestState();
  @override
  List<Object?> get props => [];
}

class ServiceRequestInitial extends ServiceRequestState {}

class ServiceRequestLoading extends ServiceRequestState {}

class ServiceRequestsLoaded extends ServiceRequestState {
  final List<ServiceRequestModel> requests;
  const ServiceRequestsLoaded(this.requests);
  @override
  List<Object?> get props => [requests];
}

class ServiceRequestError extends ServiceRequestState {
  final String message;
  const ServiceRequestError(this.message);
  @override
  List<Object?> get props => [message];
}

class ServiceRequestSuccess extends ServiceRequestState {}
