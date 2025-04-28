# yt-dlpGUI

A GUI front end for yt-dlp written in Swift 6 for macOS Apple Silicon 

DISCLAIMER: I'm not a programmer! But I'm trying to learn to program. I created this as a project to learn Swift

yt-dlp and ffmpeg are bundled.  

can download video and merge with the chosen audio file or download audio only as mp3.

also works with playlists.

### to use:

open yt-dlpGUI.app
![1 - Main Screen](https://github.com/user-attachments/assets/436067bd-cbff-4273-b872-0c490e904bd2)

paste a youtube or invidious URL into the Video URL field
![2 - enter URL](https://github.com/user-attachments/assets/47e1adf2-c0c1-49da-9c12-c351f21fd696)

click on "Fetch Formats"
![3 - fetch formats](https://github.com/user-attachments/assets/81b2cbfb-af3d-47ba-998b-5f29ff2ba785)

choose the desired Video format in the drop down menu
![4 - choose video format](https://github.com/user-attachments/assets/17a4d533-7dfb-4dfe-9bb8-c3addadcb0dd)

choose the desired Audio format in the drop down menu
![5 - choose audio format](https://github.com/user-attachments/assets/d81d815c-d570-49c2-9dc5-a5891444238e)

click the Brows button to set the download location.  This will be remembered and can be changed by clicking the Settings button.

click on Download Video for video and Download MP3 for music.
![6 - download complete](https://github.com/user-attachments/assets/57b54da2-b06e-4ce4-b0fa-e31c719b67e9)

### To build it:
```
git clone https://github.com/KwisatzJim/yt-dlpGUI
```

```
cd yt-dlpGUI
```

open yt-dlpGUI.xcodeproj in Xcode

click Product - > Build


