import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/payment_record.dart';
import '../providers/payment_providers.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final historyAsync = ref.watch(myPaymentHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.paymentHistoryRowTitle),
      ),
      body: SafeArea(
        child: historyAsync.when(
          data: (records) => records.isEmpty
              ? _EmptyHistory(loc: loc)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _PaymentHistoryRow(record: records[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, _) => _EmptyHistory(loc: loc),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final AppLocalizations loc;

  const _EmptyHistory({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 42),
            const SizedBox(height: 16),
            Text(loc.paymentHistoryEmptyMessage, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryRow extends StatelessWidget {
  final PaymentRecord record;

  const _PaymentHistoryRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final typeLabel = switch (record.type) {
      PaymentRecordType.purchase => loc.paymentTypePurchase,
      PaymentRecordType.renewal => loc.paymentTypeRenewal,
      PaymentRecordType.cancellation => loc.paymentTypeCancellation,
      PaymentRecordType.refund => loc.paymentTypeRefund,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.packageName, style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      typeLabel,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text('·', style: AppTextStyles.caption),
                    const SizedBox(width: 6),
                    Text(DateFormat('dd.MM.yyyy').format(record.createdAt), style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${record.amount.toStringAsFixed(2)} ${record.currency}',
            style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
