import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Banking-style numeric keypad — no system keyboard.
class VaultNumericKeypad extends StatelessWidget {
  const VaultNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];

  void _tap(String key) {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    if (key == 'del') {
      onBackspace();
    } else if (key.isNotEmpty) {
      onDigit(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 88, height: 72);
              }
              final isDelete = key == 'del';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: enabled ? () => _tap(key) : null,
                    borderRadius: BorderRadius.circular(36),
                    child: Ink(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDelete
                            ? Colors.transparent
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: 0.65),
                        border: isDelete
                            ? null
                            : Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.25),
                              ),
                      ),
                      child: Center(
                        child: isDelete
                            ? Icon(
                                Icons.backspace_outlined,
                                color: enabled
                                    ? scheme.onSurface
                                    : scheme.onSurface.withValues(alpha: 0.3),
                                size: 26,
                              )
                            : Text(
                                key,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: enabled
                                          ? scheme.onSurface
                                          : scheme.onSurface
                                              .withValues(alpha: 0.3),
                                    ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(growable: false),
    );
  }
}
