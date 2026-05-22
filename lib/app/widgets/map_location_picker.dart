import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// نتيجة اختيار الموقع من الخريطة
class LocationResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// شاشة اختيار الموقع التفاعلية (Google Map Picker)
/// تفتح كـ Route وترجع [LocationResult]
class MapLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const MapLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  /// دالة مساعدة لفتح الـ Map Picker وانتظار النتيجة
  static Future<LocationResult?> show(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
    String? initialAddress,
  }) {
    return Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(
          initialLat: initialLat,
          initialLng: initialLng,
          initialAddress: initialAddress,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _mapController;

  // الإحداثيات الافتراضية: القاهرة مصر
  static const LatLng _defaultCenter = LatLng(30.0444, 31.2357);

  LatLng _markerPosition = _defaultCenter;
  String _currentAddress = 'جارٍ تحديد العنوان...';
  bool _isLoadingLocation = false;
  bool _isLoadingAddress = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _markerPosition = LatLng(widget.initialLat!, widget.initialLng!);
      _currentAddress = widget.initialAddress ?? 'جارٍ تحديد العنوان...';
      if (widget.initialAddress == null) {
        _reverseGeocode(_markerPosition);
      }
    } else {
      // سيتم جلب الموقع بعد تهيئة الخريطة
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToCurrentLocation());
    }
  }

  // ── الانتقال لموقع المستخدم الحالي ────────────────────────────
  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('يرجى تفعيل خدمة GPS');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('تم رفض إذن الموقع');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('إذن الموقع مرفوض - يرجى تفعيله من الإعدادات');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) setState(() => _markerPosition = newPos);

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newPos, zoom: 15.5),
        ),
      );

      await _reverseGeocode(newPos);
    } catch (e) {
      debugPrint('Location Error: $e');
      _showSnack('تعذر تحديد موقعك');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // ── تحويل الإحداثيات لعنوان نصي ────────────────────────────────
  Future<void> _reverseGeocode(LatLng position) async {
    if (mounted) {
      setState(() {
        _isLoadingAddress = true;
        _currentAddress = 'جارٍ تحديد العنوان...';
      });
    }
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final Set<String> uniqueParts = {};
        
        // أجزاء العنوان المحتملة
        final rawParts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country,
        ];

        for (var part in rawParts) {
          if (part != null && part.isNotEmpty && !part.startsWith('Unnamed')) {
            String cleanPart = part.trim();
            
            // تجاهل النصوص التي تبدو كإحداثيات أو Plus Codes
            bool isCoordinate = RegExp(r'^-?\d+\.\d+').hasMatch(cleanPart) || 
                               cleanPart.contains('+') || 
                               cleanPart.split(',').length > 1 && cleanPart.contains('.');

            if (isCoordinate) continue;

            // وظيفة داخلية لتوحيد الحروف العربية المتشابهة للمقارنة الدقيقة
            String normalizeArabic(String text) {
              return text
                  .replaceAll('أ', 'ا')
                  .replaceAll('إ', 'ا')
                  .replaceAll('آ', 'ا')
                  .replaceAll('ة', 'ه')
                  .replaceAll('ى', 'ي')
                  .replaceAll('محافظة', '')
                  .replaceAll('مدينة', '')
                  .replaceAll('مركز', '')
                  .trim()
                  .toLowerCase();
            }

            String normalizedPart = normalizeArabic(cleanPart);
            
            bool isDuplicate = uniqueParts.any((existing) {
              String normalizedExisting = normalizeArabic(existing);
              return normalizedExisting.contains(normalizedPart) || normalizedPart.contains(normalizedExisting);
            });
            
            if (!isDuplicate && normalizedPart.isNotEmpty) {
              uniqueParts.add(cleanPart);
            }
          }
        }

        final address = uniqueParts.isNotEmpty ? uniqueParts.join('، ') : 'موقع غير معروف';

        if (mounted) setState(() => _currentAddress = address);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentAddress = 'تعذر تحديد العنوان');
      }
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.cairo()), backgroundColor: AppColors.error),
      );
    }
  }

  void _onCameraMove(CameraPosition position) {
    _markerPosition = position.target;
  }

  void _onCameraIdle() {
    // تحديث العنوان بعد توقف الكاميرا
    _reverseGeocode(_markerPosition);
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      LocationResult(
        latitude: _markerPosition.latitude,
        longitude: _markerPosition.longitude,
        address: _currentAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── خريطة جوجل ───────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _markerPosition,
              zoom: 13.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              setState(() => _mapReady = true);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onTap: (pos) {
              _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            buildingsEnabled: true,
            mapType: MapType.normal,
          ),

          // ── الدبوس في منتصف الشاشة (يتحرك مع الكاميرا) ──────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // فقاعة العنوان فوق الدبوس
                Container(
                  constraints: const BoxConstraints(maxWidth: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    _isLoadingAddress ? 'جارٍ التحديد...' : _currentAddress,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                // الدبوس
                const Icon(Icons.location_pin, color: AppColors.primary, size: 52),
                // ظل الدبوس
                Container(
                  width: 14,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                // حجز مساحة لتعويض ارتفاع الدبوس في المنتصف
                const SizedBox(height: 60),
              ],
            ),
          ),

          // ── شريط علوي (AppBar مخصص) ───────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 24,
              ),
              child: Row(
                children: [
                  // زر الرجوع
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'حدد موقعك على الخريطة',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // زر موقعي الحالي
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: IconButton(
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                            )
                          : const Icon(Icons.my_location_rounded, color: AppColors.primary),
                      onPressed: _isLoadingLocation ? null : _goToCurrentLocation,
                      tooltip: 'موقعي الحالي',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── بطاقة التأكيد السفلية ─────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 24,
                right: 24,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // مؤشر السحب
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),

                  Text(
                    'الموقع المحدد',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // العنوان
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isLoadingAddress
                            ? Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              )
                            : Text(
                                _currentAddress,
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // زر التأكيد
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingAddress ? null : _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                      label: Text(
                        'تأكيد هذا الموقع',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
