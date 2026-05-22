import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/service_request_model.dart';
import '../../data/repositories/service_request_repository.dart';
import 'service_request_state.dart';

class ServiceRequestCubit extends Cubit<ServiceRequestState> {
  final ServiceRequestRepository _repository;
  StreamSubscription? _requestsSubscription;

  ServiceRequestCubit(this._repository) : super(ServiceRequestInitial());

  // ── إرسال طلب جديد ──────────────────────────────────────────
  Future<void> sendRequest(ServiceRequestModel request, List<File> images) async {
    emit(ServiceRequestLoading());
    try {
      if (request.latitude == null || request.longitude == null) {
        throw Exception('يرجى تحديد موقع الطلب من الخريطة قبل الإرسال');
      }
      await _repository.createRequest(request, images);
      emit(ServiceRequestSuccess());
    } catch (e) {
      emit(ServiceRequestError(e.toString()));
    }
  }

  // ── جلب طلبات الحرفي (Real-time) ─────────────────────────────
  void loadArtisanRequests(String artisanId) {
    emit(ServiceRequestLoading());
    _requestsSubscription?.cancel();
    _requestsSubscription = _repository.getArtisanRequests(artisanId).listen(
      (requests) => emit(ServiceRequestsLoaded(requests)),
      onError: (e) => emit(ServiceRequestError(e.toString())),
    );
  }

  // ── جلب طلبات العميل (Real-time) ─────────────────────────────
  void loadClientRequests(String clientId) {
    emit(ServiceRequestLoading());
    _requestsSubscription?.cancel();
    _requestsSubscription = _repository.getClientRequests(clientId).listen(
      (requests) => emit(ServiceRequestsLoaded(requests)),
      onError: (e) => emit(ServiceRequestError(e.toString())),
    );
  }

  // ── تحديث الحالة (قبول/رفض) ───────────────────────────────────
  Future<void> updateStatus(String requestId, String status, ServiceRequestModel request) async {
    try {
      await _repository.updateRequestStatus(requestId, status, request);
    } catch (e) {
      emit(ServiceRequestError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _requestsSubscription?.cancel();
    return super.close();
  }
}
