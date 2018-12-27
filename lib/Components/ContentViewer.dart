import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_advanced_networkimage/flutter_advanced_networkimage.dart';
import 'package:flutter_advanced_networkimage/transition_to_image.dart';

class ContentViewerState extends State<ContentViewer> {
  static const int CHUNK_SIZE =
      3; //  our current chunk size is gonna be 3 for how much content to render at once

  List<MediaObject> mediaObjects = <MediaObject>[];
  List<Widget> pages = <Widget>[];
  final PageController pageController = new PageController();
  VideoPlayerController videoController;
  VideoPlayerController audioController;
  int currentIndex;
  int currentPage;

  //  fetches data from reddit, then parses it
  Future<Null> _fetchLinks() async {
    final res = await http.get('https://www.reddit.com/r/aww.json');
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body)['data']['children'];
      mediaObjects =
          data.map<MediaObject>((json) => MediaObject.fromJson(json)).toList();
      setState(() {
        mediaObjects = mediaObjects.where((obj) => obj != null).toList();
      });
    } else {
      throw Exception('Failed to fetch data from reddit!');
    }
    return null;
  }

  //  go to next piece of content and handle if you need to go to the next chunk
  void _movePage(int pageId) {
    if (pageId > this.currentPage) {
      //  swipe down
      this.currentIndex++;
    } else if (pageId < this.currentPage) {
      this.currentIndex--;
    }
    List<Widget> newPages = new List(CHUNK_SIZE);
    newPages[0] = _renderCurrentContent(this.currentIndex - 1);
    newPages[1] = _renderCurrentContent(this.currentIndex);
    newPages[2] = _renderCurrentContent(this.currentIndex + 1);
    setState(() {
      this.pages = newPages.where((child) => child != null).toList();
    });
    this.currentPage = ((this.pages.length - 1) / 2).floor();
    pageController.jumpToPage(this.currentPage);

    if (videoController != null && videoController.value.isPlaying)
      videoController.pause();
    if (audioController != null && audioController.value.isPlaying)
      audioController.pause();

    print(this.currentIndex);
  }

  // build a single video
  Widget _buildVideo(MediaObject mediaObj) {
    if (this.mediaObjects[this.currentIndex].url == mediaObj.url) {
      setState(() {
        videoController = new VideoPlayerController.network(mediaObj.url);
      });
      //  Reddit videos have audio hosted seperately, so we need to play both at once
      if (mediaObj.source == ContentSource.REDDIT)
        audioController = new VideoPlayerController.network(mediaObj.audioUrl);
      //  listen for when it's actually the current page
      videoController.addListener(() {
        if (videoController.value.isPlaying && mediaObj.audioUrl.length > 0) {
          if (!audioController.value.initialized) {
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
            autoInitialize: true,
            looping: true,
            aspectRatio: mediaObj.width / mediaObj.height,
            showControls: false,
            placeholder: Center(
                child:
                    CircularProgressIndicator()), //  TODO: write custom controls that also pause/play the audio at the same time.
          ),
          //  invisible video player to play audio for reddit videos
          (mediaObj.source == ContentSource.REDDIT)
              ? new Opacity(
                  opacity: 0.0,
                  child: new Chewie(
                    audioController,
                    autoPlay: false,
                    looping: true,
                    showControls: false,
                  ),
                )
              : null,
          //  if the current source isn't reddit, then playing audio seperately isn't a problem, but "null" isn't a valid child widget value so filter it
        ].where((child) => child != null).toList(), //  remove null children
      );
    } else {
      return new Center(child: CircularProgressIndicator());  //TODO: for videos, generate thumbnail url as "placeholder" OR implement a solution so you can have up to 3 PRE-INITIALIZED video controllers at a time
    }
  }

  //  create a list of content of size CHUNK_SIZE
  Widget _renderCurrentContent(int index) {
    if (index >= 0 &&
        index < mediaObjects.length &&
        mediaObjects[index] != null) {
      Widget content;
      MediaObject mediaObj = mediaObjects[index];

      if (mediaObj.type == ContentType.IMAGE) {
        content = TransitionToImage(
            AdvancedNetworkImage(mediaObj.url, useDiskCache: false),
            placeholder: new CircularProgressIndicator());
      } else if (mediaObj.type == ContentType.GFY ||
          mediaObj.type == ContentType.GIFV ||
          mediaObj.type == ContentType.VIDEO) {
        content = _buildVideo(mediaObjects[index]);
      } else {
        throw new Exception('Invalid Content Type! What the heck!');
      }
      return new Center(child: content);
    } else {
      return null;
    }
  }

  Widget _renderCurrentPage() {
    if (this.pages.isEmpty) {
      this.pages = <Widget>[
        _renderCurrentContent(this.currentIndex - 1),
        _renderCurrentContent(this.currentIndex),
        _renderCurrentContent(this.currentIndex + 1)
      ].where((child) => child != null).toList();
    }
    return new PageView(
      children: this.pages,
      controller: pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (pageId) {
        _movePage(pageId);
      },
    );
  }

  // @override
  // void dispose() {
  //   super.dispose();
  //   audioController.dispose();
  //   videoController.dispose();
  // }

  @override
  void initState() {
    super.initState();
    this.currentIndex = 0;
    this.currentPage = 0;
    _fetchLinks();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Welcome to PipPup!'),
      ),
      body: _renderCurrentPage(),
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
    //  TODO: ADD PROPER GIFV SUPPORT, maybe by figuring out to how to handle videoController.value.size
    //       - NOTE: THIS IS THE ONLY PLACE I HAVE HERE THAT ACTUALLY FILTERS GIFV OUT, ALL OTHER GIFV CODE IS INTACT, but only some of the code needed to make it work exists rn
    if (source == ContentSource.OTHER || type == ContentType.GIFV) {
      return null;
    }

    if (type != ContentType.IMAGE) {
      url = _parseSpecialType(json, url, type);
      Map<String, int> dimensions = _parseDimensions(json, source);
      width = dimensions['width'];
      height = dimensions['height'];
    } else if (source == ContentSource.IMGUR) {
      url = _parseImgurImageURL(url);
    }
    String audioUrl = "";
    if (source == ContentSource.REDDIT &&
        type == ContentType.VIDEO &&
        !json['data']['media']['reddit_video']['is_gif']) {
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
      return 'https://giant' + url.substring(14, url.length - 20) + '.mp4';
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

  static String _parseImgurImageURL(String url) {
    if (url.contains('i.imgur')) {
      return url;
    }
    return 'https://i.' + url.substring(8, url.length) + '.jpg';
  }
}

enum ContentSource { GFYCAT, IMGUR, REDDIT, OTHER }

enum ContentType {
  GFY,
  GIFV,
  IMAGE,
  VIDEO //  gifs are considered images
}
