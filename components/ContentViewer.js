import React from 'react';
import { View, Image, StyleSheet, Text, Button } from 'react-native';
import { parse } from 'qs';

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
          let parsedContent = [];
          resJSON.data.children.forEach((obj) => {
            data = obj.data;       
            if (data.is_video || data.is_self || data.url.includes('gifv') || data.url.includes('mp4') || data.url.includes('gfycat')) return;
            parsedContent.push(data.url);
          })    

          parsedContent = parsedContent.map((link) => {
            return <Image style={styles.image} source={{ uri: link }} resizeMode='contain' />;
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
    height: 500,
  }
});
