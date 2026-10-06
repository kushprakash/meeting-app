import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Result wrapper for Easebuzz Native SDK execution
class EasebuzzPgResult {
  final String result; // e.g. 'payment_successfull', 'user_cancelled', 'payment_failed'
  final String paymentResponse;

  EasebuzzPgResult({
    required this.result,
    required this.paymentResponse,
  });

  bool get isSuccess => result.toLowerCase().contains('success');
  bool get isCancelled => result.toLowerCase().contains('cancel');

  @override
  String toString() {
    return 'EasebuzzPgResult(result: $result, paymentResponse: $paymentResponse)';
  }
}

/// Service class to communicate with Easebuzz Native Android SDK via MethodChannel
class EasebuzzPgService {
  static const MethodChannel _channel =
      MethodChannel('com.bestrecharge.app/easebuzz_pg');

  /// Launch Easebuzz Native Android SDK payment flow
  static Future<EasebuzzPgResult> payWithEasebuzz({
    required String accessKey,
    required String env, // 'prod' or 'test'
  }) async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('payWithEasebuzz', {
        'access_key': accessKey,
        'pay_mode': env,
      });

      if (res != null) {
        return EasebuzzPgResult(
          result: (res['result'] ?? '').toString(),
          paymentResponse: (res['payment_response'] ?? '').toString(),
        );
      }
      return EasebuzzPgResult(
        result: 'user_cancelled',
        paymentResponse: 'No response',
      );
    } on PlatformException catch (e) {
      debugPrint('Easebuzz PlatformException: ${e.message}');
      return EasebuzzPgResult(
        result: 'error',
        paymentResponse: e.message ?? 'Platform error',
      );
    } catch (e) {
      debugPrint('Easebuzz Error: $e');
      return EasebuzzPgResult(
        result: 'error',
        paymentResponse: e.toString(),
      );
    }
  }
}
