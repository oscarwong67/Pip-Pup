import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class ContentViewerState extends State<ContentViewer> {
  List<MediaObject> mediaObjects = <MediaObject>[];

  Future<Null> _fetchLinks() async {
    final res = await http.get('https://www.reddit.com/r/aww.json');
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body)['data']['children'];
      this.mediaObjects = data.map<MediaObject>((json) => MediaObject.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch data from reddit!');
    }
    return null;
  }

  void _renderCurrentContent() {
    //
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Welcome to PipPup!'),
        actions: <Widget>[
          new IconButton(icon: const Icon(Icons.list), onPressed: _fetchLinks),
        ],
      ),
      //body: _renderCurrentContent(),
    );
  }
}

class ContentViewer extends StatefulWidget {
  @override
  ContentViewerState createState() => new ContentViewerState();
}

class MediaObject {
  final String url;
  final String redditVideoUrl;

  MediaObject({this.url, this.redditVideoUrl});

  //  need to handle link parsing/checking etc.
  factory MediaObject.fromJson(Map<String, dynamic> json) {
    return MediaObject(
      url: json['data']['url'],
      redditVideoUrl: json['data']['media'] != null ? json['data']['media']['reddit_video']['fallback_url'] : null,
    );
  }
}