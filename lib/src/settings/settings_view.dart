import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<SettingsView> createState() => SettingsState();
}

class SettingsState extends State<SettingsView> {
  static const routeName = '/settings';

  static const String _kPortNameOverlay = 'OVERLAY';
  static const String _kPortNameHome = 'UI';
  final _receivePort = ReceivePort();

  SendPort? homePort;
  bool isPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    
    checkPermissionState();

    if (homePort != null) return;
    final res = IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, _kPortNameHome);

    _receivePort.listen((message) {
      /// TODO: Add notification silencing
    });
  }

  void checkPermissionState() async {
    final status = await FlutterOverlayWindow.isPermissionGranted();
    setState(() {
      isPermissionGranted = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.of(context).size.height * 0.6).toInt();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // Glue the SettingsController to the theme selection DropdownButton.
        //
        // When a user selects a theme from the dropdown list, the
        // SettingsController is updated, which rebuilds the MaterialApp.
        child: Column(children: [
          DropdownButton<ThemeMode>(
            // Read the selected themeMode from the controller
            value: widget.controller.themeMode,
            // Call the updateThemeMode method any time the user selects a theme.
            onChanged: widget.controller.updateThemeMode,
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System Theme'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('Light Theme'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark Theme'),
              )
            ],
          ),
          isPermissionGranted ? TextButton(
            child: const Text('Show Overlay'),
            onPressed: () async {
              if (await FlutterOverlayWindow.isActive()) return;

              await FlutterOverlayWindow.showOverlay(
                overlayTitle: "emsapp",
                overlayContent: "overlayEnabled",
                flag: OverlayFlag.defaultFlag,
                visibility: NotificationVisibility.visibilityPublic,
                positionGravity: PositionGravity.auto,
                height: height,
                width: WindowSize.matchParent,
                startPosition: const OverlayPosition(0, -259));
            }
          ) : TextButton(
            child: const Text('Request Permission'),
            onPressed: () async {
              final bool? result = await FlutterOverlayWindow.requestPermission();
              setState(() {
                isPermissionGranted = result!;
              });
            }
          ),
          isPermissionGranted ? TextButton(
            onPressed: () async {
              homePort ??= IsolateNameServer.lookupPortByName(_kPortNameOverlay);
              homePort?.send('3');
              await FlutterOverlayWindow.moveOverlay(const OverlayPosition(0, -259));
            },
            child: const Text('Send Notification to Frontend')) : const SizedBox()
        ])
      ),
    );
  }
}
