import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/cubits/store_config_cubit.dart';
import 'package:baseshop/core/services/store_config_service.dart';

/// User-facing screen that displays the store policies rendered from Markdown.
class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  late final StoreConfigCubit _cubit;
  String _content = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<StoreConfigCubit>();
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    try {
      // Try current cubit state first
      final currentState = _cubit.state;
      if (currentState is StoreConfigLoaded) {
        _content = currentState.config.policiesContent;
      }
      // Refresh from API
      await _cubit.loadConfig();
      final state = _cubit.state;
      if (state is StoreConfigLoaded) {
        _content = state.config.policiesContent;
      }
    } catch (e) {
      _error = 'No se pudieron cargar las políticas';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Políticas'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadPolicies();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _content.trim().isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.policy_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Políticas no disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Las políticas de la tienda aún no han sido configuradas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : Markdown(
                      data: _content,
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
    );
  }
}
