import React from 'react';
import { View, Dimensions, Image, StyleSheet, Text, Button } from 'react-native';
import Video from 'react-native-video';

export default class ContentViewer extends React.Component {
  constructor(props) {
    super(props);
    this.state = { content: [], currentIndex: 0 };
  }
  async componentDidMount() {
    // const res = await fetch("https://www.reddit.com/r/aww.json");
    // const resJSON = await res.json()
    fetch("https://www.reddit.com/r/gifs.json")
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
            //console.log(data.url);
            //  any of these types need to be parsed so that they can be used as a video source
            if (data.is_video || data.url.includes('gifv') || data.pipPupSource == 'gfycat') {
              const url = this.parseVideoLinks(data);
              return <Video style={styles.video} source={{uri: url}} muted={false} repeat={true} resizeMode={"contain"} volume={1.0} rate={1.0} />;
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
    let url = data.url;
    //  based on the source, process accordingly
    if (data.pipPupSource == 'imgur') {
      //  turn Imgur gifV link into mp4
      url = url.substring(0, url.length - 4) + 'mp4';
    } else if (data.pipPupSource == 'gfycat') {
      //  turn gfycat link into just their mp4 link
      //  their thumbnail link preserves case, where as sometimes reddit url doesn't, so we use this to ensure we get the correct link
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
    let res;
    //  if there is currently content, grab it!
    if (this.state.content.length > 0) {
      res = this.state.content[this.state.currentIndex];
    } else {
      res = <Text>Loading!</Text>;
    }

    return (
      <View style={{ flex: 1, justifyContent: 'center' }}>{ res }</View>
    )
  }
  getNextContent = () => {
    this.setState({
      currentIndex: this.state.currentIndex + 1
    }, () => {
      console.log(this.state.content[this.state.currentIndex]);
    })
  }
  render() {
    return (
      <View style={{ width: "100%", height: "100%", flex: 1 }}>
        <View style={{ flex: 0.7, flexDirection: 'row', justifyContent: 'center', alignItems: 'center' }}>{this.fetchContent()}</View>
        <View style={{ flex: 0.1 }} />
        <View style={{ flex: 0.1, paddingHorizontal: 10 }}>
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
    width: Dimensions.get('window').width,
    height: 650,
  },
  video: {
    width: Dimensions.get('window').width,
    height: 650
  }
});
