import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class EventsTab extends StatelessWidget {
  const EventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Tədbirlər',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      child: const Icon(Icons.event_outlined, color: AppColors.primary, size: 42),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Hələ heç bir tədbir yoxdur',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Yaxınlıqda gəzinti, qəhvə görüşü və ya idman tədbiri yarat, ətrafındakılar qoşulsun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, color: Color(0xFF00281E)),
                      label: const Text('Tədbir yarat'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
