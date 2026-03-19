// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:overlay_support/overlay_support.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/chat_theme_provider.dart';
import 'services/api_service.dart';
import 'utils/app_theme.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/new_chat_screen.dart';
import 'screens/group/create_group_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService().init();

  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:      Colors.transparent,
    statusBarBrightness: Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ChatThemeProvider()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();

    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: auth,
      redirect: (context, state) {
        final status    = auth.status;
        final loggingIn = state.matchedLocation.startsWith('/auth');

        if (status == AuthStatus.unknown) return '/splash';

        if (status == AuthStatus.unauthenticated) {
          return loggingIn ? null : '/auth/login';
        }

        if (status == AuthStatus.authenticated) {
          if (loggingIn || state.matchedLocation == '/splash') return '/';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/splash',
            builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/auth/login',
            builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/auth/register',
            builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/',
            builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) => ChatScreen(
            conversationId:   int.parse(state.pathParameters['id']!),
            conversationName: state.extra as String? ?? '',
          ),
        ),
        GoRoute(path: '/new-chat',
            builder: (_, __) => const NewChatScreen()),
        GoRoute(path: '/new-group',
            builder: (_, __) => const CreateGroupScreen()),
        GoRoute(path: '/profile',
            builder: (_, __) => const ProfileScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      // ── Wrap everything in OverlaySupport ────────────────────────
      child: MaterialApp.router(
        title:                      'WhatsApp',
        debugShowCheckedModeBanner: false,
        theme:                      AppTheme.light(),
        darkTheme:                  AppTheme.dark(),
        themeMode:                  ThemeMode.system,
        routerConfig:               _router,
      ),
    );
  }
}
