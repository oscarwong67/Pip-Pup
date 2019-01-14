import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_advanced_networkimage/flutter_advanced_networkimage.dart';
import 'package:flutter_advanced_networkimage/transition_to_image.dart';

import '../Classes/MediaObject.dart';

class ContentViewerState extends State<ContentViewer> {
  List<MediaObject> mediaObjects = <MediaObject>[];
  final PageController pageController = new PageController();
  VideoPlayerController videoController;
  VideoPlayerController audioController;
  int currentIndex;
  int currentPage;

  //  go to next piece of content and handle if you need to go to the next chunk
  void _movePage(int pageId) {
    //  swipe down
    if (pageId > this.currentPage) {
      this.currentIndex++;
    } else if (pageId < this.currentPage) {
      this.currentIndex--;
    } else {
      return; //  this case is because _movePage is called by the "animateToPage" call below
    }

    setState(() {
      this.currentPage = pageId;
      //this.pageController.animateToPage(this.currentPage, duration: const Duration(milliseconds: 700), curve: Curves.ease);
      _pauseIfNeeded(this.audioController);
      _pauseIfNeeded(this.videoController);
    });
  }

  // build a single video
  Widget _buildVideo(MediaObject mediaObj) {
    if (this.mediaObjects[this.currentIndex] == mediaObj) {
      this.videoController = new VideoPlayerController.network(mediaObj.url);
      if (mediaObj.audioUrl != null && mediaObj.audioUrl.length > 0) {
        this.audioController =
            new VideoPlayerController.network(mediaObj.audioUrl);
      }
      //  listen for when it's actually the current page
      this.videoController.addListener(_videoAudioListener);
      return new Stack(
        children: <Widget>[
          new Chewie(
            this.videoController,
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
          (mediaObj.source == ContentSource.REDDIT &&
                  this.audioController != null)
              ? new Opacity(
                  opacity: 0.0,
                  child: new Chewie(
                    this.audioController,
                    autoPlay: false,
                    autoInitialize: true,
                    looping: true,
                    showControls: false,
                  ),
                )
              : null,
          //  if the current source isn't reddit, then playing audio seperately isn't a problem, but "null" isn't a valid child widget value so filter it
        ].where((child) => child != null).toList(), //  remove null children
      );
    } else {
      return new CircularProgressIndicator(); //  TODO: put image placeholder or something
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
          AdvancedNetworkImage(
            mediaObj.url,
            useDiskCache: false,
            retryDuration: const Duration(milliseconds: 500),
            retryLimit: 4,
          ),
          placeholder: const Icon(Icons.refresh),
          loadingWidget:
              const CircularProgressIndicator(), //  TODO: use the preview image link here?
        );
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
    return new PageView.builder(
        controller: pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (pageId) {
          _movePage(pageId);
        },
        itemBuilder: (BuildContext context, int index) {
          return _renderCurrentContent(index);
        },
        itemCount: this.mediaObjects.length);
  }

  void _videoAudioListener() {
    if (this.videoController.value.isPlaying && this.audioController != null) {
      this.audioController.play();
    }
    if (!this.videoController.value.isPlaying &&
        this.audioController != null &&
        this.audioController.value.isPlaying) {
      this.audioController.pause(); //  just in case audio doesn't pause
    }
  }

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

  void _pauseIfNeeded(VideoPlayerController controller) {
    if (controller != null &&
        controller.value.initialized &&
        controller.value.isPlaying) {
      controller.pause();
      controller.removeListener(_videoAudioListener);
      controller.dispose();
    }
  }

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
