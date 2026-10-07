import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/utility_service.dart';

enum HistoryType {
  addFund,
  mobileRecharge,
  dthRecharge,
  billPayment,
  meeting,
  passbook,
}

class HistoryScreen extends StatefulWidget {
  final HistoryType type;
  final String title;

  const HistoryScreen({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  String? _errorMessage;
  final Map<String, bool> _checkingStatusTxn = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.type == HistoryType.passbook || widget.type == HistoryType.addFund) {
      final walletProv = Provider.of<WalletProvider>(context, listen: false);
      await walletProv.fetchWallet();

      final list = walletProv.passbooks;
      List<Map<String, dynamic>> filtered = [];

      for (var p in list) {
        final isAddMoney = p.type == 'CR' || p.details.toLowerCase().contains('add money') || p.details.toLowerCase().contains('fund');
        if (widget.type == HistoryType.addFund && !isAddMoney) continue;

        filtered.add({
          'txnid': p.id.toString(),
          'details': p.details,
          'amount': p.amount,
          'type': p.type,
          'pre_balance': p.preBalance,
          'balance': p.balance,
          'status': 'success',
          'created_at': p.createdAt ?? '',
        });
      }

      setState(() {
        _items = filtered;
        _isLoading = false;
      });
      return;
    }

    if (widget.type == HistoryType.meeting) {
      try {
        final meetingProv = Provider.of<MeetingProvider>(context, listen: false);
        await meetingProv.fetchMeetings();

        List<Map<String, dynamic>> filtered = [];
        final Map<String, MeetingModel> meetingMap = {};
        for (var m in meetingProv.hostedMeetings) {
          meetingMap[m.uuid] = m;
        }
        for (var m in meetingProv.participatingMeetings) {
          meetingMap[m.uuid] = m;
        }

        for (var m in meetingMap.values) {
          filtered.add({
            'txnid': m.uuid,
            'details': m.title,
            'operator_name': m.title,
            'number': 'UUID: ${m.uuid}',
            'amount': m.price,
            'status': m.isMeetingExpired ? 'ended' : m.status,
            'created_at': m.startsAt ?? m.createdAt ?? '',
            'raw_meeting': m,
          });
        }

        setState(() {
          _items = filtered;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Error loading meeting history: $e';
          _isLoading = false;
        });
      }
      return;
    }

    // Utility Recharge / Bill History
    try {
      final res = await UtilityService.getHistory();
      if (res['status'] == 'success' || res['data'] != null) {
        final rawList = res['data']?['history'] ?? res['history'] ?? res['data'] ?? [];
        List<Map<String, dynamic>> filtered = [];

        if (rawList is List) {
          for (var item in rawList) {
            if (item is! Map<String, dynamic>) continue;

            final int itemType = int.tryParse(item['type']?.toString() ?? '0') ?? 0;
            final String category = (item['category'] ?? item['operator_name'] ?? '').toString().toLowerCase();

            if (widget.type == HistoryType.mobileRecharge) {
              if (itemType != 1 && !category.contains('mobile') && !category.contains('airtel') && !category.contains('jio') && !category.contains('vi') && !category.contains('bsnl')) {
                continue;
              }
            } else if (widget.type == HistoryType.dthRecharge) {
              if (itemType != 2 && !category.contains('dth') && !category.contains('dish') && !category.contains('tata') && !category.contains('airtel dth') && !category.contains('sun')) {
                continue;
              }
            } else if (widget.type == HistoryType.billPayment) {
              if (itemType != 3 && !category.contains('bill') && !category.contains('electric') && !category.contains('gas') && !category.contains('water')) {
                continue;
              }
            } else if (widget.type == HistoryType.meeting) {
              final details = (item['details'] ?? item['operator_name'] ?? '').toString().toLowerCase();
              if (!details.contains('meeting') && !category.contains('meeting')) {
                continue;
              }
            }

            filtered.add(item);
          }
        }

        setState(() {
          _items = filtered;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load history';
          _isLoading = false;
        });
      }
    } catch (e) {
        setState(() {
          _errorMessage = 'Error loading history: $e';
          _isLoading = false;
        });
    }
  }

  Future<void> _checkStatus(Map<String, dynamic> item) async {
    final txnid = (item['txnid'] ?? item['txn_id'] ?? item['id'] ?? '').toString();
    if (txnid.isEmpty) return;

    setState(() {
      _checkingStatusTxn[txnid] = true;
    });

    Map<String, dynamic> res;
    if (widget.type == HistoryType.billPayment) {
      res = await UtilityService.getBillStatus(txnid);
    } else {
      res = await UtilityService.checkRechargeStatus(txnid);
    }

    setState(() {
      _checkingStatusTxn[txnid] = false;
    });

    final newStatus = (res['status'] ?? res['data']?['status'] ?? 'pending').toString().toLowerCase();
    final message = res['message'] ?? 'Status updated: $newStatus';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: newStatus.contains('success') ? AppTheme.success : (newStatus.contains('fail') ? AppTheme.error : AppTheme.warning),
        ),
      );
      setState(() {
        item['status'] = newStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentColor))
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history_toggle_off, size: 56, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No ${widget.title} Records Found',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (ctx, idx) {
                          final item = _items[idx];
                          final status = (item['status'] ?? 'success').toString().toLowerCase();
                          final isPending = status == 'pending' || status == 'processing' || status == '0';
                          final txnid = (item['txnid'] ?? item['txn_id'] ?? item['id'] ?? '').toString();
                          final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                          final number = (item['number'] ?? item['customer_id'] ?? item['details'] ?? '').toString();
                          final operatorName = (item['operator_name'] ?? item['operator'] ?? item['details'] ?? 'Utility').toString();

                          String timeStr = 'Recently';
                          if (item['created_at'] != null) {
                            try {
                              final dt = DateTime.parse(item['created_at']).toLocal();
                              timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                            } catch (_) {}
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isPending
                                    ? AppTheme.warning.withValues(alpha: 0.6)
                                    : (status.contains('fail')
                                        ? AppTheme.error.withValues(alpha: 0.4)
                                        : Colors.white.withValues(alpha: 0.08)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        operatorName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '₹${amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: widget.type == HistoryType.addFund || item['type'] == 'CR'
                                            ? AppTheme.success
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (number.isNotEmpty && number != operatorName)
                                  Text(
                                    'Acc/Num: $number',
                                    style: const TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeStr,
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPending
                                            ? AppTheme.warning.withValues(alpha: 0.2)
                                            : (status.contains('fail')
                                                ? AppTheme.error.withValues(alpha: 0.2)
                                                : AppTheme.success.withValues(alpha: 0.2)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: isPending
                                              ? AppTheme.warning
                                              : (status.contains('fail') ? AppTheme.error : AppTheme.success),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Show "Check Status" button if transaction is PENDING
                                if (isPending && (widget.type == HistoryType.mobileRecharge || widget.type == HistoryType.dthRecharge || widget.type == HistoryType.billPayment)) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.warning,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: (_checkingStatusTxn[txnid] == true) ? null : () => _checkStatus(item),
                                      icon: (_checkingStatusTxn[txnid] == true)
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                            )
                                          : const Icon(Icons.sync, size: 14),
                                      label: const Text(
                                        'Check Status',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                                // Show "Details" button for Meeting History items
                                if (item['raw_meeting'] is MeetingModel) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.accentColor,
                                        side: const BorderSide(color: AppTheme.accentColor),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => _showMeetingReportDialog(context, item['raw_meeting'] as MeetingModel),
                                      icon: const Icon(Icons.info_outline, size: 14),
                                      label: const Text(
                                        'Meeting Details',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  void _showMeetingReportDialog(BuildContext context, MeetingModel m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assessment_outlined,
                  color: AppTheme.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Attendance & Meeting Report',
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
            const SizedBox(height: 8),
            Text(
              m.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Code (UUID): ${m.uuid}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Host:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          m.host?.name ?? 'Host User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          m.host?.email ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: m.isMeetingExpired ? AppTheme.error.withValues(alpha: 0.2) : AppTheme.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m.isMeetingExpired ? 'ENDED' : 'ACTIVE',
                      style: TextStyle(
                        color: m.isMeetingExpired ? AppTheme.error : AppTheme.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Participants History (${m.participants.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: m.participants.isEmpty
                  ? const Center(
                      child: Text(
                        'No participants recorded in this session',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: m.participants.length,
                      itemBuilder: (context, index) {
                        final p = m.participants[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: p.isHost
                                    ? AppTheme.warning
                                    : AppTheme.primaryColor,
                                child: Text(
                                  (p.user?.name ?? p.email)
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.user?.name ?? 'Guest User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      p.email,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                p.role.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.info,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
