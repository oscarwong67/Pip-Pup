import React from 'react';
import { View, Image, StyleSheet, Text } from 'react-native';
import { parse } from 'qs';

export default class ContentViewer extends React.Component {
  constructor(props) {
    super(props);
    this.state = { content: [], test: "https://i.imgur.com/uVG5yrO_d.jpg" };
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
            if (data.is_video || data.is_self) return;
            parsedContent.push(data.url);
          })    
          console.log(parsedContent);
          this.setState({
            test: parsedContent[3]
          }, () => {
            console.log(this.state.test);
          })

          parsedContent = parsedContent.map((link) => {
            return <Image style={{ width: 100, height: 100 }} source={{ uri: link }} resizeMode='contain' />;
          })
          this.setState({
            content: parsedContent
          })
        })
        .catch((err) => {
          console.error(err);
        })
  }
  render() {
    return <View style={styles.container}>
        {/*this.state.parsedContent*/}
      <Image style={{ width: 500, height: 500 }} source={{ uri: this.state.test }} resizeMode='cover' />
      </View>;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
});
