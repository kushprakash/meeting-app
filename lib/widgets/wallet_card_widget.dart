import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/passbook_item.dart';
import '../providers/wallet_provider.dart';
import '../services/easebuzz_pg_service.dart';

class WalletCardWidget extends StatelessWidget {
  const WalletCardWidget({super.key});

  static void showAddMoneyDialog(
    BuildContext context, [
    double? requiredAmount,
  ]) {
    final defaultAmt = requiredAmount != null && requiredAmount > 0
        ? requiredAmount.toStringAsFixed(0)
        : '100';
    final controller = TextEditingController(text: defaultAmt);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_card, color: AppTheme.accentColor),
                SizedBox(width: 10),
                Text(
                  'Add Money to Wallet',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (requiredAmount != null && requiredAmount > 0) ...[
                  Text(
                    'Required Meeting Fee: ₹${requiredAmount.toStringAsFixed(0)}. Please add funds to join.',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Enter Amount (₹):',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: '500',
                  ),
                ),
                const SizedBox(height: 16),
                if (!isSubmitting)
                  Wrap(
                    spacing: 8,
                    children: [50, 100, 200, 500, 1000, 2000].map((amt) {
                      return ActionChip(
                        backgroundColor: AppTheme.surfaceDark,
                        label: Text(
                          '₹$amt',
                          style: const TextStyle(color: AppTheme.accentColor),
                        ),
                        onPressed: () {
                          controller.text = amt.toString();
                        },
                      );
                    }).toList(),
                  ),
                if (isSubmitting) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.accentColor),
                        SizedBox(height: 10),
                        Text(
                          'Initiating payment gateway...',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.black,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final val = double.tryParse(controller.text.trim());
                        if (val == null || val <= 0) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid amount'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                          return;
                        }

                        setState(() {
                          isSubmitting = true;
                        });

                        final walletProv = Provider.of<WalletProvider>(
                          context,
                          listen: false,
                        );

                        final res = await walletProv.initiatePayment(val);

                        final Map<String, dynamic>? resData =
                            res['data'] is Map<String, dynamic>
                                ? (res['data'] as Map<String, dynamic>)
                                : null;
                        final String? accessKey = resData?['access_key']?.toString();
                        final String? refId =
                            resData?['reference_id']?.toString() ??
                            resData?['order_id']?.toString();
                        final String env = resData?['env']?.toString() ?? 'prod';
                        final bool isSuccess = res['status'] == 'success' ||
                            res['status'] == 1 ||
                            res['status'] == '1';

                        if (isSuccess &&
                            refId != null &&
                            accessKey != null &&
                            accessKey.isNotEmpty) {
                          // Dismiss the dialog first
                          Navigator.pop(ctx);

                          // Launch Native Easebuzz Android SDK ONLY
                          await EasebuzzPgService.payWithEasebuzz(
                            accessKey: accessKey,
                            env: env,
                          );

                          // Verify payment status after native SDK finishes
                          if (context.mounted) {
                            final verified = await walletProv.verifyPayment(refId);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    verified
                                        ? '₹${val.toStringAsFixed(2)} added to wallet successfully!'
                                        : (walletProv.errorMessage ??
                                            'Payment verification pending or cancelled'),
                                  ),
                                  backgroundColor:
                                      verified ? AppTheme.success : AppTheme.error,
                                ),
                              );
                            }
                          }
                        } else {
                          setState(() {
                            isSubmitting = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ??
                                      walletProv.errorMessage ??
                                      'Payment Gateway Error: Unable to initiate payment',
                                ),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                child: const Text(
                  'Add Funds',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<WalletProvider>(
        builder: (context, walletProv, child) {
          final passbooks = walletProv.passbooks;
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Passbook Statement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 10),
                Expanded(
                  child: passbooks.isEmpty
                      ? const Center(
                          child: Text(
                            'No passbook records found',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: passbooks.length,
                          itemBuilder: (context, index) {
                            final PassbookItemModel item = passbooks[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: item.isCredit
                                            ? AppTheme.success.withValues(
                                                alpha: 0.2,
                                              )
                                            : AppTheme.error.withValues(
                                                alpha: 0.2,
                                              ),
                                        child: Icon(
                                          item.isCredit
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: item.isCredit
                                              ? AppTheme.success
                                              : AppTheme.error,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.details,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'Type: ${item.type} | Pre-Bal: ₹${item.preBalance.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${item.isCredit ? "+" : "-"}₹${item.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: item.isCredit
                                                  ? AppTheme.success
                                                  : AppTheme.error,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Bal: ₹${item.balance.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppTheme.accentColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProv, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: AppTheme.accentColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Passbook Account',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Balance',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${walletProv.walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => showAddMoneyDialog(context),
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text(
                          'Add Money',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showHistorySheet(context),
                        icon: const Icon(Icons.menu_book, size: 16),
                        label: const Text(
                          'Passbook',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
