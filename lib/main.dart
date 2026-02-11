import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/event.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/home_page.dart';
import 'screens/event_detail_screen.dart';
import 'extensions/extension_manager.dart' show navigatorKey;
import 'features/quick_action/quick_action_screen.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(EventAdapter());
  Hive.registerAdapter(EventStepAdapter());
  Hive.registerAdapter(StepTemplateAdapter());
  Hive.registerAdapter(StepSetTemplateAdapter());
  Hive.registerAdapter(StepSetTemplateStepAdapter());

  runApp(const ProviderScope(child: MyApp()));
}

final _router = GoRouter(
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/event/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventDetailScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/quick-action',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const QuickActionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        opaque: false,
      ),
    ),
  ],
);

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  static const _channel = MethodChannel('com.example.essenmelia/intent');

  @override
  void initState() {
    super.initState();
    _initIntentHandler();
  }

  void _initIntentHandler() async {
    // 处理初始 Intent
    try {
      final String? action = await _channel.invokeMethod('getInitialIntent');
      _handleAction(action);
    } catch (e) {
      debugPrint('Error getting initial intent: $e');
    }

    // 监听后续 Intent
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final String? action = call.arguments as String?;
        _handleAction(action);
      }
    });
  }

  void _handleAction(String? action) {
    if (action == 'ACTION_QUICK_EVENT') {
      _router.push('/quick-action');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Essenmelia',
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
      ),
      routerConfig: _router,
    );
  }
}
