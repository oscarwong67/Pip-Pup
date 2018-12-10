import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ContentViewerState extends State<ContentViewer> {
  static const int CHUNK_SIZE =
      5; //  our current chunk size is gonna be 5 for how much content to render at once

  List<MediaObject> mediaObjects = <MediaObject>[];
  List<MediaObject> mediaToRender = <MediaObject>[];  
  VideoPlayerController videoController;
  VideoPlayerController audioController;
  int currentIndex;

  //  fetches data from reddit, then parses it
  Future<Null> _fetchLinks() async {
    final res = await http.get('https://www.reddit.com/r/aww.json');
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body)['data']['children'];
      mediaObjects =
          data.map<MediaObject>((json) => MediaObject.fromJson(json)).toList();
      mediaObjects = mediaObjects.where((obj) => obj != null).toList();

      _generateMediaToRender(); //  TODO: should move this eventually, probably shouldn't be handled here.
    } else {
      throw Exception('Failed to fetch data from reddit!');
    }
    return null;
  }

  // build a single video
  Widget _buildVideo(MediaObject mediaObj) {
    videoController =
        new VideoPlayerController.network(mediaObj.url);
    if (mediaObj.source == ContentSource.REDDIT)
      audioController =
        new VideoPlayerController.network(mediaObj.audioUrl);
    videoController.setVolume(1.0);
    videoController.addListener(() {
      if (videoController.value.isPlaying && mediaObj.audioUrl.length > 0) {
        if (! audioController.value.initialized) {
          audioController.initialize().then((_) {
            audioController.play();
          });
        } else {
          audioController.play();
        }
      }
    });
    return new Stack(
      children: <Widget>[
        new Chewie(
          videoController,
          autoPlay: true,
          looping: true,
          aspectRatio: mediaObj.width / mediaObj.height,
          showControls: false,  //  TODO: write custom controls that also pause/play the audio at the same time.
        ),
        (mediaObj.source == ContentSource.REDDIT) ? new Opacity(
          opacity: 0.0,
          child: new Chewie(
            audioController,
            autoPlay: false,
            looping: true,
            showControls: false,
          ),
        ) : null,
      ],
    );
  }

  //  create a list of content of size CHUNK_SIZE
  Widget _renderCurrentContent() {
    if (mediaToRender[currentIndex % CHUNK_SIZE] != null) {
      Widget content;
      MediaObject mediaObj = mediaToRender[currentIndex % CHUNK_SIZE];

      if (mediaObj.type == ContentType.IMAGE) {
        content = Image.network(mediaObj.url);
      } else if (mediaObj.type == ContentType.GFY ||
          mediaObj.type == ContentType.GIFV ||
          mediaObj.type == ContentType.VIDEO) {
        content = _buildVideo(mediaToRender[currentIndex % CHUNK_SIZE]);
      } else {
        throw new Exception('Invalid Content Type! What the heck!');
      }
      return new Center(child: content);
    } else {
      return new Center(child: new CircularProgressIndicator());
    }
  }

  //  set up the list of things to render next
  void _generateMediaToRender() {
    int i = 0;
    List<MediaObject> mediaToRender = new List(CHUNK_SIZE);
    for (int j = currentIndex;
        j < currentIndex + 5 && j < mediaObjects.length;
        j++) {
      mediaToRender[i] = mediaObjects[j];
      i++;
    }
    setState(() {
      this.mediaToRender = mediaToRender;
    });
  }

  //  go to next piece of content and handle if you need to go to the next chunk
  void _goToNext() {
    setState(() {
      this.currentIndex++;
    });
    if (audioController.value.isPlaying)
      audioController.pause();
    if (videoController.value.isPlaying)
      videoController.pause();   

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
  final String audioUrl;
  final ContentSource source;
  final ContentType type;
  final int width;
  final int height;

  MediaObject(
      {this.url,
      this.audioUrl,
      this.source,
      this.type,
      this.width,
      this.height});

  //  need to handle link parsing/checking etc.
  factory MediaObject.fromJson(Map<String, dynamic> json) {
    String url = json['data']['url'];
    ContentSource source = _parseForSource(url);
    ContentType type = _parseForType(json, url, source);
    int width = 0, height = 0;
    //  reddit api doesn't give aspect ratio of GIFVs, and that won't get us a good aspect ratio so I've decided to leave it out for now
    //  TODO: ADD PROPER GIFV SUPPORT - NOTE: THIS IS THE ONLY PLACE I HAVE HERE THAT ACTUALLY FILTERS IT OUT, ALL OTHER GIFV CODE IS INTACT
    if (source == ContentSource.OTHER || type == ContentType.GIFV) {
      return null;
    }
    if (type != ContentType.IMAGE) {
      url = _parseSpecialType(json, url, type);
      Map<String, int> dimensions = _parseDimensions(json, source);
      width = dimensions['width'];
      height = dimensions['height'];
    }
    String audioUrl = "";
    if (source == ContentSource.REDDIT && type == ContentType.VIDEO && ! json['data']['media']['reddit_video']['is_gif']) {
      audioUrl = json['data']['url'] + '/audio';
    }
    return MediaObject(
        url: url,
        audioUrl: audioUrl,
        source: source,
        type: type,
        width: width,
        height: height);
  }

  static Map<String, int> _parseDimensions(
      Map<String, dynamic> json, ContentSource source) {
    Map<String, dynamic> media = json['data']['media'];
    Map<String, int> res = new Map();
    Map<String, dynamic> sourceInfoMap;
    if (source == ContentSource.GFYCAT) {
      sourceInfoMap = media['oembed'];
    } else if (source == ContentSource.REDDIT) {
      sourceInfoMap = media['reddit_video'];
    } else {
      throw new Exception('Source specified is not Gfycat or Reddit Video.');
    }
    res.putIfAbsent('width', () => sourceInfoMap['width']);
    res.putIfAbsent('height', () => sourceInfoMap['height']);

    return res;
  }

  static String _parseSpecialType(
      Map<String, dynamic> json, String url, ContentType type) {
    if (type == ContentType.GFY) {
      final String url = json['data']['media']['oembed']['thumbnail_url'];
      return url.substring(0, 8) +
          'giant' +
          url.substring(14, url.length - 20) +
          '.mp4';
    }
    if (type == ContentType.GIFV) {
      return url.substring(0, url.length - 4) + 'mp4';
    }
    if (type == ContentType.VIDEO) {
      return json['data']['media']['reddit_video']['fallback_url'];
    }
    return null;
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

  static ContentType _parseForType(
      Map<String, dynamic> json, String url, ContentSource source) {
    if (source == ContentSource.GFYCAT) {
      return ContentType.GFY;
    }
    if (json['data']['is_video']) {
      return ContentType.VIDEO;
    }
    if (url.contains('gifv')) {
      return ContentType.GIFV;
    }
    return ContentType
        .IMAGE; //  this should be more thorough if we do it on the backend
  }
}

enum ContentSource { GFYCAT, IMGUR, REDDIT, OTHER }

enum ContentType {
  GFY,
  GIFV,
  IMAGE,
  VIDEO //  gifs are considered images
}
