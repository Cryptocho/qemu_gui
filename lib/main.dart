import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'services/qemu_service.dart';
import 'services/vm_service.dart';
import 'models/vm_config.dart';
import 'views/home_view.dart';
import 'views/settings_view.dart';
import 'views/image_manager_view.dart';
import 'views/vm_wizard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = SettingsService();
  final settings = await settingsService.loadSettings();
  final vmService = VMService();
  await vmService.loadVMs();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: settingsService),
        Provider.value(value: QemuService()),
        ChangeNotifierProvider.value(value: vmService),
      ],
      child: SettingsWrapper(
        initialSettings: settings,
        child: const QemuGuiApp(),
      ),
    ),
  );
}

class SettingsWrapper extends StatefulWidget {
  final Settings initialSettings;
  final Widget child;

  const SettingsWrapper({super.key, required this.initialSettings, required this.child});

  static _SettingsWrapperState of(BuildContext context) {
    return context.findAncestorStateOfType<_SettingsWrapperState>()!;
  }

  @override
  _SettingsWrapperState createState() => _SettingsWrapperState();
}

class _SettingsWrapperState extends State<SettingsWrapper> {
  late Settings state;

  @override
  void initState() {
    super.initState();
    state = widget.initialSettings;
  }

  void update(Settings newState) {
    setState(() {
      state = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Provider<Settings>.value(
      value: state,
      child: widget.child,
    );
  }
}

// Keep the name for backward compatibility in SettingsView if needed, or just use SettingsWrapper
typedef StatefulProvider = SettingsWrapper;

class QemuGuiApp extends StatelessWidget {
  const QemuGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QEMU GUI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/wizard') {
          final vm = settings.arguments as VMConfig?;
          return MaterialPageRoute(builder: (context) => VMWizardView(existingVM: vm));
        }
        return null;
      },
      routes: {
        '/': (context) => const HomeView(),
        '/settings': (context) => const SettingsView(),
        '/images': (context) => const ImageManagerView(),
      },
    );
  }
}
