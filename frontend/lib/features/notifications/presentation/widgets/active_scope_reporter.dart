import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/notifications_controller.dart';

/// `ContentPanel` bir kanal/DM mesajlaşma alanını her açtığında bu widget'la
/// sarmalar. Amaç: `NotificationsController`'a "şu an bu kapsam ekranda,
/// buradan gelen mesajlar için bildirim gösterme ve okunmamış sayma"
/// bilgisini iletmek — kanal/DM değiştiğinde veya ekran kapandığında bunu
/// güncel tutar.
class ActiveScopeReporter extends ConsumerStatefulWidget {
  const ActiveScopeReporter({required this.scopeKey, required this.child, super.key});

  final String scopeKey;
  final Widget child;

  @override
  ConsumerState<ActiveScopeReporter> createState() => _ActiveScopeReporterState();
}

class _ActiveScopeReporterState extends ConsumerState<ActiveScopeReporter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(covariant ActiveScopeReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey) _report();
  }

  void _report() {
    if (!mounted) return;
    ref.read(notificationsControllerProvider.notifier).setActiveScope(widget.scopeKey);
  }

  @override
  void dispose() {
    ref.read(notificationsControllerProvider.notifier).setActiveScope(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
