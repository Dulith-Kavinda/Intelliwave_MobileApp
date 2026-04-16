import 'package:get_it/get_it.dart';
import '../services/index.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register services
  getIt.registerSingleton<StorageService>(StorageService());
  getIt.registerSingleton<AuthService>(AuthService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<NotificationService>(NotificationService());
  getIt.registerSingleton<UserProfileService>(UserProfileService());
}

StorageService get storageService => getIt<StorageService>();
AuthService get authService => getIt<AuthService>();
BluetoothService get bluetoothService => getIt<BluetoothService>();
NotificationService get notificationService => getIt<NotificationService>();
UserProfileService get userProfileService => getIt<UserProfileService>();
