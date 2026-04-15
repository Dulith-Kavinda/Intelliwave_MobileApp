import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'supabase_options.dart';
import 'constants/app_theme.dart';
import 'providers/index.dart';
import 'screens/index.dart';
import 'services/index.dart';
import 'utils/index.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseOptions.url,
    anonKey: SupabaseOptions.anonKey,
  );

  // Setup service locator
  setupServiceLocator();

  // Initialize storage service
  await storageService.initialize();

  // Initialize Bluetooth service
  bluetoothService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => BluetoothProvider(bluetoothService),
        ),
        ChangeNotifierProvider(
          create: (_) => HeartbeatProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => TimedCheckProvider(storageService),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp(
            title: 'IntelIWave',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: settingsProvider.themeMode,
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isAuthenticated) {
                  return const HomeScreen();
                }
                return const LoginScreen();
              },
            ),
            routes: AppRoutes.getRoutes(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
