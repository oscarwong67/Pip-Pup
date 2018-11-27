import React from 'react';
import { View, Image, StyleSheet, Text, Button } from 'react-native';
import { Video, Audio } from 'expo';
//import Video from 'react-native-video';

export default class ContentViewer extends React.Component {
  constructor(props) {
    super(props);
    this.state = { content: [], currentIndex: 1 };
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
            //  ignore self posts and images, and forces sources to be v.reddit, imgur, or gfycat
            if (data.is_self || (!data.url.includes('gfycat') && !data.url.includes('imgur') && !data.url.includes('redd.it')) ) return;
            parsedContent.push(data);
          })    
          parsedContent = parsedContent.map((data) => {
            if (data.is_video || data.url.includes('gifv') || data.url.includes('gfycat')) {
              let url;
              if (data.url.includes('gifv')) {
                url = data.url;
                url = url.substring(0, url.length - 4) + 'mp4';
                console.log(url);
              } else if (data.url.includes('gfycat')) {
                url = data.url;
                url = url.substring(0, 8) + url.substring(14, url.length); 
              } else if (data.is_video) {
                url = data.media.reddit_video.fallback_url;
              } else {
                url = null;
              }
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
  fetchContent = () => {
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
