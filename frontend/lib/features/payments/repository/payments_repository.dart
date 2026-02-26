import 'package:dio/dio.dart';
import 'package:baseshop/core/network/api_client.dart';
import 'package:baseshop/core/constants/api_constants.dart';

class PaymentsRepository {
  final ApiClient _apiClient;

  PaymentsRepository(this._apiClient);

  /// Create a payment intent for an order.
  /// Returns payment data including `payu_form_data` with all fields
  /// needed to redirect the user to PayU checkout.
  Future<Map<String, dynamic>> createPayment({
    required String orderId,
    required double amount,
    required String buyerEmail,
    required String buyerName,
    String? paymentMethod,
    String? description,
    String currency = 'COP',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.createPayment,
        data: {
          'order_id': orderId,
          'amount': amount,
          'buyer_email': buyerEmail,
          'buyer_name': buyerName,
          'payment_method': paymentMethod ?? '',
          'description': description ?? 'Pago orden $orderId',
          'currency': currency,
        },
      );
      return Map<String, dynamic>.from(response.data['data'] ?? response.data);
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['error'] ?? 'Error al crear el pago');
      }
      throw Exception('Error de conexión con el servidor');
    }
  }

  /// Get payment status for a specific order.
  Future<Map<String, dynamic>> getPaymentByOrder(String orderId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.paymentByOrder}/$orderId',
      );
      return Map<String, dynamic>.from(response.data['data'] ?? response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('No se encontró pago para esta orden');
      }
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['error'] ?? 'Error al consultar el pago');
      }
      throw Exception('Error de conexión con el servidor');
    }
  }

  /// Validate PayU response params and update payment status.
  /// Called after PayU redirects back to the app with response parameters.
  Future<Map<String, dynamic>> validatePayUResponse(Map<String, dynamic> params) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.validatePaymentResponse,
        data: params,
      );
      return Map<String, dynamic>.from(response.data['data'] ?? response.data);
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['error'] ?? 'Error al validar la respuesta');
      }
      throw Exception('Error de conexión con el servidor');
    }
  }
}
