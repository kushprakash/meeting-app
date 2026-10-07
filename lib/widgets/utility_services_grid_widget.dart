import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../screens/utility/electricity_bill_screen.dart';
import '../screens/utility/mobile_recharge_screen.dart';

class UtilityServicesGridWidget extends StatefulWidget {
  const UtilityServicesGridWidget({super.key});

  @override
  State<UtilityServicesGridWidget> createState() => _UtilityServicesGridWidgetState();
}

class _UtilityServicesGridWidgetState extends State<UtilityServicesGridWidget> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allServices = [
      {
        'title': 'Mobile\nRecharge',
        'icon': Icons.smartphone_outlined,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileRechargeScreen()),
          );
        },
      },
      {
        'title': 'DTH\nRecharge',
        'icon': Icons.settings_input_antenna_outlined,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ElectricityBillScreen(
                title: 'DTH Recharge',
                category: 'DTH',
              ),
            ),
          );
        },
      },
      {
        'title': 'Electricity\nBill Pay',
        'icon': Icons.lightbulb_outline_rounded,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ElectricityBillScreen(
                title: 'Electricity Bill',
                category: 'Electric',
              ),
            ),
          );
        },
      },
      {
        'title': 'Loan\nRepayment',
        'icon': Icons.account_balance_wallet_outlined,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ElectricityBillScreen(
                title: 'Loan Repayment',
                category: 'Loan Repayment',
              ),
            ),
          );
        },
      },
      {
        'title': 'Fastag\nRecharge',
        'icon': Icons.directions_car_outlined,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ElectricityBillScreen(
                title: 'Fastag Recharge',
                category: 'Fastag',
              ),
            ),
          );
        },
      },
      {
        'title': 'LPG Gas\nBill',
        'icon': Icons.local_fire_department_outlined,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ElectricityBillScreen(
                title: 'LPG Gas Bill',
                category: 'LPG Gas',
              ),
            ),
          );
        },
      },
      {
        'title': 'Broadband\nBill',
        'icon': Icons.wifi_outlined,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ElectricityBillScreen(
                title: 'Broadband Bill',
                category: 'Broadband',
              ),
            ),
          );
        },
      },
      {
        'title': 'Credit Card\nPay',
        'icon': Icons.credit_card_outlined,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ElectricityBillScreen(
                title: 'Credit Card Pay',
                category: 'Credit Card Pay',
              ),
            ),
          );
        },
      },
    ];

    final displayServices = _showAll ? allServices : allServices.take(4).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with "Recharge & Bills" title and "See All" pill button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recharge & Bills',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAll ? Icons.keyboard_arrow_up : Icons.grid_view_rounded,
                        size: 14,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showAll ? 'Show Less' : 'See All',
                        style: const TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Grid View displaying tiles with AppTheme dark styling
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayServices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (ctx, index) {
              final item = displayServices[index];
              return InkWell(
                onTap: item['onTap'] as VoidCallback?,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Theme Tile Box matching dark app palette
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: AppTheme.success, // Theme green/emerald color
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
