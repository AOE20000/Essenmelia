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
import 'screens/edit_event_sheet.dart';
import 'extensions/core/globals.dart' show navigatorKey;
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务（非阻塞）
  NotificationService().init().catchError((e) {
    debugPrint('Notification Service Init Error: $e');
  });

  // 启用 Edge-to-Edge 沉浸式体验
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(EventAdapter());
    Hive.registerAdapter(EventStepAdapter());
    Hive.registerAdapter(StepTemplateAdapter());
    Hive.registerAdapter(StepSetTemplateAdapter());
    Hive.registerAdapter(StepSetTemplateStepAdapter());

    runApp(const ProviderScope(child: MyApp()));
  } catch (e, stackTrace) {
    debugPrint('Critical Initialization Error: $e\n$stackTrace');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'App Initialization Failed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $e\n\nPlease try restarting the app or contact developers.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        child: const EditEventSheet(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          );
        },
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

  void _initIntentHandler() {
    // 监听 Intent (Native -> Flutter)
    _channel.setMethodCallHandler((call) async {
      try {
        if (call.method == 'onQuickAction') {
          final String? action = call.arguments as String?;
          _handleAction(action);
        }
      } catch (e) {
        debugPrint('MethodChannel Error: $e');
      }
    });
  }

  void _handleAction(String? action) {
    if (action == 'ACTION_QUICK_EVENT') {
      // 检查当前路由，避免重复打开快速操作界面
      final currentRoute =
          _router.routerDelegate.currentConfiguration.last.matchedLocation;
      if (currentRoute != '/quick-action') {
        _router.push('/quick-action');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeModeOption = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightColorScheme =
            lightDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            );
        final ColorScheme darkColorScheme =
            darkDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            );

        final themeMode = switch (themeModeOption) {
          ThemeModeOption.system => ThemeMode.system,
          ThemeModeOption.light => ThemeMode.light,
          ThemeModeOption.dark => ThemeMode.dark,
        };

        // 构建主题
        ThemeData buildTheme(ColorScheme colorScheme) {
          final isDark = colorScheme.brightness == Brightness.dark;
          final baseTheme = ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
              ),
            ),
          );

          if (displaySettings.useSystemFont) {
            return baseTheme;
          } else {
            // 使用内置 MD3 字体 (Roboto)
            return baseTheme.copyWith(
              textTheme: GoogleFonts.robotoTextTheme(baseTheme.textTheme),
            );
          }
        }

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
          themeMode: themeMode,
          theme: buildTheme(lightColorScheme),
          darkTheme: buildTheme(darkColorScheme),
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
