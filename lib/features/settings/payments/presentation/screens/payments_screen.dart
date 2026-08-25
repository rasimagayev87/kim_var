import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/coming_soon_screen.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/saved_card.dart';
import '../providers/payment_providers.dart';
import '../widgets/saved_card_row.dart';
import 'payment_history_screen.dart';

/// No card-tokenization provider (Stripe et al.) is connected yet —
/// see `savedCardsProvider`'s doc comment — so "Kartlarım" always
/// shows the empty state right now, and "Kart əlavə et" opens
/// [ComingSoonScreen] rather than a real add-card flow. The list UI
/// and the per-card options sheet are real and ready for whenever a
/// provider is wired up.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final cards = ref.watch(savedCardsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.paymentsScreenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.receipt_long_outlined,
                  title: loc.paymentHistoryRowTitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(loc.myCardsTitle, style: AppTextStyles.sectionTitle.copyWith(fontSize: 17)),
            const SizedBox(height: 12),
            if (cards.isEmpty)
              _EmptyCardsState(onAddCard: () => _openAddCard(context))
            else ...[
              SettingsGroup(
                children: [
                  for (final card in cards) SavedCardRow(card: card, onTap: () => _showCardOptions(context, card)),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openAddCard(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.addCardButton),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openAddCard(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComingSoonScreen(title: loc.addCardButton)));
  }

  void _showCardOptions(BuildContext context, SavedCard card) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (!card.isDefault)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                title: Text(loc.cardOptionsSetDefault, style: AppTextStyles.body.copyWith(fontSize: 15)),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(loc.cardOptionsDelete, style: AppTextStyles.body.copyWith(fontSize: 15, color: AppColors.error)),
              onTap: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  final VoidCallback onAddCard;

  const _EmptyCardsState({required this.onAddCard});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.credit_card_outlined, color: AppColors.textMuted, size: 32),
          const SizedBox(height: 12),
          Text(loc.noCardsMessage, style: AppTextStyles.caption),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddCard,
            icon: const Icon(Icons.add, size: 18, color: AppColors.onAccent),
            label: Text(loc.addCardButton),
          ),
        ],
      ),
    );
  }
}
