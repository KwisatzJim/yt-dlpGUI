# yt-dlpGUI

A GUI front end for yt-dlp written in Swift 6 for macOS Apple Silicon 

DISCLAIMER: I'm not a programmer! But I'm trying to learn to program. I created this as a project to learn Swift

yt-dlp and ffmpeg are bundled.  

can download video and merge with the chosen audio file or download audio only as mp3.

also works with playlists.

to use:

open yt-dlpGUI.app

paste a youtube or invidious URL into the Video URL field

click on "Fetch Formats"

choose the desired Video format in the drop down menu

choose the desired Audio format in the drop down menu

click the Brows button to set the download location.  This will be remembered and can be changed by clicking the Settings button.

click on Download Video for video and Download MP3 for music.

To build it:
1: git clone https://github.com/KwisatzJim/yt-dlpGUI
2: cd yt-dlpGUI
3: open yt-dlpGUI.xcodeproj in Xcode
4: click Product - > Build
