import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class ContentViewerState extends State<ContentViewer> {
  static const int CHUNK_SIZE = 5;  //  our current chunk size is gonna be 5 for how much content to render at once

  List<MediaObject> mediaObjects = <MediaObject>[];
  List<MediaObject> mediaToRender = <MediaObject>[];
  int currentIndex;

  //  fetches data from reddit, then parses it
  Future<Null> _fetchLinks() async {
    final res = await http.get('https://www.reddit.com/r/aww.json');
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body)['data']['children'];
      mediaObjects = data.map<MediaObject>((json) => MediaObject.fromJson(json)).toList();
      mediaObjects = mediaObjects.where((obj) => obj != null).toList();
      
      _generateMediaToRender(); //  TODO: should move this eventually
    } else {
      throw Exception('Failed to fetch data from reddit!');
    }
    return null;
  }

  //  build individual content "pages"
  Widget _buildSingleContent(MediaObject mediaObj) {
    Widget content;
    if (mediaObj == null) {
      content = new Text('Loading!');
    }
    else if (mediaObj.type == ContentType.IMAGE) {
      content = Image.network(mediaObj.url);
    } else if (mediaObj.type == ContentType.GFY || mediaObj.type == ContentType.GIFV || mediaObj.type == ContentType.VIDEO) {
      content = _buildFullScreenVideo(mediaToRender[currentIndex % CHUNK_SIZE]);
    } else {
      content = new Text('Loading!');
    }   
    return new ListTile(
      title: content
    );
  }

  //  build a single video
  Widget _buildFullScreenVideo(MediaObject mediaObj) {
    return Scaffold(
      body: Center(
        child: Center(
          child: Hero(
            tag: VideoPlayerController,
            child: VideoPlayer(VideoPlayerController.network(mediaObj.url))
          )
        )
      )
    );
  }
  
  //  create a list of content of size CHUNK_SIZE
  Widget _renderCurrentContent() {
    return new ListView.builder(
      padding: const EdgeInsets.all(2.0),
      itemBuilder: (BuildContext _context, int i) {
        if (i.isOdd) {
          return new Divider();
        }
        currentIndex++; // TODO: fix: so hacky
        return _buildSingleContent(mediaToRender[(currentIndex - 1) % CHUNK_SIZE]);
      }
    );
  }

  //  set up the list of things to render next
  void _generateMediaToRender() {
    int i = 0;
    for (int j = currentIndex; j < currentIndex + 5 && j < mediaObjects.length; j++) {
      mediaToRender[i] = mediaObjects[i];
    }
  }

  //  go to next piece of content and handle if you need to go to the next chunk
  void _goToNext() {
    currentIndex++;

    if (currentIndex % CHUNK_SIZE == 0) {
      _generateMediaToRender();
    }
  }

  @override
  void initState() {
    super.initState();
    currentIndex = 0;
    mediaToRender = new List(CHUNK_SIZE);
    _fetchLinks();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Welcome to PipPup!'),
        actions: <Widget>[
          new IconButton(icon: const Icon(Icons.list), onPressed: _goToNext),
        ],
      ),
      body: _renderCurrentContent(),
    );
  }
}

class ContentViewer extends StatefulWidget {
  @override
  ContentViewerState createState() => new ContentViewerState();
}

class MediaObject {
  final String url;
  final ContentSource source;
  final ContentType type;

  MediaObject({this.url, this.source, this.type});

  //  need to handle link parsing/checking etc.
  factory MediaObject.fromJson(Map<String, dynamic> json) {
    String url = json['data']['url'];
    ContentSource source = _parseForSource(url);
    ContentType type = _parseForType(json, url, source);
    if (source == ContentSource.OTHER) {
      return null;
    }
    if (type != ContentType.IMAGE) {
      url = _parseSpecialType(json, url, type);
    }

    return MediaObject(
      url: url,
      source: source,
      type: type
    );
  }

  static ContentSource _parseForSource(String url) {
    if (url.contains('gfycat')) {
      return ContentSource.GFYCAT;
    }
    if (url.contains('imgur')) {
      return ContentSource.IMGUR;
    }
    if (url.contains('redd.it')) {
      return ContentSource.REDDIT;
    }
    return ContentSource.OTHER;
  }

  static ContentType _parseForType(Map<String, dynamic> json, String url, ContentSource source) {
    if (source == ContentSource.GFYCAT) {
      return ContentType.GFY;
    }
    if (json['data']['is_video']) {
      return ContentType.VIDEO;
    }
    if (url.contains('gifv')) {
      return ContentType.GIFV;
    }
    return ContentType.IMAGE; //  this should be more thorough if we do it on the backend
  }

  static String _parseSpecialType(Map<String, dynamic> json, String url, ContentType type) {
    if (type == ContentType.GFY) {
      return url.substring(0, 8) + 'giant' + url.substring(14, url.length - 20) + '.mp4';
    }
    if (type == ContentType.GIFV) {
      return url.substring(0, url.length - 4) + 'mp4';
    }    
    if (type == ContentType.VIDEO) {
      return json['data']['media']['reddit_video']['fallback_url'];
    }
    return null;
  }
}

enum ContentSource {
  GFYCAT, IMGUR, REDDIT, OTHER
}

enum ContentType {
  GFY, GIFV, IMAGE, VIDEO  //  gifs are considered images
}