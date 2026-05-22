import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/di/injection_container.dart';
import '../../../home/admin/data/repositories/specialty_repository.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/post_cubit.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../../app/widgets/map_location_picker.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  
  String? _selectedSpecialty;
  List<String> _availableSpecialties = [];
  bool _isLoadingSpecialties = true;
  double? _lat;
  double? _lng;
  
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  void _loadSpecialties() {
    try {
      final specialtyRepo = sl<SpecialtyRepository>();
      specialtyRepo.getActiveSpecialties().listen((specialtiesList) {
        if (mounted) {
          setState(() {
            _availableSpecialties = specialtiesList.map((e) => e.name).toList();
            // فقط تعيين الافتراضي إذا لم يتم اختيار أي تخصص من قبل
            if (_availableSpecialties.isNotEmpty && _selectedSpecialty == null) {
              _selectedSpecialty = _availableSpecialties.first;
            } else if (_selectedSpecialty != null && !_availableSpecialties.contains(_selectedSpecialty)) {
               // إذا أصبح التخصص المختار غير متاح
               _selectedSpecialty = _availableSpecialties.isNotEmpty ? _availableSpecialties.first : null;
            }
            _isLoadingSpecialties = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSpecialties = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final source = await AppComponents.showImageSourceSheet(context);
    if (source == null) return;

    if (source == ImageSource.camera) {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        if (_images.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('الحد الأقصى هو 3 صور', style: GoogleFonts.cairo()),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        setState(() {
          _images.add(File(pickedFile.path));
        });
      }
    } else {
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
        context.read<PostCubit>().createPost(
              client: authState.user,
              title: _titleController.text,
              description: _descController.text,
              specialty: _selectedSpecialty ?? '',
              location: _locationController.text,
              latitude: _lat,
              longitude: _lng,
              images: _images,
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppComponents.premiumAppBar(context, title: 'طلب جديد'),
      body: BlocConsumer<PostCubit, PostState>(
        listener: (context, state) {
          if (state is PostSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message, style: GoogleFonts.cairo()), backgroundColor: AppColors.success),
            );
            context.pop();
          } else if (state is PostError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message, style: GoogleFonts.cairo()), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is PostLoading;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title \u0026 Specialty Section ───────────────────
                  _buildSectionCard(
                    title: 'تفاصيل الخدمة',
                    subtitle: 'حدد ما تحتاجه ونوع الحرفة المطلوبة',
                    icon: Icons.assignment_rounded,
                    children: [
                      AppComponents.textField(
                        controller: _titleController,
                        hint: 'عنوان الطلب (مثال: تصليح سخان)',
                        prefixIcon: Icons.edit_note_rounded,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال العنوان' : null,
                      ),
                      const SizedBox(height: 20),
                      if (_isLoadingSpecialties)
                        const Center(child: CircularProgressIndicator())
                      else if (_availableSpecialties.isEmpty)
                        _buildNoSpecialtiesWarning()
                      else
                        _buildCustomDropdown(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Description Section ──────────────
                  _buildSectionCard(
                    title: 'وصف المشكلة',
                    subtitle: 'اشرح المشكلة بالتفصيل لضمان أفضل العروض',
                    icon: Icons.description_rounded,
                    children: [
                      AppComponents.textField(
                        controller: _descController,
                        hint: 'اكتب الوصف هنا...',
                        maxLines: 5,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الوصف' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Location Section ────────────────
                  _buildSectionCard(
                    title: 'الموقع',
                    subtitle: 'حدد مكان العمل بدقة',
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
                    title: 'الصور التوضيحية',
                    subtitle: 'أضف صور للمشكلة (اختياري) (${_images.length}/3)',
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
                    label: 'نشر الطلب الآن',
                    onPressed: (isLoading || _availableSpecialties.isEmpty || _selectedSpecialty == null) ? null : _submit,
                    isLoading: isLoading,
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

  Widget _buildCustomDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedSpecialty,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
        elevation: 16,
        style: GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        borderRadius: BorderRadius.circular(20),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 20),
          hintText: 'اختر التخصص المطلوب',
          hintStyle: GoogleFonts.cairo(fontSize: 14, color: AppColors.textHint),
        ),
        items: _availableSpecialties.map((s) {
          return DropdownMenuItem(
            value: s,
            child: Text(s, style: GoogleFonts.cairo()),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) setState(() => _selectedSpecialty = val);
        },
      ),
    );
  }


  Widget _buildNoSpecialtiesWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لا يوجد حرفيين في منطقتك حالياً لتقديم هذا النوع من الخدمات',
              style: GoogleFonts.cairo(fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
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
          border: Border.all(color: AppColors.primary.withOpacity(0.2), style: BorderStyle.solid),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
        ),
        child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28),
      ),
    );
  }

  Widget _buildImagePreview(int index) {
    return Stack(
      children: [
        Hero(
          tag: 'image_preview_$index',
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.shadowLevel1,
              image: DecorationImage(image: FileImage(_images[index]), fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
              child: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
            ),
          ),
        ),
      ],
    ).animate().scale(duration: 200.ms);
  }
}
