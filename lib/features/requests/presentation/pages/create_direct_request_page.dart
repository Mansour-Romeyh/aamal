import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/service_request_cubit.dart';
import '../bloc/service_request_state.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../../app/widgets/map_location_picker.dart';
import '../../data/models/service_request_model.dart';

class CreateDirectRequestPage extends StatefulWidget {
  final UserModel artisan;

  const CreateDirectRequestPage({super.key, required this.artisan});

  @override
  State<CreateDirectRequestPage> createState() => _CreateDirectRequestPageState();
}

class _CreateDirectRequestPageState extends State<CreateDirectRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  double? _lat;
  double? _lng;
  
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFiles = await _picker.pickMultiImage(
      limit: 3,
      imageQuality: 70,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (pickedFiles.isNotEmpty) {
      if (_images.length + pickedFiles.length > 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الحد الأقصى هو 3 صور', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      setState(() {
        _images.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _openMapPicker() async {
    final result = await MapLocationPicker.show(
      context,
      initialLat: _lat,
      initialLng: _lng,
      initialAddress: _locationController.text.isNotEmpty ? _locationController.text : null,
    );
    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _locationController.text = result.address;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_lat == null || _lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى اختيار الموقع من الخريطة لتحديد الإحداثيات', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        final request = ServiceRequestModel(
          id: '',
          clientId: authState.user.uid,
          clientName: authState.user.name,
          artisanId: widget.artisan.uid,
          artisanName: widget.artisan.name,
          specialty: widget.artisan.specialty,
          status: 'pending',
          title: _titleController.text,
          location: _locationController.text,
          message: _descController.text,
          createdAt: DateTime.now(),
          latitude: _lat,
          longitude: _lng,
        );

        context.read<ServiceRequestCubit>().sendRequest(request, _images);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppComponents.premiumAppBar(context, title: 'طلب عمل مباشر'),
      body: BlocConsumer<ServiceRequestCubit, ServiceRequestState>(
        listener: (context, state) {
          if (state is ServiceRequestSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم إرسال طلبك بنجاح!', style: GoogleFonts.cairo()),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          } else if (state is ServiceRequestError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: GoogleFonts.cairo()),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ServiceRequestLoading;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Artisan Info Header
                  _buildArtisanInfoCard(),
                  const SizedBox(height: 24),

                  // ── Title Section ───────────────────
                  _buildSectionCard(
                    title: 'عنوان الطلب',
                    subtitle: 'حدد عنواناً مختصراً لطلبك',
                    icon: Icons.title_rounded,
                    children: [
                      AppComponents.textField(
                        controller: _titleController,
                        hint: 'مثال: تصليح تلفاز توشيبا 40 بوصة',
                        prefixIcon: Icons.edit_note_rounded,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال العنوان' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Description Section ──────────────
                  _buildSectionCard(
                    title: 'تفاصيل العمل المطلوبة',
                    subtitle: 'اشرح للحرفي ما الذي تريده بالضبط',
                    icon: Icons.description_rounded,
                    children: [
                      AppComponents.textField(
                        controller: _descController,
                        hint: 'اكتب الوصف هنا...',
                        maxLines: 5,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال التفاصيل' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Location Section ────────────────
                  _buildSectionCard(
                    title: 'الموقع',
                    subtitle: 'أين سيتم تنفيذ العمل؟',
                    icon: Icons.location_on_rounded,
                    children: [
                      AppComponents.textField(
                        controller: _locationController,
                        hint: 'اضغط لتحديد موقعك على الخريطة',
                        prefixIcon: Icons.map_rounded,
                        readOnly: true,
                        onTap: _openMapPicker,
                        suffixIcon: _lat != null
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                            : IconButton(
                                icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary),
                                onPressed: _openMapPicker,
                              ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'يرجى تحديد الموقع';
                          if (_lat == null || _lng == null) return 'يرجى اختيار الموقع من الخريطة';
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Images Section ──────────────────
                  _buildSectionCard(
                    title: 'الصور (اختياري)',
                    subtitle: 'أضف صور توضيحية (${_images.length}/3)',
                    icon: Icons.photo_library_rounded,
                    children: [
                      Row(
                        children: [
                          _buildAddImageButton(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _images.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 12),
                                itemBuilder: (context, index) => _buildImagePreview(index),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 48),

                  // ── Submit Button ──────────────────
                  AppComponents.primaryButton(
                    label: 'إرسال طلب العمل الآن',
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                    backgroundColor: AppColors.secondary,
                  ).animate().scale(delay: 200.ms),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildArtisanInfoCard() {
    return AppComponents.card(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.primary.withOpacity(0.05),
      child: Row(
        children: [
          AppComponents.userAvatar(
            imageUrl: widget.artisan.profileImage,
            name: widget.artisan.name,
            radius: 25,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب موجه إلى: ${widget.artisan.name}',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  widget.artisan.specialty,
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppComponents.card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    Text(subtitle, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
      onTap: _images.length < 3 ? _pickImage : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28),
      ),
    );
  }

  Widget _buildImagePreview(int index) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(image: FileImage(_images[index]), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
            ),
          ),
        ),
      ],
    ).animate().scale(duration: 200.ms);
  }
}
