import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/iap_product.dart';
import '../providers/premium_provider.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const List<String> _perks = [
    'Remove all ads',
    'AMOLED & custom themes',
    'Custom equalizer presets',
    'Unlimited private vault',
    'Cloud sync & floating player',
    'Priority updates',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final premium = context.watch<PremiumProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('DS Premium')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Hero(isPremium: premium.isPremium),
          const SizedBox(height: 20),
          ..._perks.map((p) => ListTile(
                leading: Icon(Icons.check_circle, color: scheme.primary),
                title: Text(p),
                dense: true,
              )),
          const SizedBox(height: 12),
          if (!premium.isPremium) _Plans(premium: premium),
          if (premium.errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              premium.errorText!,
              style: TextStyle(color: scheme.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.isPremium});
  final bool isPremium;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium,
              color: Colors.white, size: 56),
          const SizedBox(height: 8),
          Text(
            isPremium ? 'You are Premium ✨' : 'Unlock everything',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Plans extends StatelessWidget {
  const _Plans({required this.premium});
  final PremiumProvider premium;

  @override
  Widget build(BuildContext context) {
    if (premium.isLoadingProducts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!premium.isBillingAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Billing is unavailable on this device. '
          'Make sure Google Play is signed in and try again.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    if (premium.products.isEmpty) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Plans aren\'t configured for this build yet. '
              'They will appear here once the SKUs are published on Play Console.',
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: premium.loadProducts,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    // Sort: lifetime first (highlighted), then yearly, then monthly.
    final ordered = [...premium.products]..sort(_compareType);

    return Column(
      children: [
        for (final p in ordered)
          _PlanCard(
            product: p,
            highlighted: p.type == IapProductType.lifetime,
            disabled: premium.isPurchasing,
            onTap: () => context.read<PremiumProvider>().purchase(p),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              premium.isPurchasing ? null : context.read<PremiumProvider>().restore,
          child: const Text('Restore purchases'),
        ),
      ],
    );
  }

  int _compareType(IapProduct a, IapProduct b) =>
      _rank(a.type).compareTo(_rank(b.type));

  int _rank(IapProductType t) => switch (t) {
        IapProductType.lifetime => 0,
        IapProductType.yearly => 1,
        IapProductType.monthly => 2,
      };
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.onTap,
    required this.highlighted,
    required this.disabled,
  });
  final IapProduct product;
  final VoidCallback onTap;
  final bool highlighted;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (highlighted)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(_subtitleFor(product)),
        trailing: FilledButton(
          onPressed: disabled ? null : onTap,
          child: Text(product.price),
        ),
      ),
    );
  }

  String _subtitleFor(IapProduct p) => switch (p.type) {
        IapProductType.lifetime => 'One-time payment',
        IapProductType.yearly => 'Per year · auto-renews',
        IapProductType.monthly => 'Per month · auto-renews',
      };
}
