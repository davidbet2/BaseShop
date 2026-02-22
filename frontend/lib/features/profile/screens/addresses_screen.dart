import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:baseshop/core/theme/app_theme.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_addresses') ?? '[]';
    setState(() {
      _addresses = List<Map<String, dynamic>>.from(jsonDecode(raw));
      _loading = false;
    });
  }

  Future<void> _saveAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_addresses', jsonEncode(_addresses));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Mis Direcciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _addresses.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _addresses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final addr = _addresses[i];
        final isDefault = addr['is_default'] == true;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDefault ? AppTheme.primaryColor.withValues(alpha: 0.5) : AppTheme.dividerColor.withValues(alpha: 0.5),
              width: isDefault ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 20,
                    color: isDefault ? AppTheme.primaryColor : AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      addr['label'] ?? 'Dirección',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: isDefault ? AppTheme.primaryColor : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Principal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (val) => _handleMenu(val, i),
                    itemBuilder: (_) => [
                      if (!isDefault) const PopupMenuItem(value: 'default', child: Text('Hacer principal')),
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(addr['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(addr['address'] ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
              if ((addr['city'] ?? '').toString().isNotEmpty)
                Text('${addr['city']}, ${addr['state'] ?? ''} ${addr['zip'] ?? ''}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              if ((addr['phone'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Tel: ${addr['phone']}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _handleMenu(String action, int index) {
    if (action == 'default') {
      setState(() {
        for (var a in _addresses) { a['is_default'] = false; }
        _addresses[index]['is_default'] = true;
      });
      _saveAddresses();
    } else if (action == 'edit') {
      _showAddDialog(editIndex: index);
    } else if (action == 'delete') {
      setState(() => _addresses.removeAt(index));
      _saveAddresses();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Dirección eliminada'), backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      );
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No tienes direcciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Agrega una dirección de envío', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _showAddDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final existing = isEdit ? _addresses[editIndex] : <String, dynamic>{};
    final labelCtrl = TextEditingController(text: (existing['label'] ?? '').toString());
    final nameCtrl = TextEditingController(text: (existing['name'] ?? '').toString());
    final addressCtrl = TextEditingController(text: (existing['address'] ?? '').toString());
    final cityCtrl = TextEditingController(text: (existing['city'] ?? '').toString());
    final stateCtrl = TextEditingController(text: (existing['state'] ?? '').toString());
    final zipCtrl = TextEditingController(text: (existing['zip'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (existing['phone'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isEdit ? 'Editar dirección' : 'Nueva dirección',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 20),
              _field(labelCtrl, 'Etiqueta', 'Ej: Casa, Oficina', Icons.label_outline_rounded),
              _field(nameCtrl, 'Nombre completo', 'Nombre del destinatario', Icons.person_outline_rounded),
              _field(addressCtrl, 'Dirección', 'Calle, número, colonia', Icons.location_on_outlined),
              Row(children: [
                Expanded(child: _field(cityCtrl, 'Ciudad', '', Icons.location_city_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _field(stateCtrl, 'Estado/Depto', '', Icons.map_outlined)),
              ]),
              Row(children: [
                Expanded(child: _field(zipCtrl, 'Código postal', '', Icons.markunread_mailbox_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _field(phoneCtrl, 'Teléfono', '', Icons.phone_outlined)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Nombre y dirección son obligatorios'),
                          backgroundColor: AppTheme.errorColor, behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      );
                      return;
                    }
                    final newAddr = {
                      'label': labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Dirección',
                      'name': nameCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                      'state': stateCtrl.text.trim(),
                      'zip': zipCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'is_default': isEdit ? (existing['is_default'] ?? false) : _addresses.isEmpty,
                    };
                    setState(() {
                      if (isEdit) {
                        _addresses[editIndex] = newAddr;
                      } else {
                        _addresses.add(newAddr);
                      }
                    });
                    _saveAddresses();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Dirección actualizada' : 'Dirección agregada'),
                        backgroundColor: AppTheme.successColor, behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: Text(isEdit ? 'Guardar cambios' : 'Agregar dirección', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isNotEmpty ? hint : null,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
