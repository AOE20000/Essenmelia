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
import 'providers/app_lifecycle_provider.dart';
import 'services/notification_service.dart';
import 'services/command_gateway_service.dart';
import 'services/app_initialization_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

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
    Hive.registerAdapter(EventReminderAdapter());

    runApp(const ProviderScope(child: IdleDetector(child: MyApp())));
  } catch (e, stackTrace) {
    debugPrint('Critical Initialization Error: $e\n$stackTrace');
    runApp(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: _DbErrorRecoveryScreen(error: e.toString()),
        ),
      ),
    );
  }
}

class _DbErrorRecoveryScreen extends ConsumerWidget {
  final String error;
  const _DbErrorRecoveryScreen({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storage_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                l10n.dbLoadFailed,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.dbLoadFailedDesc,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _handleExportBackup(context, ref),
                  icon: const Icon(Icons.backup_rounded),
                  label: Text(l10n.forceExportBackup),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleAutoRepair(context, ref),
                  icon: const Icon(Icons.build_circle_rounded),
                  label: Text(l10n.directAutoRepair),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
              const SizedBox(height: 48),
              ExpansionTile(
                title: Text(
                  l10n.errorDetails,
                  style: const TextStyle(fontSize: 14),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExportBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Attempt to read data directly from Hive files if possible
      final metaBox = await Hive.openBox('essenmelia_meta');
      final dbs = List<String>.from(
        metaBox.get('db_list', defaultValue: ['main']),
      );

      Map<String, dynamic> allData = {
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
      };

      for (final db in dbs) {
        try {
          final eventBox = await Hive.openBox<Event>('${db}_events');
          allData['${db}_events'] = eventBox.values
              .map((e) => e.toJson())
              .toList();
        } catch (e) {
          debugPrint('Recovery: Failed to read $db events: $e');
        }
      }

      final jsonString = jsonEncode(allData);
      final bytes = utf8.encode(jsonString);

      if (context.mounted) {
        // Close loading
        Navigator.pop(context);

        final tempDir = await getTemporaryDirectory();
        final file = File(
          p.join(tempDir.path, 'essenmelia_emergency_backup.json'),
        );
        await file.writeAsBytes(bytes);

        await SharePlus.instance.share(
          ShareParams(text: l10n.emergencyBackup, files: [XFile(file.path)]),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.backupComplete)));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.error(e.toString()))));
      }
    }
  }

  Future<void> _handleAutoRepair(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmRepairTitle),
        content: Text(l10n.confirmRepairDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.confirmAndReset),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await Hive.close();

        final appDir = await getApplicationDocumentsDirectory();

        if (Platform.isWindows) {
          final dir = Directory(p.join(appDir.path, 'essenmelia'));
          if (await dir.exists()) await dir.delete(recursive: true);
        } else {
          final hiveDir = Directory(appDir.path);
          final files = hiveDir.listSync();
          for (final file in files) {
            if (file is File &&
                (file.path.endsWith('.hive') || file.path.endsWith('.lock'))) {
              try {
                await file.delete();
              } catch (_) {}
            }
          }
        }

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(l10n.repairComplete),
              content: Text(l10n.repairCompleteDesc),
              actions: [
                FilledButton(
                  onPressed: () => exit(0),
                  child: Text(l10n.closeApp),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.repairFailed(e.toString())}\n${l10n.manualCleanupAdvice}',
              ),
            ),
          );
        }
      }
    }
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
  static const _channel = MethodChannel('org.essenmelia/intent');

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

    // Trigger app-wide initialization service
    // This ensures extensions are loaded only after DB is ready
    ref.watch(appInitializationServiceProvider);

    // Initialize Command Gateway for deep links
    ref.watch(commandGatewayServiceProvider);

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
            // Windows 平台默认字体修复
            if (Platform.isWindows) {
              return baseTheme.copyWith(
                textTheme: baseTheme.textTheme.apply(
                  fontFamily: 'Microsoft YaHei',
                ),
              );
            }
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
