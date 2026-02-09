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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(EventAdapter());
  Hive.registerAdapter(EventStepAdapter());
  Hive.registerAdapter(StepTemplateAdapter());
  Hive.registerAdapter(StepSetTemplateAdapter());
  Hive.registerAdapter(StepSetTemplateStepAdapter());

  // Initialization handled by DbProvider/DbController
  // We only open settings and meta box here if needed, or let provider handle it.
  // Actually, DbController handles DB boxes. SettingsProvider handles settings.
  // We should just let providers initialize lazily or kick them off.

  // Note: We used to open boxes here. Now we delegate to providers.
  // However, for the very first run, we might want to ensure 'main' boxes exist or migration.
  // But DbController._init() handles this logic.

  runApp(const ProviderScope(child: MyApp()));
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/event/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventDetailScreen(eventId: id);
      },
    ),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
