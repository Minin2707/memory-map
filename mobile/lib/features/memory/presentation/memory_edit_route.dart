import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/edit_memory_screen.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class MemoryEditRoute extends ConsumerWidget {
  const MemoryEditRoute({
    required this.memoryId,
    this.onBack,
    this.onPickLocation,
    this.onMemoryUpdated,
    super.key,
  });

  final String memoryId;
  final VoidCallback? onBack;
  final EditMemoryLocationPicker? onPickLocation;
  final ValueChanged<Memory>? onMemoryUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsValue = ref.watch(memoryDetailsProvider(memoryId));

    if (detailsValue.isLoading) {
      return const _MemoryEditRouteScaffold(child: _LoadingView());
    }

    if (detailsValue.hasError) {
      final l10n = AppLocalizations.of(context);
      return _MemoryEditRouteScaffold(
        child: _RouteErrorView(
          title: l10n.unexpectedErrorTitle,
          message: l10n.memoryFailureUnknown,
          onRetry: () {
            ref.read(memoryDetailsProvider(memoryId).notifier).retryLoad();
          },
        ),
      );
    }

    final detailsState = detailsValue.asData?.value;
    if (detailsState == null) {
      return const _MemoryEditRouteScaffold(child: _LoadingView());
    }

    final loadFailure = detailsState.loadFailure;
    if (loadFailure != null) {
      final l10n = AppLocalizations.of(context);
      return _MemoryEditRouteScaffold(
        child: _RouteErrorView(
          title: l10n.memoryDetailsLoadFailureTitle,
          message: memoryFailureMessage(l10n, loadFailure),
          onRetry: () {
            ref.read(memoryDetailsProvider(memoryId).notifier).retryLoad();
          },
        ),
      );
    }

    final memory = detailsState.memory;
    if (memory == null) {
      return const _MemoryEditRouteScaffold(child: _LoadingView());
    }

    return EditMemoryScreen(
      memory: memory,
      onBack: onBack,
      onPickLocation: onPickLocation,
      onMemoryUpdated: onMemoryUpdated,
    );
  }
}

class _MemoryEditRouteScaffold extends StatelessWidget {
  const _MemoryEditRouteScaffold({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: ValueKey('edit-memory.route-loading'),
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: Color(0xFFFF5D72),
      ),
    );
  }
}

class _RouteErrorView extends StatelessWidget {
  const _RouteErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('edit-memory.route-error-view'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            offset: Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            key: const ValueKey('edit-memory.route-error.retry-action'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
