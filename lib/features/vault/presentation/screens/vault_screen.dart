import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/vault_repository.dart';
import '../../domain/entities/vault_item.dart';
import '../providers/vault_provider.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VaultProvider(
        sl<SecureStorageService>(),
        sl<VaultRepository>(),
      )..evaluate(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Private Vault'),
          actions: [
            Consumer<VaultProvider>(
              builder: (context, v, _) => v.state == VaultState.unlocked
                  ? IconButton(
                      icon: const Icon(Icons.lock),
                      tooltip: 'Lock vault',
                      onPressed: v.lock,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: Consumer<VaultProvider>(
          builder: (context, v, _) {
            switch (v.state) {
              case VaultState.needsSetup:
                return _PinForm(
                  title: 'Set a vault PIN',
                  cta: 'Create vault',
                  onSubmit: v.setupPin,
                );
              case VaultState.locked:
                return _LockedView(v: v);
              case VaultState.unlocked:
                return _UnlockedView(v: v);
            }
          },
        ),
        floatingActionButton: Consumer<VaultProvider>(
          builder: (context, v, _) => v.state == VaultState.unlocked
              ? FloatingActionButton.extended(
                  onPressed: v.isImporting ? null : () => _pickAndImport(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add file'),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> _pickAndImport(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null || !context.mounted) return;
    final delete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete original?'),
        content: const Text(
          'The file will be encrypted into the vault. '
          'Optionally remove the original copy from outside the vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep original'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete original'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    await context.read<VaultProvider>().importFile(
          File(path),
          deleteOriginal: delete ?? false,
        );
  }
}

class _UnlockedView extends StatelessWidget {
  const _UnlockedView({required this.v});
  final VaultProvider v;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (v.isImporting)
          LinearProgressIndicator(value: v.importProgress)
        else if (v.errorText != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(12),
            child: Text(
              v.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: v.items.isEmpty
              ? const _EmptyVault()
              : ListView.separated(
                  itemCount: v.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = v.items[i];
                    return ListTile(
                      leading: Icon(_iconFor(item.type)),
                      title: Text(
                        item.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(Formatters.fileSize(item.sizeBytes)),
                      trailing: PopupMenuButton<_Action>(
                        onSelected: (a) => _onAction(context, a, item),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _Action.export,
                            child: Text('Export'),
                          ),
                          PopupMenuItem(
                            value: _Action.delete,
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _onAction(
    BuildContext context,
    _Action a,
    VaultItem item,
  ) async {
    switch (a) {
      case _Action.export:
        final dir = await getApplicationDocumentsDirectory();
        final dest = File(p.join(dir.path, 'exports', item.originalName));
        await dest.parent.create(recursive: true);
        if (!context.mounted) return;
        final out =
            await context.read<VaultProvider>().exportFile(item, dest);
        if (out != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to ${out.path}')),
          );
        }
      case _Action.delete:
        if (!context.mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete from vault?'),
            content: Text(
              '"${item.originalName}" will be permanently removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await context.read<VaultProvider>().delete(item);
        }
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'video' => Icons.movie_outlined,
        'audio' => Icons.music_note_outlined,
        'image' => Icons.image_outlined,
        _ => Icons.insert_drive_file_outlined,
      };
}

enum _Action { export, delete }

class _EmptyVault extends StatelessWidget {
  const _EmptyVault();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open, size: 48),
            const SizedBox(height: 8),
            const Text('Vault is empty'),
            const SizedBox(height: 4),
            Text(
              'Tap "Add file" to encrypt a file into the vault.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _LockedView extends StatelessWidget {
  const _LockedView({required this.v});
  final VaultProvider v;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock, size: 56),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.fingerprint),
          label: const Text('Unlock with biometrics'),
          onPressed: () async {
            final ok = await v.unlockWithBiometric();
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Biometric failed')),
              );
            }
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 240,
          child: _PinForm(
            title: 'Or enter PIN',
            cta: 'Unlock',
            onSubmit: v.unlockWithPin,
          ),
        ),
      ],
    );
  }
}

class _PinForm extends StatefulWidget {
  const _PinForm({
    required this.title,
    required this.cta,
    required this.onSubmit,
  });
  final String title;
  final String cta;
  final Future<bool> Function(String) onSubmit;

  @override
  State<_PinForm> createState() => _PinFormState();
}

class _PinFormState extends State<_PinForm> {
  final _c = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            decoration: InputDecoration(
              hintText: 'PIN (min 4 digits)',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final ok = await widget.onSubmit(_c.text);
              if (!ok) setState(() => _error = 'Invalid PIN');
            },
            child: Text(widget.cta),
          ),
        ],
      ),
    );
  }
}
