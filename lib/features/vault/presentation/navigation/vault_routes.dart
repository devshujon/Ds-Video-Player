import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/vault_category.dart';
import '../screens/vault_category_screen.dart';

/// Vault-specific routes. Registered from [AppRouter].
class VaultRoutes {
  VaultRoutes._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.vaultCategory:
        final category = settings.arguments as VaultCategory?;
        if (category == null) {
          return null;
        }
        return MaterialPageRoute(
          builder: (_) => VaultCategoryScreen(category: category),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
