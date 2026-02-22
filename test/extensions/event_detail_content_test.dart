import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:essenmelia_flutter/extensions/services/ui_extension_service.dart';
import 'package:essenmelia_flutter/extensions/runtime/api/extension_api_registry.dart';

void main() {
  test(
    'registerEventDetailContent API updates eventDetailContentProvider',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Initialize the UI extension service (this registers the handlers)
      container.read(uiExtensionServiceProvider);

      // 2. Get the registry and the handler
      final registry = container.read(extensionApiRegistryProvider);
      final handler = registry.getHandler('registerEventDetailContent');

      expect(
        handler,
        isNotNull,
        reason: 'Handler for registerEventDetailContent should be registered',
      );

      // 3. Invoke the handler with test data
      final eventId = 'test-event-123';
      final extensionId = 'test-extension-abc';
      final content = {'type': 'text', 'value': 'Hello World'};
      final title = 'My Extension Tab';

      await handler!({
        'eventId': eventId,
        'extensionId': extensionId,
        'content': content,
        'title': title,
      }, isUntrusted: false);

      // 4. Verify the provider state
      final state = container.read(eventDetailContentProvider);

      expect(
        state.containsKey(eventId),
        isTrue,
        reason: 'Provider should contain entry for eventId',
      );
      final eventContentList = state[eventId]!;
      expect(eventContentList.length, 1);
      expect(eventContentList.first['extensionId'], extensionId);
      expect(eventContentList.first['content'], content);
      expect(eventContentList.first['title'], title);

      // 5. Update content for the same extension (should replace)
      final newContent = {
        'type': 'image',
        'url': 'http://example.com/image.png',
      };
      await handler({
        'eventId': eventId,
        'extensionId': extensionId,
        'content': newContent,
        'title': title,
      }, isUntrusted: false);

      final updatedState = container.read(eventDetailContentProvider);
      final updatedList = updatedState[eventId]!;
      expect(
        updatedList.length,
        1,
        reason: 'Should still have only 1 item (replaced)',
      );
      expect(updatedList.first['content'], newContent);

      // 6. Add content from another extension (should append)
      final extensionId2 = 'test-extension-def';
      await handler({
        'eventId': eventId,
        'extensionId': extensionId2,
        'content': content,
        'title': 'Another Tab',
      }, isUntrusted: false);

      final finalState = container.read(eventDetailContentProvider);
      final finalList = finalState[eventId]!;
      expect(finalList.length, 2, reason: 'Should have 2 items now');
      expect(finalList.any((e) => e['extensionId'] == extensionId), isTrue);
      expect(finalList.any((e) => e['extensionId'] == extensionId2), isTrue);
    },
  );
}
