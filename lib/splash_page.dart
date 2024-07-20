import 'dart:async';

import 'package:bimasakti/home_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    Timer(const Duration(milliseconds: 1500), () {
      Get.off(HomePage());
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          child: Center(
            child: Image.asset(
              'assets/images/img_bsi_black.png',
              width: 250,
            ),
          ),
        ));
  }
}
