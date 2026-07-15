import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Söhbətlər',
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
                      child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Söhbətin yoxdur',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ətrafındakı insanlarla tanış olduqda söhbətlərin burada görünəcək.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
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
