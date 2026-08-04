import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/saved_card.dart' show CardBrand, SavedCard;

/// One saved payment method — network badges are stylized text (VISA/MC),
/// not the providers' actual trademarked artwork.
class SavedCardRow extends StatelessWidget {
  final SavedCard card;
  final VoidCallback onTap;

  const SavedCardRow({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _brandColor(card.brand);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
              child: Text(
                _brandLabel(card.brand),
                style: AppTextStyles.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '**** **** **** ${card.last4}',
                    style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${card.expMonth.toString().padLeft(2, '0')}/${(card.expYear % 100).toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (card.isDefault)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
              ),
            Icon(Icons.credit_card_outlined, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  String _brandLabel(CardBrand brand) {
    return switch (brand) {
      CardBrand.visa => 'VISA',
      CardBrand.mastercard => 'MC',
      CardBrand.other => 'CARD',
    };
  }

  Color _brandColor(CardBrand brand) {
    return switch (brand) {
      CardBrand.visa => const Color(0xFF1A1F71),
      CardBrand.mastercard => const Color(0xFFEB001B),
      CardBrand.other => AppColors.textMuted,
    };
  }
}
