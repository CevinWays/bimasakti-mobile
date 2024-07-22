
import 'package:bimasakti/splash_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  await Permission.microphone.request();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  // Plugin must be initialized before using
  await FlutterDownloader.initialize(
      debug:
          kDebugMode, // optional: set to false to disable printing logs to console (default: true)
      ignoreSsl:
          true // option: set to false to disable working with http links (default: false)
      );

  runApp(
    GetMaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 58, 66, 183)),
        useMaterial3: true,
      ),
      home: const SplashPage(),
      debugShowCheckedModeBanner: kDebugMode ? true : false,
    ),
  );
}
