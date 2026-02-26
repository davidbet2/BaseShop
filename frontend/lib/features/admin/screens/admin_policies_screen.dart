import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/cubits/store_config_cubit.dart';
import 'package:baseshop/core/services/store_config_service.dart';

/// Admin screen for editing the store policies content using Markdown.
class AdminPoliciesScreen extends StatefulWidget {
  const AdminPoliciesScreen({super.key});

  @override
  State<AdminPoliciesScreen> createState() => _AdminPoliciesScreenState();
}

class _AdminPoliciesScreenState extends State<AdminPoliciesScreen>
    with SingleTickerProviderStateMixin {
  late final StoreConfigCubit _cubit;
  late final TabController _tabCtrl;
  final _contentCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<StoreConfigCubit>();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadContent();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    // Read from current cubit state
    final currentState = _cubit.state;
    if (currentState is StoreConfigLoaded) {
      _contentCtrl.text = currentState.config.policiesContent;
    }
    // Refresh from API
    await _cubit.loadConfig();
    final state = _cubit.state;
    if (state is StoreConfigLoaded) {
      _contentCtrl.text = state.config.policiesContent;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _cubit.updateConfig(policiesContent: _contentCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Políticas guardadas correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _insertTemplate() {
    const template = '''# Políticas de la Tienda

## 1. Política de Privacidad

Nos comprometemos a proteger la privacidad de nuestros usuarios. Los datos personales recopilados se utilizan únicamente para procesar pedidos y mejorar la experiencia de compra.

### Datos que recopilamos
- Nombre y apellido
- Correo electrónico
- Dirección de envío
- Historial de compras

### Uso de los datos
Sus datos personales se utilizan exclusivamente para:
- Procesar y enviar sus pedidos
- Comunicar el estado de sus órdenes
- Mejorar nuestros servicios

---

## 2. Política de Devoluciones

Aceptamos devoluciones dentro de los **30 días** posteriores a la compra, siempre que el producto se encuentre en su estado original.

### Condiciones
1. El producto debe estar sin usar y en su empaque original
2. Debe presentar el comprobante de compra
3. Los productos en oferta no son reembolsables

### Proceso de devolución
1. Contacte a nuestro equipo de soporte
2. Recibirá las instrucciones de envío
3. El reembolso se procesará en 5-10 días hábiles

---

## 3. Términos y Condiciones

Al utilizar nuestra tienda, usted acepta estos términos y condiciones. Nos reservamos el derecho de modificar estos términos en cualquier momento.

### Precios
- Los precios están sujetos a cambios sin previo aviso
- Los precios incluyen impuestos aplicables

### Envíos
- Los tiempos de entrega son estimados y pueden variar
- No nos hacemos responsables por retrasos del transportista

---

## 4. Contacto

Si tiene preguntas sobre nuestras políticas, contáctenos:
- **Email:** soporte@tienda.com
- **Teléfono:** +57 300 000 0000
''';

    setState(() {
      _contentCtrl.text = template;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Políticas de la Tienda'),
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _saving ? 'Guardando...' : 'Guardar',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
        bottom: _loading
            ? null
            : TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note), text: 'Editar'),
                  Tab(icon: Icon(Icons.visibility), text: 'Vista previa'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ── Editor Tab ──
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Toolbar
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _toolbarButton(
                                  icon: Icons.description_outlined,
                                  label: 'Insertar plantilla',
                                  onTap: () => _showTemplateConfirmDialog(),
                                ),
                                _toolbarButton(
                                  icon: Icons.format_bold,
                                  label: 'Negrita',
                                  onTap: () => _wrapSelection('**', '**'),
                                ),
                                _toolbarButton(
                                  icon: Icons.format_italic,
                                  label: 'Cursiva',
                                  onTap: () => _wrapSelection('_', '_'),
                                ),
                                _toolbarButton(
                                  icon: Icons.title,
                                  label: 'Título',
                                  onTap: () => _insertAtLineStart('## '),
                                ),
                                _toolbarButton(
                                  icon: Icons.format_list_bulleted,
                                  label: 'Lista',
                                  onTap: () => _insertAtLineStart('- '),
                                ),
                                _toolbarButton(
                                  icon: Icons.horizontal_rule,
                                  label: 'Separador',
                                  onTap: () => _insertText('\n\n---\n\n'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: primaryColor),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Usa formato Markdown para dar estilo al texto. '
                                      'Los cambios se reflejan en la pestaña "Vista previa".',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Editor
                            Expanded(
                              child: TextField(
                                controller: _contentCtrl,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Escribe las políticas de tu tienda aquí...\n\n'
                                      'Usa Markdown para dar formato:\n'
                                      '# Título principal\n'
                                      '## Subtítulo\n'
                                      '**texto en negrita**\n'
                                      '- elemento de lista',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Preview Tab ──
                      _contentCtrl.text.trim().isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.description_outlined,
                                      size: 64,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Sin contenido',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Escribe algo en la pestaña "Editar" para ver la vista previa',
                                    style: TextStyle(
                                        color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            )
                          : Markdown(
                              data: _contentCtrl.text,
                              padding: const EdgeInsets.all(20),
                              styleSheet: MarkdownStyleSheet(
                                h1: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                                h2: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                                h3: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                                p: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                                listBullet: const TextStyle(fontSize: 15),
                                horizontalRuleDecoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save),
              label: const Text('Guardar cambios'),
              onPressed: _saving ? null : _save,
            ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  void _showTemplateConfirmDialog() {
    if (_contentCtrl.text.trim().isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Insertar plantilla'),
          content: const Text(
            '¿Deseas reemplazar el contenido actual con una plantilla de ejemplo? '
            'Esta acción sobrescribirá todo el texto existente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _insertTemplate();
              },
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
    } else {
      _insertTemplate();
    }
  }

  void _wrapSelection(String before, String after) {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      // Insert placeholder
      final newText =
          '${text.substring(0, sel.baseOffset)}${before}texto$after${text.substring(sel.baseOffset)}';
      _contentCtrl.text = newText;
      _contentCtrl.selection = TextSelection(
        baseOffset: sel.baseOffset + before.length,
        extentOffset: sel.baseOffset + before.length + 5,
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      final newText =
          '${text.substring(0, sel.start)}$before$selected$after${text.substring(sel.end)}';
      _contentCtrl.text = newText;
      _contentCtrl.selection = TextSelection(
        baseOffset: sel.start + before.length,
        extentOffset: sel.start + before.length + selected.length,
      );
    }
    setState(() {});
  }

  void _insertAtLineStart(String prefix) {
    final text = _contentCtrl.text;
    final offset = _contentCtrl.selection.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0);
    final insertAt = lineStart == -1 ? 0 : lineStart + 1;
    final newText =
        '${text.substring(0, insertAt)}$prefix${text.substring(insertAt)}';
    _contentCtrl.text = newText;
    _contentCtrl.selection =
        TextSelection.collapsed(offset: offset + prefix.length);
    setState(() {});
  }

  void _insertText(String insert) {
    final text = _contentCtrl.text;
    final offset = _contentCtrl.selection.baseOffset.clamp(0, text.length);
    final newText =
        '${text.substring(0, offset)}$insert${text.substring(offset)}';
    _contentCtrl.text = newText;
    _contentCtrl.selection =
        TextSelection.collapsed(offset: offset + insert.length);
    setState(() {});
  }
}
