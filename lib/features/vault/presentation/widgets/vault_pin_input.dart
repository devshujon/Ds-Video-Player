import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium PIN entry with dot indicators and optional shake on error.
class VaultPinInput extends StatefulWidget {
  const VaultPinInput({
    super.key,
    required this.length,
    this.maxLength = 8,
    this.onChanged,
    this.onCompleted,
    this.errorText,
    this.shakeKey = 0,
    this.hint = 'Enter PIN',
  });

  final int length;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final String? errorText;
  final int shakeKey;
  final String hint;

  @override
  State<VaultPinInput> createState() => _VaultPinInputState();
}

class _VaultPinInputState extends State<VaultPinInput>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _controller.addListener(() {
      widget.onChanged?.call(_controller.text);
      if (_controller.text.length >= widget.length) {
        widget.onCompleted?.call(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant VaultPinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeKey != oldWidget.shakeKey && widget.errorText != null) {
      _runShake();
    }
  }

  Future<void> _runShake() async {
    await _shake.forward(from: 0);
    _shake.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pin = _controller.text;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = (t < 0.5 ? t * 24 : (1 - t) * 24) * (t < 0.25 || t > 0.75 ? 1 : -1);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.maxLength.clamp(4, 8), (i) {
                final filled = i < pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: filled ? 14 : 12,
                  height: filled ? 14 : 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.45),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: 0.01,
          child: SizedBox(
            height: 1,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: widget.maxLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(counterText: '', hintText: widget.hint),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// Simple strength meter for PIN setup.
class VaultPinStrength extends StatelessWidget {
  const VaultPinStrength({super.key, required this.pin});

  final String pin;

  int get _score {
    if (pin.length < 4) return 0;
    var score = 1;
    if (pin.length >= 6) score++;
    if (pin.length >= 8) score++;
    if (RegExp(r'(.)\1{2,}').hasMatch(pin)) score--;
    if (pin == pin.split('').reversed.join()) score--;
    return score.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = ['Too short', 'Weak', 'Good', 'Strong'];
    final colors = [
      scheme.outline,
      scheme.error,
      scheme.tertiary,
      scheme.primary,
    ];
    final score = _score;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: i < score
                      ? colors[score]
                      : scheme.surfaceContainerHighest,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          labels[score],
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors[score],
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
