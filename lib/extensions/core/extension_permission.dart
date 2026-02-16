import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Extension permission definitions
enum ExtensionPermission {
  readEvents(Icons.event_note_rounded),
  addEvents(Icons.add_task_rounded),
  updateEvents(Icons.edit_calendar_rounded),
  deleteEvents(Icons.delete_sweep_rounded),
  readTags(Icons.tag_rounded),
  manageTags(Icons.label_important_rounded),
  manageDb(Icons.storage_rounded),
  fileSystem(Icons.folder_open_rounded),
  notifications(Icons.notifications_active_rounded),
  readCalendar(Icons.calendar_month_rounded),
  writeCalendar(Icons.edit_calendar_rounded),
  network(Icons.language_rounded),
  systemInfo(Icons.info_outline_rounded),
  navigation(Icons.explore_rounded),
  uiInteraction(Icons.touch_app_rounded);

  final IconData icon;

  const ExtensionPermission(this.icon);

  String getLabel(AppLocalizations l10n) {
    switch (this) {
      case ExtensionPermission.readEvents:
        return l10n.extensionPermissionReadEvents;
      case ExtensionPermission.addEvents:
        return l10n.extensionPermissionAddEvents;
      case ExtensionPermission.updateEvents:
        return l10n.extensionPermissionUpdateEvents;
      case ExtensionPermission.deleteEvents:
        return l10n.extensionPermissionDeleteEvents;
      case ExtensionPermission.readTags:
        return l10n.extensionPermissionReadTags;
      case ExtensionPermission.manageTags:
        return l10n.extensionPermissionManageTags;
      case ExtensionPermission.manageDb:
        return l10n.extensionPermissionManageDb;
      case ExtensionPermission.fileSystem:
        return l10n.extensionPermissionFileSystem;
      case ExtensionPermission.notifications:
        return l10n.extensionPermissionNotifications;
      case ExtensionPermission.readCalendar:
        return l10n.extensionPermissionReadCalendar;
      case ExtensionPermission.writeCalendar:
        return l10n.extensionPermissionWriteCalendar;
      case ExtensionPermission.network:
        return l10n.extensionPermissionNetwork;
      case ExtensionPermission.systemInfo:
        return l10n.extensionPermissionSystemInfo;
      case ExtensionPermission.navigation:
        return l10n.extensionPermissionNavigation;
      case ExtensionPermission.uiInteraction:
        return l10n.extensionPermissionUIInteraction;
    }
  }

  String getDescription(AppLocalizations l10n) {
    switch (this) {
      case ExtensionPermission.readEvents:
        return l10n.extensionPermissionReadEventsDesc;
      case ExtensionPermission.addEvents:
        return l10n.extensionPermissionAddEventsDesc;
      case ExtensionPermission.updateEvents:
        return l10n.extensionPermissionUpdateEventsDesc;
      case ExtensionPermission.deleteEvents:
        return l10n.extensionPermissionDeleteEventsDesc;
      case ExtensionPermission.readTags:
        return l10n.extensionPermissionReadTagsDesc;
      case ExtensionPermission.manageTags:
        return l10n.extensionPermissionManageTagsDesc;
      case ExtensionPermission.manageDb:
        return l10n.extensionPermissionManageDbDesc;
      case ExtensionPermission.fileSystem:
        return l10n.extensionPermissionFileSystemDesc;
      case ExtensionPermission.notifications:
        return l10n.extensionPermissionNotificationsDesc;
      case ExtensionPermission.readCalendar:
        return l10n.extensionPermissionReadCalendarDesc;
      case ExtensionPermission.writeCalendar:
        return l10n.extensionPermissionWriteCalendarDesc;
      case ExtensionPermission.network:
        return l10n.extensionPermissionNetworkDesc;
      case ExtensionPermission.systemInfo:
        return l10n.extensionPermissionSystemInfoDesc;
      case ExtensionPermission.navigation:
        return l10n.extensionPermissionNavigationDesc;
      case ExtensionPermission.uiInteraction:
        return l10n.extensionPermissionUIInteractionDesc;
    }
  }
}
