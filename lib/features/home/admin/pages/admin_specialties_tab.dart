import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/di/injection_container.dart';
import '../data/models/specialty_model.dart';
import '../data/repositories/specialty_repository.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminSpecialtiesTab extends StatefulWidget {
  const AdminSpecialtiesTab({super.key});

  @override
  State<AdminSpecialtiesTab> createState() => _AdminSpecialtiesTabState();
}

class _AdminSpecialtiesTabState extends State<AdminSpecialtiesTab> {
  final _specialtyRepo = sl<SpecialtyRepository>();

  void _showAddSpecialtyDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.add_task_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('إضافة تخصص جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'مثلاً: التصميم، البرمجة، السباكة...',
            hintStyle: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('تجاهل', style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                _specialtyRepo.addSpecialty(name);
                Navigator.pop(context);
              }
            },
            child: Text('حفظ القسم', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSpecialtyDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 10,
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: Text('قسم جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
      body: StreamBuilder<List<SpecialtyModel>>(
        stream: _specialtyRepo.getSpecialties(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final specialties = snapshot.data ?? [];
          
          if (specialties.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(opacity: 0.1, child: Icon(Icons.category_rounded, size: 80, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  Text('لا توجد أقسام مسجلة حالياً', style: GoogleFonts.cairo(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return GridView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85,
            ),
            itemCount: specialties.length,
            itemBuilder: (context, index) {
              final item = specialties[index];
              final color = item.isActive ? AppColors.primary : Colors.grey[400]!;
              return _buildSpecialtyCard(item, color, index);
            },
          );
        },
      ),
    );
  }

  Widget _buildSpecialtyCard(SpecialtyModel item, Color color, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.08), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.construction_rounded, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(item.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch.adaptive(
                value: item.isActive,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => _specialtyRepo.toggleSpecialtyStatus(item.id, v),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _specialtyRepo.deleteSpecialty(item.id),
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms).scale(duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
