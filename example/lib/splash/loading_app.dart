import 'package:flutter/material.dart';

import 'loading.dart';

class LoadingApp extends StatelessWidget {
  const LoadingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "FabricElements",
      home: LoadingScreen(),
    );
  }
}
