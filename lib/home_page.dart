import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true,
      allowsBackForwardNavigationGestures: true,
      sharedCookiesEnabled: true,
      useOnDownloadStart: true);

  PullToRefreshController? pullToRefreshController;
  String url = "";
  String cookiesString = '';
  double progress = 0;
  String? token;
  final urlController = TextEditingController();
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final dio = Dio();

  @override
  void initState() {
    super.initState();
    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: const Color.fromARGB(255, 58, 66, 183),
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final canGoback = await webViewController?.canGoBack() ?? false;
        if (canGoback) {
          webViewController?.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: getListUrl(url)
            ? null
            : Platform.isIOS
                ? buildAppBar(context)
                : null,
        body: buildBody(context),
      ),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final canGoback = await webViewController?.canGoBack() ?? false;
            if (canGoback) {
              webViewController?.goBack();
            }
          }),
    );
  }

  Widget buildBody(BuildContext context) {
    return SafeArea(
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                    keepAlive: InAppWebViewKeepAlive(),
                    key: webViewKey,
                    initialUrlRequest:
                        URLRequest(url: WebUri("https://bsi.ciapps.id/")),
                    initialSettings: settings,
                    pullToRefreshController: pullToRefreshController,
                    onLoadStart: (controller, url) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onPermissionRequest: (controller, request) async {
                      return PermissionResponse(
                          resources: request.resources,
                          action: PermissionResponseAction.GRANT);
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url!;

                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about"
                      ].contains(uri.scheme)) {
                        if (await canLaunchUrl(uri)) {
                          // Launch the App
                          await launchUrl(
                            uri,
                          );
                          // and cancel the request
                          return NavigationActionPolicy.CANCEL;
                        }
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController?.endRefreshing();
                      cookiesString = '';
                      List<Cookie> cookies =
                          await CookieManager().getCookies(url: url!);
                      for (Cookie cookie in cookies) {
                        cookiesString += '${cookie.name}=${cookie.value};';
                      }
                      print('ini cookie nya ya: ${cookiesString}');
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                        this.cookiesString = cookiesString;
                        token = url.queryParameters["token"];
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      pullToRefreshController?.endRefreshing();
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController?.endRefreshing();
                      }
                      setState(() {
                        this.progress = progress / 100;
                        urlController.text = url;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      if (kDebugMode) {
                        print(consoleMessage);
                      }
                    },
                    onDownloadStartRequest:
                        (controller, downloadStartRequest) async {
                      var permissionStatus;

                      if ((Platform.isAndroid)) {
                        if (await isBelowAndroid32(deviceInfo)) {
                          permissionStatus = await Permission.storage.request();
                        } else {
                          permissionStatus = await Permission.photos.request();
                        }
                      } else {
                        permissionStatus = await Permission.storage.request();
                      }

                      if (permissionStatus == PermissionStatus.granted) {
                        final directory = (Platform.isAndroid)
                            ? await getExternalStorageDirectory()
                            : await getApplicationDocumentsDirectory();

                        List<String>? partsMime =
                            downloadStartRequest.mimeType?.split('/');
                        final extensionType = partsMime?[1];
                        String filename =
                            '${DateTime.now().millisecondsSinceEpoch}.$extensionType';
                        List<String>? partsUrl =
                            downloadStartRequest.url.toString().split(',');

                        final suggestFileName =
                            downloadStartRequest.suggestedFilename;

                        final urlFinal = downloadStartRequest.url.toString() +
                            '/' +
                            (suggestFileName ?? filename);

                        if (partsUrl.length > 1) {
                          final base64Data = partsUrl[1];
                          _createFileFromBase64(
                              base64content: base64Data,
                              fileName: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              yourExtension: extensionType ?? '',
                              directory: directory);
                        } else {
                          try {
                            await FlutterDownloader.enqueue(
                              fileName: filename,
                              url: urlFinal,
                              savedDir: directory?.path ?? '',
                              saveInPublicStorage: true,
                              showNotification: true,
                              openFileFromNotification: true,
                              headers: {
                                "connection": "keep-alive",
                                "cookie": cookiesString,
                              },
                            );
                            // await dio.download(
                            //   urlFinal,
                            //   (Headers headers){
                            //     // Extra info: redirect counts
                            //     print(headers.value('redirects'));
                            //     ///        // Extra info: real uri
                            //            print(headers.value('uri'));
                            //     return '${directory?.path}/${suggestFileName ?? filename}';
                            //   },
                            //   options: Options(
                            //     // responseType: ResponseType.bytes,
                            //     // followRedirects: true,
                            //     // validateStatus: (status) {
                            //     //   return status! < 500;
                            //     // },
                            //     headers: {
                            //       // "authorization": "Basic $token",
                            //       "connection": "keep-alive",
                            //       "cookie": cookiesString,
                            //     },
                            //   ),
                            //   onReceiveProgress: (recivedBytes, totalBytes) {
                            //     // final progressString =
                            //     //     ((recivedBytes / totalBytes) * 100);
                            //     // setState(() {
                            //     //   this.progress = progressString;
                            //     // });

                            //     // if (_progressString == "100%") {
                            //     //   Scaffold.of(context).showSnackBar(SnackBar(
                            //     //       content: Text("Next Action...")));
                            //     //   // NextAction();
                            //     // }
                            //   },
                            //   deleteOnError: true,
                            // );
                          } catch (e) {
                            final base64Data = partsUrl[1];
                            _createFileFromBase64(
                                base64content: base64Data,
                                fileName: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                yourExtension: extensionType ?? '',
                                directory: directory);
                          }
                        }
                        if (kDebugMode) {
                          print('onDownloadStart ${downloadStartRequest.url}');
                        }
                      }
                    }),
                progress < 1.0
                    ? LinearProgressIndicator(
                        value: progress,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      )
                    : SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool getListUrl(String url) {
    final listUrl = [
      "https://bsi.ciapps.id/",
      "https://bsi.ciapps.id/page/dashboard",
    ];
    return listUrl.contains(url);
  }

  static Future<bool> isBelowAndroid32(DeviceInfoPlugin deviceInfo) async {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt < 32;
  }

  void _createFileFromBase64(
      {required String base64content,
      required String fileName,
      required String yourExtension,
      Directory? directory}) async {
    var bytes = base64Decode(base64content.replaceAll('\n', ''));
    final file = File("${directory?.path}/$fileName.$yourExtension");
    await file.writeAsBytes(bytes.buffer.asUint8List());

    final params = SaveFileDialogParams(
      data: file.readAsBytesSync(),
      fileName: '$fileName.$yourExtension',
    );
    final filePath = await FlutterFileDialog.saveFile(params: params);

    if (filePath != null) {
      print(filePath);
      await OpenFile.open("${directory?.path}/$fileName.$yourExtension");
    }
    setState(() {});
  }
}
