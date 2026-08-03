import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  // Faz 6.4: mesaj zaman damgaları `tr_TR` yerelinde biçimlendirilir (bkz.
  // `message_bubble.dart` — `DateFormat('d MMM HH:mm', 'tr_TR')`).
  await initializeDateFormatting('tr_TR');
  runApp(const ProviderScope(child: VyronApp()));
}
