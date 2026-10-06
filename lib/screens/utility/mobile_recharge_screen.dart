import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../services/utility_service.dart';

class MobileRechargeScreen extends StatefulWidget {
  const MobileRechargeScreen({super.key});

  @override
  State<MobileRechargeScreen> createState() => _MobileRechargeScreenState();
}

class _MobileRechargeScreenState extends State<MobileRechargeScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _mpinController = TextEditingController();

  int _currentStep = 1; // 1: Number Input ONLY, 2: Select Plan with Categories, 3: MPIN & Confirm
  bool _isLoadingPlans = false;
  bool _isProcessingRecharge = false;

  String _selectedOperatorCode = '2';
  String _selectedOperatorName = 'AIRTEL';
  String? _selectedOperatorLogo;
  String _selectedCircleCode = '2';
  String _selectedCircleName = '';
  String _selectedCategory = 'All';

  Map<String, dynamic>? _selectedPlan;
  List<Map<String, dynamic>> _allPlans = [];
  List<String> _planCategories = ['All'];

  void _fetchPlans() async {
    final number = _numberController.text.trim();
    if (number.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingPlans = true;
    });

    // Post ONLY the mobile number to getMobilePlans API
    final res = await UtilityService.getMobilePlans(number);

    setState(() {
      _isLoadingPlans = false;

      final dataObj = res['data'] ?? res;
      final isSuccess = (res['status'] == 1 ||
          res['status'] == '1' ||
          res['status'] == 'success' ||
          res['status'] == true ||
          res['code'] == 200 ||
          dataObj['plan'] != null ||
          res['plans'] != null);

      if (isSuccess && dataObj is Map) {
        // Extract Operator Name, Code, Logo & Circle Name from data
        if (dataObj['operatorname'] != null && dataObj['operatorname'].toString().isNotEmpty) {
          _selectedOperatorName = dataObj['operatorname'].toString();
        } else if (dataObj['name'] != null && dataObj['name'].toString().isNotEmpty) {
          _selectedOperatorName = dataObj['name'].toString();
        }

        if (dataObj['operator'] != null) {
          _selectedOperatorCode = dataObj['operator'].toString();
        }

        if (dataObj['circalname'] != null) {
          _selectedCircleName = dataObj['circalname'].toString();
        }
        if (dataObj['circal'] != null) {
          _selectedCircleCode = dataObj['circal'].toString();
        }

        if (dataObj['logo'] != null && dataObj['logo'].toString().isNotEmpty) {
          _selectedOperatorLogo = dataObj['logo'].toString();
        }

        // Parse Categories and Plans list from "data" -> "plan" object
        _allPlans = [];
        final Set<String> categoriesSet = {'All'};

        dynamic rawPlans = dataObj['plan'] ?? res['plans'];

        if (rawPlans is Map) {
          rawPlans.forEach((catName, planArray) {
            if (planArray is List && planArray.isNotEmpty) {
              categoriesSet.add(catName.toString());
              for (var p in planArray) {
                if (p is Map) {
                  Map<String, dynamic> item = Map<String, dynamic>.from(p);
                  item['category'] = catName.toString();
                  item['price'] = item['rs'] ?? item['price'] ?? 0;
                  item['description'] = item['desc'] ?? item['description'] ?? '';
                  item['validity'] = item['validity'] ?? 'NA';
                  _allPlans.add(item);
                }
              }
            }
          });
        } else if (rawPlans is List) {
          for (var p in rawPlans) {
            if (p is Map) {
              Map<String, dynamic> item = Map<String, dynamic>.from(p);
              item['category'] = item['category'] ?? 'Popular';
              item['price'] = item['rs'] ?? item['price'] ?? 0;
              item['description'] = item['desc'] ?? item['description'] ?? '';
              item['validity'] = item['validity'] ?? 'NA';
              categoriesSet.add(item['category'].toString());
              _allPlans.add(item);
            }
          }
        }

        _planCategories = categoriesSet.toList();

        if (_allPlans.isEmpty) {
          // Default fallback plans if API returns empty list
          _allPlans = [
            {
              'id': 'P399',
              'price': 399,
              'validity': '28 day',
              'category': 'Trending Packs',
              'description': 'Calls : Unlimited | Data : Unlimited 5G + 2.5GB/day | SMS : 100/day',
            },
            {
              'id': 'P449',
              'price': 449,
              'validity': '28 day',
              'category': 'Trending Packs',
              'description': 'Calls : Unlimited | Data : Unlimited 5G + 4GB/day | Apple Music',
            },
            {
              'id': 'P379',
              'price': 379,
              'validity': '1 month',
              'category': 'Recommended Packs',
              'description': 'Calls : Unlimited | Data : Unlimited 5G + 2GB/day | 1 month',
            },
            {
              'id': 'P200',
              'price': 200,
              'validity': '28 day',
              'category': 'Data',
              'description': 'Data: 30GB | Details: Hotstar, Prime Video, Zee5 for 28 days',
            },
          ];
          _planCategories = ['All', 'Trending Packs', 'Recommended Packs', 'Data'];
        }

        _selectedCategory = 'All';
        _currentStep = 2; // Move to Plan selection view
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Unable to fetch plans for this number'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredPlans() {
    if (_selectedCategory == 'All' || _allPlans.isEmpty) return _allPlans;
    final filtered = _allPlans.where((p) {
      return p['category'] == _selectedCategory;
    }).toList();

    return filtered.isNotEmpty ? filtered : _allPlans;
  }

  void _selectPlan(Map<String, dynamic> plan) {
    setState(() {
      _selectedPlan = plan;
      _currentStep = 3; // Move to MPIN & Confirmation view
    });
  }

  void _executeCompleteRecharge() async {
    final mpin = _mpinController.text.trim();
    if (mpin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 4-digit MPIN'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_selectedPlan == null) return;

    final double amount = double.tryParse(_selectedPlan!['price'].toString()) ?? 0.0;
    final String number = _numberController.text.trim();

    setState(() {
      _isProcessingRecharge = true;
    });

    final res = await UtilityService.doRecharge(
      number: number,
      operator: _selectedOperatorCode,
      circle: _selectedCircleCode.isNotEmpty ? _selectedCircleCode : '2',
      amount: amount,
      type: 1, // Mobile Recharge
    );

    setState(() {
      _isProcessingRecharge = false;
    });

    if (mounted) {
      Provider.of<WalletProvider>(context, listen: false).fetchWallet();
    }

    if (res['status'] == 'success' || res['status'] == 1) {
      _showSuccessDialog(res['message'] ?? 'Mobile Recharge Successful!');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Recharge failed. Amount refunded if debited.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showSuccessDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Recharge Successful!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorAvatar({double radius = 22}) {
    if (_selectedOperatorLogo != null && _selectedOperatorLogo!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: ClipOval(
          child: Image.network(
            _selectedOperatorLogo!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => _buildFallbackAvatar(radius),
          ),
        ),
      );
    }
    return _buildFallbackAvatar(radius);
  }

  Widget _buildFallbackAvatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.accentColor,
      child: Text(
        _selectedOperatorName.isNotEmpty ? _selectedOperatorName.substring(0, 1).toUpperCase() : 'M',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 1
            ? 'Mobile Recharge'
            : (_currentStep == 2 ? 'Select Recharge Plan' : 'Confirm Recharge')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentStep == 1) _buildStep1NumberInput(),
              if (_currentStep == 2) _buildStep2PlanSelection(),
              if (_currentStep == 3) _buildStep3ConfirmationAndMPIN(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 1: Mobile Number Input ONLY
  Widget _buildStep1NumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_android, color: AppTheme.accentColor, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Enter Mobile Number',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter mobile number to automatically fetch operator, circle & recharge plans.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Mobile Number TextField ONLY
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                decoration: InputDecoration(
                  labelText: '10-Digit Mobile Number',
                  hintText: '9876543210',
                  prefixIcon: const Icon(Icons.phone, color: AppTheme.accentColor),
                  suffixIcon: _numberController.text.length == 10
                      ? const Icon(Icons.check_circle, color: AppTheme.success)
                      : null,
                ),
                onChanged: (val) {
                  setState(() {});
                  if (val.length == 10) {
                    _fetchPlans();
                  }
                },
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoadingPlans ? null : _fetchPlans,
                child: _isLoadingPlans
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('FETCH PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Step 2: Scrollable Categories & Plan Cards
  Widget _buildStep2PlanSelection() {
    final filteredPlans = _getFilteredPlans();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header info card with Operator Logo & Name & Circle
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              _buildOperatorAvatar(radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _numberController.text,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '$_selectedOperatorName${_selectedCircleName.isNotEmpty ? " • $_selectedCircleName" : ""}',
                      style: const TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _currentStep = 1);
                },
                icon: const Icon(Icons.edit, size: 14, color: AppTheme.accentColor),
                label: const Text('Change', style: TextStyle(color: AppTheme.accentColor, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Scrollable Plan Categories Chips
        const Text(
          'Select Plan Category:',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _planCategories.length,
            itemBuilder: (context, idx) {
              final cat = _planCategories[idx];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.accentColor,
                  backgroundColor: AppTheme.surfaceDark,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Filtered Plans List
        Text(
          'Showing Plans (${filteredPlans.length})',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredPlans.length,
          itemBuilder: (context, idx) {
            final p = filteredPlans[idx];
            final price = p['price'] ?? p['rs'] ?? 0;
            final validity = p['validity'] ?? 'NA';
            final desc = p['description'] ?? p['desc'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppTheme.cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.2)),
              ),
              child: InkWell(
                onTap: () => _selectPlan(p),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹$price',
                            style: const TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Validity: $validity',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desc,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _selectPlan(p),
                          child: const Text('SELECT PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Step 3: Confirmation Details + MPIN Input + Complete Recharge
  Widget _buildStep3ConfirmationAndMPIN() {
    if (_selectedPlan == null) return const SizedBox.shrink();

    final price = _selectedPlan!['price'] ?? _selectedPlan!['rs'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recharge Details',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Operator Logo & Name Row
          Row(
            children: [
              _buildOperatorAvatar(radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedOperatorName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Text(
                      'Mobile Number: ${_numberController.text}',
                      style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (_selectedCircleName.isNotEmpty)
                      Text(
                        'Circle: $_selectedCircleName',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount & Plan Card Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recharge Amount', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    Text('₹$price', style: const TextStyle(color: AppTheme.accentColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Validity: ${_selectedPlan!['validity'] ?? 'NA'}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        _selectedPlan!['description'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // MPIN Input Field Below Recharge Details
          const Text(
            'Enter 4-Digit MPIN to Confirm:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _mpinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '••••',
              hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 8),
              prefixIcon: const Icon(Icons.lock, color: AppTheme.accentColor),
              fillColor: AppTheme.surfaceDark,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.accentColor)),
            ),
          ),
          const SizedBox(height: 20),

          // Complete Recharge Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isProcessingRecharge ? null : _executeCompleteRecharge,
            child: _isProcessingRecharge
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('COMPLETE RECHARGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
