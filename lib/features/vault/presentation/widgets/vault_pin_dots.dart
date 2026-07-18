import 'package:flutter/material.dart';

/// Filled-circle PIN indicator with optional shake animation.
class VaultPinDots extends StatefulWidget {
  const VaultPinDots({
    super.key,
    required this.length,
    required this.filled,
    this.shake = false,
    this.success = false,
  });

  final int length;
  final int filled;
  final bool shake;
  final bool success;

  @override
  State<VaultPinDots> createState() => _VaultPinDotsState();
}

class _VaultPinDotsState extends State<VaultPinDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void didUpdateWidget(covariant VaultPinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _shake.forward(from: 0).then((_) => _shake.reset());
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = t == 0
            ? 0.0
            : (t < 0.5 ? t * 28 : (1 - t) * 28) *
                (t < 0.25 || t > 0.75 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          final filled = i < widget.filled;
          final color = widget.success
              ? scheme.tertiary
              : filled
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.45);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: filled ? 16 : 13,
            height: filled ? 16 : 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
