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
  ChewieController chewieVideoController;
  VideoPlayerController audioController;
  ChewieController chewieAudioController;
  int currentIndex;
  int currentPage;  //  used to help track the index in the list of mediaobjects

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

  //  render individual content page
  Widget _renderCurrentContent(int index) {
    if (index >= 0 &&
        index < mediaObjects.length &&
        mediaObjects[index] != null) {
      Widget content;
      MediaObject mediaObj = mediaObjects[index];

      if (mediaObj.type == ContentType.IMAGE) {
        content = _buildImage(mediaObj);
      } else if (mediaObj.type == ContentType.GFY ||
          mediaObj.type == ContentType.GIFV ||
          mediaObj.type == ContentType.VIDEO) {
        content = _buildVideo(mediaObj);
      } else {
        throw new Exception('Invalid Content Type! What the heck!');
      }
      return new Center(child: content);
    } else {
      return null;
    }
  }

  Widget _buildImage(MediaObject mediaObj) {
    return new TransitionToImage(
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
  }

    // build a single video
  Widget _buildVideo(MediaObject mediaObj) {
    //  error check - in case elements are being pre-built and saved rather than built on-demand.
    if (this.mediaObjects[this.currentIndex] == mediaObj) {
      _cleanup(); //  clean up possible old controllers and stuff
      _setupVideoControllers(mediaObj);
      _setupChewieControllers(mediaObj);

      return new Stack(
        children: <Widget>[
          new Chewie(
            controller: chewieVideoController,
          ),
          //  invisible video player to play audio for reddit videos
          (mediaObj.source == ContentSource.REDDIT &&
                  this.audioController != null)
              ? new Opacity(
                  opacity: 0.0,
                  child: new Chewie(
                    controller: chewieAudioController
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

  //  go to next piece of content and handle if you need to go to the next chunk
  void _movePage(int pageId) {
    //  swipe down
    if (pageId > this.currentPage) {
      this.currentIndex++;
    } else if (pageId < this.currentPage) {
      this.currentIndex--;
    }

    setState(() {
      this.currentPage = pageId;
      _pauseIfNeeded(this.audioController);
      _pauseIfNeeded(this.videoController);
      videoController.removeListener(_videoAudioListener);
    });
  }

  void _setupVideoControllers(MediaObject mediaObj) {
    this.videoController = new VideoPlayerController.network(mediaObj.url);
      if (mediaObj.audioUrl != null && mediaObj.audioUrl.length > 0) {
        this.audioController =
            new VideoPlayerController.network(mediaObj.audioUrl);
      }
      //  listen for when it's actually the current page
      this.videoController.addListener(_videoAudioListener);
  }

  void _setupChewieControllers(MediaObject mediaObj) {
    this.chewieVideoController = ChewieController(
        videoPlayerController: this.videoController,
          autoPlay: true,
          autoInitialize: true,
          looping: true,
          aspectRatio: mediaObj.width / mediaObj.height,
          showControls: false, //  TODO: write custom controls that also pause/play the audio at the same time.
          placeholder: Center(
            child:
              CircularProgressIndicator()
          )
      );

      if (mediaObj.source == ContentSource.REDDIT && this.audioController != null) {
        this.chewieAudioController = ChewieController(
          videoPlayerController: this.audioController,
          autoPlay: false,
          autoInitialize: true,
          looping: true,
          showControls: false,
        );
      }
  }

  void _videoAudioListener() {
    if (this.videoController.value.isPlaying && this.audioController != null) {
      this.audioController.play();
    }
    if (!this.videoController.value.isPlaying &&
        this.audioController != null &&
        this.audioController.value.isPlaying) {
      this.audioController.pause(); //  just in case audio doesn't pause off of _pauseIfNeeded()
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

  void _cleanup() {
    if (this.videoController != null) {
      this.videoController.dispose();
    }
    if (this.audioController != null) {
      this.audioController.dispose();
    }
    if (this.chewieVideoController != null) {
      this.chewieVideoController.dispose();
    }
    if (this.chewieAudioController != null) {
      this.chewieAudioController.dispose();
    }
    this.videoController = null;
    this.audioController = null;
    this.chewieVideoController = null;
    this.chewieAudioController = null;
  }

  void _pauseIfNeeded(VideoPlayerController controller) {
    if (controller != null &&
        controller.value.initialized &&
        controller.value.isPlaying) {
      controller.pause();      
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
  void dispose() {
    super.dispose();
    _cleanup();
  }

  void _debug() {
    print('yo');
  }
}

class ContentViewer extends StatefulWidget {
  @override
  ContentViewerState createState() => new ContentViewerState();
}
