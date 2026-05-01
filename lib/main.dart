import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'supabase_options.dart';
import 'providers/index.dart';
import 'screens/index.dart';
import 'utils/index.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, storageService, userProfileService),
        ),
        ChangeNotifierProvider(
          create: (_) => BluetoothProvider(bluetoothService),
        ),
        ChangeNotifierProvider(
          create: (_) => ECGProvider(bluetoothService),
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
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            themeMode: settingsProvider.themeMode,
            home: const AppHome(),
            debugShowCheckedModeBanner: false,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegistrationScreen(),
              '/home': (context) => const HomeScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/ecg_recordings': (context) => const ECGRecordingsScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Main app home that wraps providers
class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, AuthProvider>(
      builder: (context, settingsProvider, authProvider, _) {
        // Show loading while auth state is being determined
        if (authProvider.isLoading) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'IntelIWave',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Initializing...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show onboarding if not completed
        if (!settingsProvider.onboardingCompleted) {
          return const OnboardingScreen();
        }

        // Show login or home based on auth state
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

/// Error app shown during initialization if something goes wrong
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[900],
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  error,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}