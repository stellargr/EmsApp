import 'dart:isolate';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_service.dart';

/// A class that many Widgets can interact with to read user settings, update
/// user settings, or listen to user settings changes.
///
/// Controllers glue Data Services to Flutter Widgets. The SettingsController
/// uses the SettingsService to store and retrieve user settings.
class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService);

  // Make SettingsService a private variable so it is not used directly.
  final SettingsService _settingsService;

  // Make ThemeMode a private variable so it is not updated directly without
  // also persisting the changes with the SettingsService.
  late ThemeMode _themeMode;

  // Allow Widgets to read the user's preferred ThemeMode.
  ThemeMode get themeMode => _themeMode;
  
  static const String kPortNameOverlay = 'OVERLAY';
  static const String kPortNameHome = 'UI';
  final receivePort = ReceivePort();

  SendPort? homePort;
  bool isPermissionGranted = false;

  /// Load the user's settings from the SettingsService. It may load from a
  /// local database or the internet. The controller only knows it can load the
  /// settings from the service.
  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();

    WidgetsFlutterBinding.ensureInitialized();
    
    bg.BackgroundGeolocation.onLocation((location) async {
      // Send a message to the backend with location.latitude and location.longitude
      var response = await http.post(
        Uri.parse('http://localhost:3000/get-notification'),
        headers: <String, String> {
          'Content-type': 'text/plain'
        },
        body: "${location.coords.latitude}|${location.coords.longitude}"
      );

      int count = int.parse(response.body);

      // Send notification if needed
      if(count > 0 && homePort != null) {
        homePort!.send(count.toString());

        /// TODO: Send a toast notification
      }
    });

    bg.State state = await bg.BackgroundGeolocation.ready(bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10.0,
        stopOnTerminate: false,
        startOnBoot: true,
        debug: true,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE
    ));

    if (!state.enabled) {
      ////
      // 3.  Start the plugin.
      //
      bg.BackgroundGeolocation.start();
    }
    
    // Important! Inform listeners a change has occurred.
    notifyListeners();
  }

  /// Update and persist the ThemeMode based on the user's selection.
  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;

    // Do not perform any work if new and old ThemeMode are identical
    if (newThemeMode == _themeMode) return;

    // Otherwise, store the new ThemeMode in memory
    _themeMode = newThemeMode;

    // Important! Inform listeners a change has occurred.
    notifyListeners();

    // Persist the changes to a local database or the internet using the
    // SettingService.
    await _settingsService.updateThemeMode(newThemeMode);
  }

  void callbackDispatcher() {
    const MethodChannel backgroundChannel = MethodChannel('');

    WidgetsFlutterBinding.ensureInitialized();

    backgroundChannel.setMethodCallHandler((MethodCall call) async {

      final Function? callback = PluginUtilities.getCallbackFromHandle(CallbackHandle.fromRawHandle(call.arguments[0]));

      callback!(call.arguments[1].cast<String>());
    });

    // TODO: Add call to let the system know it's running
  }
}
