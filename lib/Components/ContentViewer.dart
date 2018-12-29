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
  VideoPlayerController previousVideoController;
  VideoPlayerController currentVideoController;
  VideoPlayerController nextVideoController;
  VideoPlayerController previousAudioController;
  VideoPlayerController currentAudioController;
  VideoPlayerController nextAudioController;
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
    List<Widget> newPages = new List(CHUNK_SIZE);
    //  swipe down
    if (pageId > this.currentPage) {
      this.currentIndex++;

      this.previousAudioController = this.currentAudioController;
      this.previousVideoController = this.currentVideoController;
      this.currentAudioController = this.nextAudioController;
      this.currentVideoController = this.nextVideoController;
      this.nextVideoController = null;
      this.nextAudioController = null;

      newPages[0] = this.pages.length >= 3
          ? this.pages[1]
          : this.pages[
              0]; //  if it's less than 3, that means '0' or "previous" didn't exist before
      newPages[1] = this.pages.length >= 3
          ? this.pages[2]
          : _renderCurrentContent(this.currentIndex, 1);
      newPages[2] = _renderCurrentContent(this.currentIndex + 1, 2);
    } else if (pageId < this.currentPage) {
      this.currentIndex--;

      this.nextAudioController = this.currentAudioController;
      this.nextVideoController = this.currentVideoController;
      this.currentAudioController = this.previousAudioController;
      this.currentVideoController = this.previousVideoController;
      this.previousVideoController = null;
      this.previousAudioController = null;
      newPages[0] = _renderCurrentContent(this.currentIndex - 1, 0);
      newPages[1] = this.pages.length >= 3
          ? this.pages[0]
          : _renderCurrentContent(this.currentIndex, 1);
      newPages[2] = this.pages[1];
    } else {
      newPages = this.pages;
    }

    newPages = newPages.where((child) => child != null).toList();

    setState(() {
      this.pages = newPages;
      this.currentPage = ((this.pages.length - 1) / 2).floor();
      pageController.animateToPage(this.currentPage, duration: const Duration(milliseconds: 300), curve: Curves.ease);
    });

    _pauseIfNeeded(previousVideoController);
    _pauseIfNeeded(previousAudioController);
    _pauseIfNeeded(nextVideoController);
    _pauseIfNeeded(nextAudioController);

    if (this.currentVideoController != null) {
      if (this.currentVideoController.value.initialized) {
        this.currentVideoController.play();
      } else {
        this.currentVideoController.initialize().then((_) {
          this.currentVideoController.play();
        });
      }
    }
  }

  // build a single video
  Widget _buildVideo(MediaObject mediaObj, int pageIndex) {
    VideoPlayerController videoController =
        new VideoPlayerController.network(mediaObj.url);
    VideoPlayerController audioController;
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

    if (pageIndex == 0) {
      this.previousVideoController = videoController;
      this.previousAudioController = audioController;
    } else if (pageIndex == 1) {
      this.currentVideoController = videoController;
      this.currentAudioController = audioController;
    } else if (pageIndex == 2) {
      this.nextVideoController = videoController;
      this.nextAudioController = audioController;
    }

    return new Stack(
      children: <Widget>[
        new Chewie(
          videoController,
          autoPlay: false,
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
  }

  //  create a list of content of size CHUNK_SIZE
  Widget _renderCurrentContent(int index, int pageIndex) {
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
        content = _buildVideo(mediaObjects[index], pageIndex);
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
      //  skip "previous" since you're at the beginning
      this.pages = <Widget>[
        _renderCurrentContent(this.currentIndex, 1),
        _renderCurrentContent(this.currentIndex + 1, 2),
      ].where((child) => child != null).toList();
      if (this.currentVideoController != null) {
        this.currentVideoController.play();
      }
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

  void _pauseIfNeeded(VideoPlayerController controller) {
    if (controller != null &&
        controller.value.initialized &&
        controller.value.isPlaying) controller.pause();
  }

  // @override
  // void dispose() {
  //   super.dispose();
  //   currentAudioController.dispose();
  //   currentVideoController.dispose();
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
        actions: <Widget>[
          new IconButton(
            icon: const Icon(Icons.list),
            onPressed: _debug,
          )
        ],
      ),
      body: _renderCurrentPage(),
    );
  }

  void _debug() {
    print('yo');
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
    ContentSource source = _parseForSource(json);
    ContentType type = _parseForType(json, url, source);
    int width = 0, height = 0;
    if (source == ContentSource.OTHER ||
        type == ContentType.OTHER ||
        json['data']['is_meta'] ||
        json['data']['is_self']) {
      return null;
    }

    if (type != ContentType.IMAGE) {
      url = _parseSpecialType(json, url, type, source);
      Map<String, int> dimensions = _parseDimensions(json, source);
      width = dimensions['width'];
      height = dimensions['height'];
    } else if (source == ContentSource.IMGUR) {
      url = _parseImgurImageURL(
          url); //  images, if submitted as links to imgur.com (not gallery posts, just single images), need to be parsed to actually get the image
    }

    String audioUrl = _parseForAudioURL(json, type, source);

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
    } else if (source == ContentSource.IMGUR) {
      // this is how we support GIFVs, by ripping reddit's preview which has height/width info
      sourceInfoMap = json['data']['preview']['reddit_video_preview'];
    } else {
      throw new Exception('Source specified is not Gfycat or Reddit Video.');
    }
    res.putIfAbsent('width', () => sourceInfoMap['width']);
    res.putIfAbsent('height', () => sourceInfoMap['height']);

    return res;
  }

  static String _parseSpecialType(Map<String, dynamic> json, String url,
      ContentType type, ContentSource source) {
    if (type == ContentType.GFY) {
      final String url = json['data']['media']['oembed']['thumbnail_url'];
      return 'https://giant' + url.substring(14, url.length - 20) + '.mp4';
    }
    if (type == ContentType.GIFV) {
      return json['data']['preview']['reddit_video_preview']['fallback_url'];
    }
    if (type == ContentType.VIDEO && source == ContentSource.REDDIT) {
      return json['data']['media']['reddit_video']['fallback_url'];
    }
    return null;
  }

  static ContentSource _parseForSource(Map<String, dynamic> json) {
    if (json['data']['domain'] == 'gfycat.com') {
      return ContentSource.GFYCAT;
    }
    if (json['data']['domain'] == 'i.imgur.com' ||
        json['data']['domain'] == 'imgur.com') {
      return ContentSource.IMGUR;
    }
    bool iREDDIT = json['data']['domain'] == 'i.redd.it';
    if (json['data']['domain'] == 'v.redd.it' || iREDDIT) {
      if (iREDDIT &&
          json['data']['url'].contains(
              '.gif')) // is there a fix? actual gifs load really slowly, so we're ditching them altogether.
        return ContentSource.OTHER;
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
    } else if (json['data']['domain'] == 'v.redd.it') {
      // if it's v.reddit but NOT a video, then it must be something fucked up
      return ContentType.OTHER;
    }
    if (url.contains('gifv')) {
      return ContentType.GIFV;
    } else if (url.contains('/gallery/') || url.contains('imgur.com/a/')) {
      //  not supporting imgur albums and such right now
      return ContentType.OTHER;
    }

    return ContentType
        .IMAGE; //  this should be more thorough if we do it on the backend
  }

  static String _parseForAudioURL(
      Map<String, dynamic> json, ContentType type, ContentSource source) {
    if (source == ContentSource.REDDIT &&
        type == ContentType.VIDEO &&
        !json['data']['media']['reddit_video']['is_gif']) {
      return json['data']['url'] + '/audio';
    } else if (source == ContentSource.IMGUR && type == ContentType.GIFV && !json['data']['preview']['reddit_video_preview']['is_gif']) {
      //  TODO: GIFV WITH SOUND NOT SUPPORTED ATM, IDK IF GETTING THE AUDIO URL VIA REDDIT VIDEO WILL EVEN WORK
      return "";
    }
    return "";
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
  VIDEO, //  gifs are considered images
  OTHER
}
