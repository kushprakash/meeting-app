import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class UtilityService {
  /// 1. Fetch Mobile Recharge Plans
  static Future<Map<String, dynamic>> getMobilePlans(String number) async {
    return await ApiService.post('/recharge/mobile-plans', {'number': number});
  }

  /// 2. Fetch Operators (Default: DTH)
  static Future<Map<String, dynamic>> getOperators({
    String category = 'DTH',
  }) async {
    return await ApiService.post('/recharge/get-operator', {
      'category': category,
    });
  }

  /// 3. Perform Mobile / DTH Recharge
  static Future<Map<String, dynamic>> doRecharge({
    required String number,
    required String operator,
    String circle = '2',
    required double amount,
    int type = 1, // 1: Mobile, 2: DTH
  }) async {
    return await ApiService.post('/recharge/recharge', {
      'number': number,
      'operator': operator,
      'circle': circle,
      'amount': amount,
      'type': type,
    });
  }

  /// 4. Check Single Recharge Transaction Status
  static Future<Map<String, dynamic>> checkRechargeStatus(String txnid) async {
    return await ApiService.post('/recharge/recharge-status', {'txnid': txnid});
  }

  /// 5. Fetch Bill Categories (Electricity, Water, Gas, etc.)
  static Future<Map<String, dynamic>> getBillCategories() async {
    return await ApiService.get('/recharge/bill-categories');
  }

  /// 6. Fetch Billers by Category
  static Future<Map<String, dynamic>> getBillersByCategory(
    String category,
  ) async {
    final res = await ApiService.post('/recharge/billers-by-category', {
      'category': category,
    });

    if (res['status'] == 'error' || (res['billers'] == null && res['data'] == null)) {
      try {
        final directUrl = Uri.parse('https://icchhamatidataservice.com/api/v2/billers-by-category');
        final directResponse = await http.post(
          directUrl,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'category': category}),
        ).timeout(const Duration(seconds: 8));
        final directJson = jsonDecode(directResponse.body);
        if (directJson is Map<String, dynamic>) {
          return directJson;
        }
      } catch (_) {}
    }
    return res;
  }

  /// 7. Fetch Bill Details
  static Future<Map<String, dynamic>> fetchBill({
    required String billerCode,
    required String customerId,
  }) async {
    final res = await ApiService.post('/recharge/fetch-bill', {
      'biller_code': billerCode,
      'customer_id': customerId,
    });

    if (res['status'] == 'error' || (res['billDetails'] == null && res['data'] == null && res['bill_amount'] == null)) {
      try {
        final directUrl = Uri.parse('https://icchhamatidataservice.com/api/v2/fetch-bill');
        final directResponse = await http.post(
          directUrl,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'biller_code': billerCode,
            'customer_id': customerId,
          }),
        ).timeout(const Duration(seconds: 8));
        final directJson = jsonDecode(directResponse.body);
        if (directJson is Map<String, dynamic>) {
          return directJson;
        }
      } catch (_) {}
    }
    return res;
  }

  /// 8. Perform Bill Payment (type = 3)
  static Future<Map<String, dynamic>> payBill({
    required String customerId,
    required String billerCode,
    required double amount,
    String circle = '2',
    String? fetchRefId,
    String? billNumber,
    String? customerName,
    String? dueDate,
  }) async {
    return await ApiService.post('/recharge/bill-payment', {
      'number': customerId,
      'operator': billerCode,
      'amount': amount,
      'circle': circle,
      'type': 3,
      'fetch_ref_id': fetchRefId,
      'bill_number': billNumber,
      'customer_name': customerName,
      'due_date': dueDate,
    });
  }

  /// 9. Check Bill Payment Status
  static Future<Map<String, dynamic>> getBillStatus(String txnid) async {
    return await ApiService.post('/recharge/bill-status', {'txnid': txnid});
  }

  /// 10. Fetch User Recharge & Utility History
  static Future<Map<String, dynamic>> getHistory() async {
    return await ApiService.get('/recharge/history');
  }
}
