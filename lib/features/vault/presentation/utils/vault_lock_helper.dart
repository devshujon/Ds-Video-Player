import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/presentation/providers/media_library_provider.dart';
import '../providers/vault_provider.dart';
import '../screens/vault_unlock_view.dart';

/// Long-press "Move to Private Vault" entry point from the media library.
class VaultLockHelper {
  VaultLockHelper._();

  static Future<void> showMoveSheet(BuildContext context, MediaItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_rounded),
              title: const Text('Move to Private Vault'),
              subtitle: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                Navigator.pop(ctx);
                await lockMediaItem(context, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> lockMediaItem(BuildContext context, MediaItem item) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final vault = context.read<VaultProvider>();

    if (vault.state == VaultState.needsSetup) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Create your vault first')),
      );
      await Navigator.of(context).pushNamed(Routes.vault);
      return false;
    }

    if (vault.state == VaultState.locked) {
      final unlocked = await _authenticate(context);
      if (!unlocked) return false;
      if (!context.mounted) return false;
    }

    final ok = await context.read<VaultProvider>().lockFromMediaItem(item);
    if (!context.mounted) return ok;

    if (ok) {
      await context.read<MediaLibraryProvider>().removeFromLibrary([item.uri]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved "${item.title}" to Private Vault')),
        );
      }
    } else if (context.mounted) {
      final err = context.read<VaultProvider>().errorText;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Could not move file to vault')),
      );
    }
    return ok;
  }

  static Future<void> showFolderLockSheet(
    BuildContext context,
    String folderPath,
    List<MediaItem> items,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: const Text('Lock entire folder'),
              subtitle: Text(
                '${items.length} files in ${folderPath.split('/').last}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await lockFolder(context, folderPath, items);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> lockFolder(
    BuildContext context,
    String folderPath,
    List<MediaItem> items,
  ) async {
    final vault = context.read<VaultProvider>();

    if (vault.state == VaultState.needsSetup) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create your vault first')),
      );
      await Navigator.of(context).pushNamed(Routes.vault);
      return false;
    }

    if (vault.state == VaultState.locked) {
      final unlocked = await _authenticate(context);
      if (!unlocked || !context.mounted) return false;
    }

    final count = await context.read<VaultProvider>().lockFolder(items);
    if (!context.mounted) return count > 0;

    if (count > 0) {
      await context.read<MediaLibraryProvider>().removeFromLibrary(
            items.map((i) => i.uri).toList(),
          );
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locked $count files from folder')),
      );
      return true;
    }

    if (!context.mounted) return false;
    final err = context.read<VaultProvider>().errorText;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Could not lock folder')),
    );
    return false;
  }

  static Future<bool> _authenticate(BuildContext context) async {
    final vault = context.read<VaultProvider>();
    if (vault.canUseBiometrics) {
      final bio = await vault.unlockWithBiometric(silent: true);
      if (bio == VaultUnlockResult.success) return true;
    }

    if (!context.mounted) return false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SizedBox(
        height: 520,
        child: VaultUnlockView(),
      ),
    );
    return vault.state == VaultState.unlocked;
  }
}
