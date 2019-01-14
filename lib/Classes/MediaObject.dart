class MediaObject {
  final String url;
  final String audioUrl;
  final String videoThumbUrl;
  final ContentSource source;
  final ContentType type;
  final int width;
  final int height;

  MediaObject(
      {this.url,
      this.audioUrl,
      this.videoThumbUrl,
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
    String audioUrl;
    String videoThumbUrl;
    if (source == ContentSource.OTHER ||
        type == ContentType.OTHER ||
        json['data']['is_meta'] ||
        json['data']['is_self']) {
      return null;
    }

    if (type != ContentType.IMAGE) {
      List<String> urlAndPreview = _parseSpecialTypeUrl(json, url, type, source);
      url = urlAndPreview[0];
      videoThumbUrl = urlAndPreview[1];
      Map<String, int> dimensions = _parseDimensions(json, source);
      width = dimensions['width'];
      height = dimensions['height'];      
    } else if (source == ContentSource.IMGUR) {
      url = _parseImgurImageUrl(
          url); //  images, if submitted as links to imgur.com (not gallery posts, just single images), need to be parsed to actually get the image
    }

    audioUrl = _parseForAudioUrl(json, type, source);

    return MediaObject(
        url: url,
        audioUrl: audioUrl,
        videoThumbUrl: videoThumbUrl,
        source: source,
        type: type,
        width: width,
        height: height,);
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

  static List<String> _parseSpecialTypeUrl(Map<String, dynamic> json, String url,
      ContentType type, ContentSource source) {
    List<String> urlAndPreview = new List(2);
    if (type == ContentType.GFY) {
      final String url = json['data']['media']['oembed']['thumbnail_url'];
      urlAndPreview[0] =
          'https://giant' + url.substring(14, url.length - 20) + '.mp4';
    } else if (type == ContentType.GIFV) {
      urlAndPreview[0] =
          json['data']['preview']['reddit_video_preview']['fallback_url'];
    } else if (type == ContentType.VIDEO && source == ContentSource.REDDIT) {
      urlAndPreview[0] = json['data']['media']['reddit_video']['fallback_url'];
    }
    urlAndPreview[1] = json['data']['thumbnail'];
    return urlAndPreview;
  }

  static ContentSource _parseForSource(Map<String, dynamic> json) {
    if (json['data']['domain'] == 'gfycat.com') {
      if (json['data']['media'] == null) {  //  needed for stuff like dimensions and thumbnail url
        return ContentSource.OTHER;
      }
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
    if (url.contains('.gif') ||
        url.contains('.jpg') ||
        url.contains('.png') ||
        url.contains('.jpeg')) {
      return ContentType.IMAGE;
    }
    return ContentType.OTHER;
  }

  static String _parseForAudioUrl(
      Map<String, dynamic> json, ContentType type, ContentSource source) {
    if (source == ContentSource.REDDIT &&
        type == ContentType.VIDEO &&
        !json['data']['media']['reddit_video']['is_gif']) {
      return json['data']['url'] + '/audio';
    } else if (source == ContentSource.IMGUR &&
        type == ContentType.GIFV &&
        !json['data']['preview']['reddit_video_preview']['is_gif']) {
      //  TODO: GIFV WITH SOUND NOT SUPPORTED ATM, IDK IF GETTING THE AUDIO URL VIA REDDIT VIDEO WILL EVEN WORK
      return "";
    }
    return "";
  }

  static String _parseImgurImageUrl(String url) {
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
