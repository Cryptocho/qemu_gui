// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qemu_gui/main.dart';
import 'package:qemu_gui/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:qemu_gui/services/qemu_service.dart';
import 'package:qemu_gui/services/vm_service.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We need to wrap QemuGuiApp with providers to avoid errors
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: SettingsService()),
          Provider.value(value: QemuService()),
          ChangeNotifierProvider.value(value: VMService()),
        ],
        child: SettingsWrapper(
          initialSettings: Settings(),
          child: const QemuGuiApp(),
        ),
      ),
    );

    // Basic check that the app starts
    expect(find.text('QEMU GUI'), findsOneWidget);
  });
}
