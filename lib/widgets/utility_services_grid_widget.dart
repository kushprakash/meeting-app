import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../screens/utility/electricity_bill_screen.dart';
import '../screens/utility/mobile_recharge_screen.dart';

class UtilityServicesGridWidget extends StatelessWidget {
  const UtilityServicesGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> services = [
      {
        'title': 'Mobile',
        'icon': Icons.phone_android_outlined,
        'color': const Color(0xFF3B82F6),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileRechargeScreen()),
          );
        },
      },
      {
        'title': 'Electricity',
        'icon': Icons.bolt_outlined,
        'color': const Color(0xFFF59E0B),
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
        'title': 'Loan Pay',
        'icon': Icons.account_balance_outlined,
        'color': const Color(0xFF10B981),
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
        'title': 'Fastag',
        'icon': Icons.directions_car_outlined,
        'color': const Color(0xFF8B5CF6),
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
        'title': 'LPG Gas',
        'icon': Icons.local_fire_department_outlined,
        'color': const Color(0xFFEF4444),
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
        'title': 'Broadband',
        'icon': Icons.wifi_outlined,
        'color': const Color(0xFF06B6D4),
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
        'title': 'Credit Card',
        'icon': Icons.credit_card_outlined,
        'color': const Color(0xFFEC4899),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 18, color: AppTheme.accentColor),
              SizedBox(width: 8),
              Text(
                'Recharge & Bill Services',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (ctx, index) {
              final item = services[index];
              return InkWell(
                onTap: item['onTap'] as VoidCallback?,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (item['color'] as Color).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: item['color'] as Color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['title'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
