import 'package:flutter/material.dart';

import './Components/ContentViewer.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'PipPup',
        home: new ContentViewer()
    );
  }
}