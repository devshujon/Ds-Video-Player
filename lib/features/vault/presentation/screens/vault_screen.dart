import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/vault_provider.dart';
import 'vault_create_view.dart';
import 'vault_home_view.dart';
import 'vault_unlock_view.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VaultProvider>().evaluate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, vault, _) {
        return Scaffold(
          extendBodyBehindAppBar: vault.state == VaultState.unlocked,
          appBar: AppBar(
            title: const Text('Private Vault'),
            actions: [
              if (vault.state == VaultState.unlocked)
                IconButton(
                  icon: const Icon(Icons.lock_rounded),
                  tooltip: 'Lock vault',
                  onPressed: vault.lock,
                ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: switch (vault.state) {
              VaultState.needsSetup => const VaultCreateView(
                  key: ValueKey('setup'),
                ),
              VaultState.locked => const VaultUnlockView(
                  key: ValueKey('locked'),
                ),
              VaultState.unlocked => const VaultHomeView(
                  key: ValueKey('home'),
                ),
            },
          ),
          floatingActionButton: vault.state == VaultState.unlocked
              ? FloatingActionButton.extended(
                  onPressed: vault.isImporting
                      ? null
                      : () => VaultHomeView.pickAndImport(context),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Import Files'),
                )
              : null,
          bottomSheet: vault.isImporting
              ? Material(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: vault.importProgress),
                        const SizedBox(height: 8),
                        const Text('Encrypting file…'),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
