import React from 'react';
import { View, Image, StyleSheet, Text, Button } from 'react-native';
import { Video, Audio } from 'expo';
//import Video from 'react-native-video';

export default class ContentViewer extends React.Component {
  constructor(props) {
    super(props);
    this.state = { content: [], currentIndex: 0 };
  }
  async componentDidMount() {
    // const res = await fetch("https://www.reddit.com/r/aww.json");
    // const resJSON = await res.json()
    fetch("https://www.reddit.com/r/aww.json")
      .then((res) => res.json())
        .then((resJSON) => {
          if (!resJSON)
            return;
          let parsedContent = [];
          resJSON.data.children.forEach((obj) => {
            data = obj.data;       
            
            //  grab and set the source
            let source;
            if (data.url.includes('gfycat')) {
              source = 'gfycat';
            } else if (data.url.includes('imgur')) {
              source = 'imgur';
            } else if (data.url.includes('redd.it')) {
              source = 'reddit';
            }

            //  ignore self posts and images, and forces sources to be v.reddit, imgur, or gfycat
            if (data.is_self || ! source) return;
            data.pipPupSource = source;
            parsedContent.push(data);
          })    
          parsedContent = parsedContent.map((data) => {
            //  any of these types need to be parsed so that they can be used as a video source
            if (data.is_video || data.url.includes('gifv') || data.url.includes('gfycat')) {
              const url = this.parseVideoLinks(data);
              return <Video style={styles.video} source={{ uri: url }} isMuted={false} shouldPlay isLooping usePoster={true} useNativeControls={false} resizeMode="contain" />;
              {/*return <Video style={styles.video} source={{uri: url}} muted={false} repeat={true} resizeMode={"contain"} volume={1.0} rate={1.0} />; */}
            } else {
              return <Image style={styles.image} source={{ uri: data.url }} resizeMode="contain" />;
            }
          })
          this.setState({
            content: parsedContent
          })
        })
        .catch((err) => {
          console.error(err);
        })
  }
  parseVideoLinks = (data) => {
    //  based on the source, process accordingly
    if (data.pipPupSource == 'imgur') {
      //  turn Imgur gifV link into mp4
      url = data.url;
      url = url.substring(0, url.length - 4) + 'mp4';
    } else if (data.pipPupSource == 'gfycat') {
      //  turn gfycat link into just their mp4 link
      //  their thumbnail link preserves case, where as sometimes reddit url doesn't, so we use this to ensure we get the correct link
      url = data.media.oembed.thumbnail_url;  
      //  this is the format to turn thumbs.gfycat.com/TITLE-sizewhatever into giant.gfycat.com/TITLE.mp4
      url = url.substring(0, 8) + 'giant' + url.substring(14, url.length - 20) + '.mp4';
    } else if (data.pipPupSource = 'reddit') {
      //  direct link to reddit video
      url = data.media.reddit_video.fallback_url;
    } else {
      url = null;
    }
    return url;
  }
  fetchContent = () => {
    //  if there is currently content, grab it!
    if (this.state.content.length > 0) {
      return this.state.content[this.state.currentIndex];
    } else {
      return <Text>Loading!</Text>;
    }
  }
  getNextContent = () => {
    this.setState({
      currentIndex: this.state.currentIndex + 1
    })
  }
  render() {
    return (
      <View style={styles.container}>
        <View style={styles.container}>{this.fetchContent()}</View>
        <View style={styles.container}>
          <Button title="Next!" onPress={this.getNextContent} />
        </View>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  image: {
    width: window.width,
    height: 650,
  },
  video: {
    width: window.width,
    height: 650
  }
});
