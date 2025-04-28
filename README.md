# yt-dlpGUI

A GUI front end for yt-dlp written in Swift 6 for macOS Apple Silicon 

DISCLAIMER: I'm not a programmer! But I'm trying to learn to program. I created this as a project to learn Swift

yt-dlp and ffmpeg are bundled.  

can download video and merge with the chosen audio file or download audio only as mp3.

also works with playlists.

### to use:

open yt-dlpGUI.app
![1 main window](https://github.com/user-attachments/assets/61fe1edf-f495-4d0c-9090-fe7db3afadf7)


paste a youtube or invidious URL into the Video URL field
![2 paste url](https://github.com/user-attachments/assets/dcc1252a-c080-44ba-9724-1a504b6986c8)


click on "Fetch Formats"
![3 fetch formats](https://github.com/user-attachments/assets/bd386042-4cba-478c-93d0-ef438636972a)


choose the desired Video format in the drop down menu
![4 choose video](https://github.com/user-attachments/assets/a5baad45-40b7-4759-8151-e71dc1a0f669)


choose the desired Audio format in the drop down menu
![5 choose audio](https://github.com/user-attachments/assets/68c7d4a9-73ec-420b-8f4c-2536bed938c4)


click the Browse button to set the download location.  This will be remembered and can be changed by clicking the Settings button.

click on Download Video for video and Download MP3 for music.
![7 done](https://github.com/user-attachments/assets/f3a6dab1-ff26-4d7f-b0d1-21d7dec3fe61)


### To build it:
```
git clone https://github.com/KwisatzJim/yt-dlpGUI
```

```
cd yt-dlpGUI
```

open yt-dlpGUI.xcodeproj in Xcode

click Product - > Build


