import 'package:flutter/material.dart';

import 'loading.dart';

class LoadingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PADS',
      home: LoadingScreen(),
    );
  }
}
