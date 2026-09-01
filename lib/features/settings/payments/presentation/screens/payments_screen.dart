import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/payments/epoint_card_checkout_screen.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/saved_card.dart';
import '../providers/payment_providers.dart';
import '../widgets/saved_card_row.dart';
import 'payment_history_screen.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _addingCard = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cards =
        ref.watch(savedCardsProvider).valueOrNull ?? const <SavedCard>[];

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    MaterialPageRoute(
                      builder: (_) => const PaymentHistoryScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              loc.myCardsTitle,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 12),
            if (cards.isEmpty)
              _EmptyCardsState(loading: _addingCard, onAddCard: _openAddCard)
            else ...[
              SettingsGroup(
                children: [
                  for (final card in cards)
                    SavedCardRow(
                      card: card,
                      onTap: () => _showCardOptions(card),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addingCard ? null : _openAddCard,
                icon: _addingCard
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 18),
                label: Text(loc.addCardButton),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAddCard() async {
    if (_addingCard) return;
    final loc = AppLocalizations.of(context);
    setState(() => _addingCard = true);
    try {
      final checkoutUrl = await ref
          .read(savedCardRepositoryProvider)
          .startCardRegistration();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpointCardCheckoutScreen(checkoutUrl: checkoutUrl),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    } finally {
      if (mounted) setState(() => _addingCard = false);
    }
  }

  void _showCardOptions(SavedCard card) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (!card.isDefault)
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primary,
                ),
                title: Text(
                  loc.cardOptionsSetDefault,
                  style: AppTextStyles.body.copyWith(fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setDefault(card);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                loc.cardOptionsDelete,
                style: AppTextStyles.body.copyWith(
                  fontSize: 15,
                  color: AppColors.error,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(card);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefault(SavedCard card) async {
    final loc = AppLocalizations.of(context);
    try {
      await ref.read(savedCardRepositoryProvider).setDefaultCard(card.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    }
  }

  Future<void> _confirmDelete(SavedCard card) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          loc.cardOptionsDelete,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(loc.cardDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(savedCardRepositoryProvider).deleteCard(card.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    }
  }
}

class _EmptyCardsState extends StatelessWidget {
  final bool loading;
  final VoidCallback onAddCard;

  const _EmptyCardsState({required this.loading, required this.onAddCard});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.credit_card_outlined,
            color: AppColors.textMuted,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(loc.noCardsMessage, style: AppTextStyles.caption),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: loading ? null : onAddCard,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onAccent,
                    ),
                  )
                : const Icon(Icons.add, size: 18, color: AppColors.onAccent),
            label: Text(loc.addCardButton),
          ),
        ],
      ),
    );
  }
}
