import 'package:fabric_flutter/state/state-document.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StateDocumentDemo extends StatefulWidget {
  StateDocumentDemo({Key? key, required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  _StateDocumentDemoState createState() => _StateDocumentDemoState();
}

class _StateDocumentDemoState extends State<StateDocumentDemo> {
  @override
  Widget build(BuildContext context) {
    StateDocument stateDocument = Provider.of<StateDocument>(context);
    if (stateDocument.id == null) {
      stateDocument.collection = "demo";
      stateDocument.id = "test";
    }
    String title = stateDocument.id != null
        ? "${stateDocument.data["id"]} --- ${stateDocument.data["name"]}"
        : "Not found";
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(16),
        child: Text(title),
      ),
    );
  }
}
