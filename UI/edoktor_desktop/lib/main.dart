import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/notification_provider.dart';
import 'providers/providers.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'services/api_client.dart';
import 'services/auth_store.dart';
import 'services/report_pdf.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Shared so the 401 handler below can also stop SignalR.
final notificationProvider = NotificationProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.load();
  await ReportPdf.loadFonts();

  // On a 401 from the API, clear the session and return to the login screen.
  ApiClient.onUnauthorized = () {
    notificationProvider.disconnect();
    AuthStore.clear();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  runApp(const EDoktorAdminApp());
}

class EDoktorAdminApp extends StatelessWidget {
  const EDoktorAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => SpecializationProvider()),
        ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ChangeNotifierProvider(create: (_) => CountryProvider()),
        ChangeNotifierProvider(create: (_) => CityProvider()),
        ChangeNotifierProvider(create: (_) => DoctorProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => MedicalRecordProvider()),
        ChangeNotifierProvider.value(value: notificationProvider),
      ],
      child: MaterialApp(
        title: 'eDoktor Admin',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), primary: const Color(0xFF2E7D32)),
          scaffoldBackgroundColor: const Color(0xFFF1F6F2),
          useMaterial3: true,
        ),
        home: AuthStore.token != null && (AuthStore.user?.role == 'admin' || AuthStore.user?.role == 'doctor')
            ? const ShellScreen()
            : const LoginScreen(),
      ),
    );
  }
}
