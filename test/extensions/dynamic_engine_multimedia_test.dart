import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:essenmelia_flutter/extensions/runtime/view/dynamic_engine.dart';
import 'package:essenmelia_flutter/extensions/runtime/js/extension_js_engine.dart';
import 'package:essenmelia_flutter/extensions/core/extension_metadata.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:essenmelia_flutter/l10n/app_localizations.dart';

// Mock ExtensionJsEngine
class MockExtensionJsEngine implements ExtensionJsEngine {
  @override
  final ExtensionMetadata metadata;

  @override
  final Map<String, dynamic> state = {};

  @override
  bool get isInitialized => true;

  @override
  String? get error => null;

  MockExtensionJsEngine({required this.metadata});

  @override
  Future<void> init() async {}

  @override
  void setOnStateChanged(VoidCallback? callback) {}

  @override
  ValueNotifier<dynamic> getStateNotifier(String key) {
    return ValueNotifier(state[key]);
  }

  @override
  Future<dynamic> callFunction(String name, [dynamic params]) async {}

  @override
  void updateStateSilent(String? key, dynamic value) {
    if (key != null) state[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('DynamicEngine renders markdown component', (
    WidgetTester tester,
  ) async {
    final metadata = ExtensionMetadata(
      id: 'test_md',
      name: 'Test Markdown',
      description: 'Test Description',
      icon: Icons.extension,
      version: '1.0.0',
      script: 'main.js',
      view: {
        'type': 'markdown',
        'props': {'data': '# Hello Markdown', 'selectable': true},
      },
    );

    final engine = MockExtensionJsEngine(metadata: metadata);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          home: DynamicEngine(engine: engine),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Hello Markdown'), findsOneWidget);
  });

  testWidgets('DynamicEngine renders novel component', (
    WidgetTester tester,
  ) async {
    final metadata = ExtensionMetadata(
      id: 'test_novel',
      name: 'Test Novel',
      description: 'Test Description',
      icon: Icons.extension,
      version: '1.0.0',
      script: 'main.js',
      view: {
        'type': 'novel',
        'props': {'text': 'Once upon a time...', 'fontSize': 20},
      },
    );

    final engine = MockExtensionJsEngine(metadata: metadata);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          home: DynamicEngine(engine: engine),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Once upon a time...'), findsOneWidget);
    // Verify it's in a container with padding (default or specified)
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets(
    'DynamicEngine renders video component (error state without platform)',
    (WidgetTester tester) async {
      final metadata = ExtensionMetadata(
        id: 'test_video',
        name: 'Test Video',
        description: 'Test Description',
        icon: Icons.extension,
        version: '1.0.0',
        script: 'main.js',
        view: {
          'type': 'video',
          'props': {'url': 'https://example.com/video.mp4', 'autoPlay': false},
        },
      );

      final engine = MockExtensionJsEngine(metadata: metadata);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh')],
            home: DynamicEngine(engine: engine),
          ),
        ),
      );

      // Pump enough time for async initialization to fail
      await tester.pumpAndSettle();

      // Verify error state
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to load video'), findsOneWidget);
    },
  );
}
