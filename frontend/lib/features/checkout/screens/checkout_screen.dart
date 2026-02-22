import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_event.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';
import 'package:baseshop/features/orders/bloc/orders_bloc.dart';
import 'package:baseshop/features/orders/bloc/orders_event.dart';
import 'package:baseshop/features/orders/bloc/orders_state.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final PageController _stepCtrl = PageController();
  int _currentStep = 0; // 0=address, 1=payment, 2=summary
  late final OrdersBloc _ordersBloc;

  List<Map<String, dynamic>> _addresses = [];
  int _selectedAddressIndex = -1;
  String _selectedPayment = '';
  String _notes = '';
  bool _placingOrder = false;

  static const _paymentMethods = [
    {'id': 'cash', 'label': 'Efectivo / Contra entrega', 'icon': Icons.money_rounded, 'desc': 'Paga al recibir tu pedido'},
    {'id': 'transfer', 'label': 'Transferencia bancaria', 'icon': Icons.account_balance_rounded, 'desc': 'Transferencia o depósito'},
    {'id': 'card', 'label': 'Tarjeta de crédito/débito', 'icon': Icons.credit_card_rounded, 'desc': 'Visa, Mastercard, etc.'},
    {'id': 'nequi', 'label': 'Nequi / Daviplata', 'icon': Icons.phone_android_rounded, 'desc': 'Billetera digital'},
  ];

  @override
  void initState() {
    super.initState();
    _ordersBloc = getIt<OrdersBloc>();
    _loadAddresses();
  }

  @override
  void dispose() {
    _stepCtrl.dispose();
    _ordersBloc.close();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_addresses') ?? '[]';
    final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
    setState(() {
      _addresses = list;
      // Select default address
      final defaultIdx = list.indexWhere((a) => a['is_default'] == true);
      _selectedAddressIndex = defaultIdx >= 0 ? defaultIdx : (list.isNotEmpty ? 0 : -1);
    });
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _stepCtrl.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _ordersBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (_currentStep > 0) {
                _goToStep(_currentStep - 1);
              } else {
                context.pop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Step indicator
            _buildStepIndicator(),
            // Pages
            Expanded(
              child: PageView(
                controller: _stepCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAddressStep(),
                  _buildPaymentStep(),
                  _buildSummaryStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Dirección', 'Pago', 'Resumen'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i <= _currentStep;
          final isCompleted = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
                    ),
                  ),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                        : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? Colors.white : AppTheme.textSecondary)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(steps[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary)),
                if (i < steps.length - 1) const Spacer(),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── STEP 1: Address Selection ──
  Widget _buildAddressStep() {
    return Column(
      children: [
        Expanded(
          child: _addresses.isEmpty
              ? _buildNoAddresses()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length + 1, // +1 for "add new" button
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == _addresses.length) {
                      return OutlinedButton.icon(
                        onPressed: () async {
                          await context.push('/addresses');
                          _loadAddresses();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar dirección'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      );
                    }
                    final addr = _addresses[i];
                    final selected = i == _selectedAddressIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAddressIndex = i),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? AppTheme.primaryColor : AppTheme.dividerColor.withValues(alpha: 0.5),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: selected ? AppTheme.primaryColor : AppTheme.textSecondary, size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(addr['label'] ?? 'Dirección', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: selected ? AppTheme.primaryColor : AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(addr['name'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                  Text(addr['address'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                  if ((addr['city'] ?? '').toString().isNotEmpty)
                                    Text('${addr['city']}, ${addr['state'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildBottomButton('Continuar', () {
          if (_selectedAddressIndex < 0) {
            _showSnack('Selecciona una dirección de envío');
            return;
          }
          _goToStep(1);
        }),
      ],
    );
  }

  Widget _buildNoAddresses() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No tienes direcciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Agrega una para continuar', style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/addresses');
              _loadAddresses();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar dirección'),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: Payment Method ──
  Widget _buildPaymentStep() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _paymentMethods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final method = _paymentMethods[i];
              final id = method['id'] as String;
              final selected = id == _selectedPayment;
              return GestureDetector(
                onTap: () => setState(() => _selectedPayment = id),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppTheme.primaryColor : AppTheme.dividerColor.withValues(alpha: 0.5),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primaryColor.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(method['icon'] as IconData, size: 22,
                          color: selected ? AppTheme.primaryColor : AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(method['label'] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: selected ? AppTheme.primaryColor : AppTheme.textPrimary)),
                            Text(method['desc'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: selected ? AppTheme.primaryColor : AppTheme.textSecondary, size: 22,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Notes field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            maxLines: 2,
            onChanged: (v) => _notes = v,
            decoration: InputDecoration(
              hintText: 'Notas adicionales (opcional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        _buildBottomButton('Revisar pedido', () {
          if (_selectedPayment.isEmpty) {
            _showSnack('Selecciona un método de pago');
            return;
          }
          _goToStep(2);
        }),
      ],
    );
  }

  // ── STEP 3: Order Summary ──
  Widget _buildSummaryStep() {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cartState) {
        if (cartState is! CartLoaded) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final items = cartState.items;
        final subtotal = cartState.subtotal;
        const shipping = 0.0; // Free shipping for now
        final total = subtotal + shipping;
        final address = _selectedAddressIndex >= 0 ? _addresses[_selectedAddressIndex] : <String, dynamic>{};
        final payment = _paymentMethods.firstWhere((m) => m['id'] == _selectedPayment, orElse: () => _paymentMethods[0]);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address summary
                    _summarySection(
                      icon: Icons.location_on_rounded,
                      title: 'Enviar a',
                      onEdit: () => _goToStep(0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(address['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${address['name'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          Text('${address['address'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          if ((address['city'] ?? '').toString().isNotEmpty)
                            Text('${address['city']}, ${address['state'] ?? ''} ${address['zip'] ?? ''}',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payment summary
                    _summarySection(
                      icon: payment['icon'] as IconData,
                      title: 'Método de pago',
                      onEdit: () => _goToStep(1),
                      child: Text(payment['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),

                    // Items
                    _summarySection(
                      icon: Icons.shopping_bag_rounded,
                      title: 'Productos (${items.length})',
                      child: Column(
                        children: items.map((item) {
                          final name = (item['product_name'] ?? item['productName'] ?? item['name'] ?? '').toString();
                          final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                          final price = double.tryParse(item['product_price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                Text('x$qty', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                const SizedBox(width: 12),
                                Text(_currency.format(price * qty), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Totals
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          _totalRow('Subtotal', _currency.format(subtotal)),
                          const SizedBox(height: 8),
                          _totalRow('Envío', shipping > 0 ? _currency.format(shipping) : 'Gratis'),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              Text(_currency.format(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.note_rounded, size: 18, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_notes, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            BlocListener<OrdersBloc, OrdersState>(
              listener: (context, state) {
                if (state is OrderCreated) {
                  setState(() => _placingOrder = false);
                  context.read<CartBloc>().add(const ClearCart());
                  context.go('/orders');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('¡Pedido realizado con éxito! 🎉'),
                      backgroundColor: AppTheme.successColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } else if (state is OrdersError) {
                  setState(() => _placingOrder = false);
                  _showSnack(state.message);
                }
              },
              child: _buildBottomButton(
                _placingOrder ? 'Procesando...' : 'Confirmar pedido',
                _placingOrder ? null : () => _placeOrder(items),
              ),
            ),
          ],
        );
      },
    );
  }

  void _placeOrder(List<Map<String, dynamic>> items) {
    setState(() => _placingOrder = true);
    final address = _addresses[_selectedAddressIndex];
    final orderItems = items.map((item) {
      final productId = (item['product_id'] ?? item['productId'] ?? '').toString();
      final productName = (item['product_name'] ?? item['productName'] ?? item['name'] ?? '').toString();
      final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final price = double.tryParse(item['product_price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0;
      final image = (item['product_image'] ?? item['productImage'] ?? item['image'] ?? '').toString();
      return {
        'product_id': productId,
        'product_name': productName,
        'product_image': image,
        'quantity': qty,
        'product_price': price,
      };
    }).toList();

    _ordersBloc.add(CreateOrder(
      items: orderItems,
      shippingAddress: address,
      paymentMethod: _selectedPayment,
      notes: _notes.isNotEmpty ? _notes : null,
    ));
  }

  Widget _summarySection({required IconData icon, required String title, VoidCallback? onEdit, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: const Text('Cambiar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: value == 'Gratis' ? AppTheme.successColor : AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildBottomButton(String label, VoidCallback? onPressed) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }
}
