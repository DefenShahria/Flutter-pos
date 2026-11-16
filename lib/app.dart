import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/transfer_provider.dart';
import 'providers/remote_files_provider.dart';
import 'providers/connectivity_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/transfers_screen.dart';
import 'ui/widgets/global_transfer_banner.dart';

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    NotificationService.instance.onNotificationTap ??= (payload) {
      final nav = PosApp.navigatorKey.currentState;
      if (nav == null) return;
      if (!context.read<AuthProvider>().isLoggedIn) return;
      nav.push(MaterialPageRoute(builder: (_) => const TransfersScreen()));
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransferProvider()),
        ChangeNotifierProvider(create: (_) => RemoteFilesProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: MaterialApp(
        title: 'POS File Transfer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: Colors.blue,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blue,
        ),
        themeMode: ThemeMode.system,
        navigatorKey: navigatorKey,
        builder: (context, child) {
          return Column(
            children: [
              const GlobalTransferBanner(),
              if (child != null) Expanded(child: child),
            ],
          );
        },
        home: const _HomeWrapper(),
      ),
    );
  }
}

class _HomeWrapper extends StatefulWidget {
  const _HomeWrapper();

  @override
  State<_HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<_HomeWrapper> {
  bool _restoring = true;
  bool _notificationHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().restoreSession();
      if (mounted) setState(() => _restoring = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_restoring &&
        context.watch<AuthProvider>().isLoggedIn &&
        !_notificationHandled) {
      _notificationHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final payload = NotificationService.instance.consumeLastTapPayload();
        if (payload != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TransfersScreen()),
          );
        }
      });
    }

    if (_restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return context.watch<AuthProvider>().isLoggedIn
        ? const HomeScreen()
        : const LoginScreen();
  }
}
