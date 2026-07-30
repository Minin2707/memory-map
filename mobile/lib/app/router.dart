import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/features/bootstrap/presentation/bootstrap_screen.dart';

final appRouterProvider = Provider<GoRouter>((_) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const BootstrapScreen();
        },
      ),
    ],
  );
});
