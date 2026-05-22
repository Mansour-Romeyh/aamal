import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../home/admin/data/repositories/specialty_repository.dart';
import '../../data/models/post_model.dart';
import '../bloc/post_cubit.dart';
import '../../../../app/widgets/app_components.dart';

class EditPostPage extends StatefulWidget {
  final PostModel post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _locationController;
  
  String? _selectedSpecialty;
  List<String> _availableSpecialties = [];
  bool _isLoadingSpecialties = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _descController = TextEditingController(text: widget.post.description);
    _locationController = TextEditingController(text: widget.post.location);
    _selectedSpecialty = widget.post.specialty;
    
    _loadSpecialties();
  }

  void _loadSpecialties() {
    try {
      final specialtyRepo = sl<SpecialtyRepository>();
      specialtyRepo.getActiveSpecialties().listen((specialtiesList) {
        if (mounted) {
          setState(() {
            _availableSpecialties = specialtiesList.map((e) => e.name).toList();
            if (!_availableSpecialties.contains(_selectedSpecialty) && _selectedSpecialty != null) {
               _availableSpecialties.add(_selectedSpecialty!);
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

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<PostCubit>().updatePost(
            postId: widget.post.id,
            title: _titleController.text,
            description: _descController.text,
            specialty: _selectedSpecialty ?? widget.post.specialty,
            location: _locationController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppComponents.premiumAppBar(context, title: 'تعديل الطلب'),
      body: BlocConsumer<PostCubit, PostState>(
        listener: (context, state) {
          if (state is PostSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message, style: GoogleFonts.cairo()), backgroundColor: AppColors.success),
            );
            if (GoRouter.of(context).canPop()) context.pop();
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
                  // ── Title Section ───────────────────
                  _buildSectionHeader('عنوان الطلب', 'ما الذي تريد تغييره؟'),
                  const SizedBox(height: 16),
                  AppComponents.textField(
                    controller: _titleController,
                    hint: 'أدخل العنوان الجديد',
                    prefixIcon: Icons.title_rounded,
                    validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال العنوان' : null,
                  ),
                  const SizedBox(height: 24),

                  // ── Specialty Section ────────────────
                  _buildSectionHeader('التخصص', 'تغيير نوع الحرفة'),
                  const SizedBox(height: 16),
                  if (_isLoadingSpecialties)
                    const Center(child: CircularProgressIndicator())
                  else
                    _buildDropdownField(),
                  const SizedBox(height: 24),

                  // ── Description Section ──────────────
                  _buildSectionHeader('وصف المهمة', 'حدث تفاصيل طلبك'),
                  const SizedBox(height: 16),
                  AppComponents.textField(
                    controller: _descController,
                    hint: 'اكتب الوصف الجديد هنا...',
                    maxLines: 5,
                    validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الوصف' : null,
                  ),
                  const SizedBox(height: 24),

                  // ── Location Section ────────────────
                  _buildSectionHeader('الموقع / العنوان', 'تعديل مكان العمل'),
                  const SizedBox(height: 16),
                  AppComponents.textField(
                    controller: _locationController,
                    hint: 'تعديل الموقع',
                    prefixIcon: Icons.location_on_rounded,
                    validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الموقع' : null,
                  ),
                  const SizedBox(height: 24),

                  // ── Info Card ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'تعديل الصور غير متاح حالياً. لتغيير الصور، يجب حذف الطلب ونشره من جديد.',
                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Submit Button ──────────────────
                  AppComponents.primaryButton(
                    label: 'حفظ التعديلات',
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
        Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedSpecialty,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
        style: GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 20),
        ),
        items: _availableSpecialties.map((s) {
          return DropdownMenuItem(value: s, child: Text(s));
        }).toList(),
        onChanged: (val) {
          if (val != null) setState(() => _selectedSpecialty = val);
        },
      ),
    );
  }
}
