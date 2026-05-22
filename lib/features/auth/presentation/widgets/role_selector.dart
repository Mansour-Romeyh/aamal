import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import '../../../../app/di/injection_container.dart';
import '../../../home/admin/data/repositories/specialty_repository.dart';
import '../../../home/admin/data/models/specialty_model.dart';

import '../../../../app/widgets/app_components.dart';

class RoleSelector extends StatefulWidget {
  final String selectedRole;
  final String selectedSpecialty;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onSpecialtyChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.selectedSpecialty,
    required this.onRoleChanged,
    required this.onSpecialtyChanged,
  });

  @override
  State<RoleSelector> createState() => _RoleSelectorState();
}

class _RoleSelectorState extends State<RoleSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _specialtyAnimation;
  late Stream<List<SpecialtyModel>> _specialtiesStream;
  
  final _specialtyRepo = sl<SpecialtyRepository>();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _specialtyAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
    if (widget.selectedRole == 'artisan') {
      _animController.value = 1.0;
    }
    _specialtiesStream = _specialtyRepo.getActiveSpecialties();
  }


  @override
  void didUpdateWidget(covariant RoleSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRole == 'artisan') {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع الحساب',
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _RoleCard(
                title: 'عميل',
                subtitle: 'أبحث عن حرفي',
                icon: Icons.person_outline_rounded,
                isSelected: widget.selectedRole == 'client',
                onTap: () => widget.onRoleChanged('client'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleCard(
                title: 'حرفي',
                subtitle: 'أقدم خدماتي',
                icon: Icons.handyman_rounded,
                isSelected: widget.selectedRole == 'artisan',
                onTap: () => widget.onRoleChanged('artisan'),
              ),
            ),
          ],
        ),

        SizeTransition(
          sizeFactor: _specialtyAnimation,
          child: FadeTransition(
            opacity: _specialtyAnimation,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اختر تخصصك',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<SpecialtyModel>>(
                    stream: _specialtiesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('خطأ: ${snapshot.error}', style: GoogleFonts.cairo(color: AppColors.error, fontSize: 11));
                      }

                      final specialties = snapshot.data ?? [];
                      
                      if (snapshot.connectionState != ConnectionState.waiting && specialties.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.2)),
                          ),
                          child: Text(
                            '⚠️ لا توجد تخصصات مضافة حالياً. يرجى مراجعة الإدارة.',
                            style: GoogleFonts.cairo(fontSize: 12, color: Colors.orange[900]),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: widget.selectedSpecialty.isNotEmpty && 
                                specialties.any((s) => s.name == widget.selectedSpecialty)
                            ? widget.selectedSpecialty
                            : null,
                        hint: Text(
                          snapshot.connectionState == ConnectionState.waiting 
                            ? 'جاري التحميل...' 
                            : 'اختر من القائمة...', 
                          style: GoogleFonts.cairo(fontSize: 14)
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.handyman_outlined, size: 20),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        items: specialties.map((SpecialtyModel specialty) {
                          return DropdownMenuItem(
                            value: specialty.name,
                            child: Text(specialty.name, style: GoogleFonts.cairo(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            widget.onSpecialtyChanged(value);
                          }
                        },
                        validator: (v) {
                          if (widget.selectedRole == 'artisan' && (v == null || v.isEmpty)) {
                            return 'يرجى اختيار التخصص';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected ? AppColors.shadowLevel2 : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: isSelected ? AppColors.primary.withOpacity(0.8) : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
