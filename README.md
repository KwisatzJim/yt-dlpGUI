# yt-dlpGUI

A GUI front end for yt-dlp written in Swift 6 for macOS 

DISCLAIMER: I'm not a programmer! But I'm trying to learn to program. I created this as a project to learn Swift

yt-dlp and ffmpeg are no longer bundled.  The app will check for dependencies. If homebrew isn't installed it will install it. If ffmpeg and/or yt-dlp aren't installed it will install them with homebrew.

Can download video and merge with the chosen audio file or download audio only as mp3.

Also works with playlists.

### to use:

open yt-dlpGUI.app
![01 opening screen](https://github.com/user-attachments/assets/86e07cfc-d8c1-4f5d-bb46-28633d426a89)



paste a youtube or invidious URL into the Video URL field
![02 pasted url](https://github.com/user-attachments/assets/be3ed786-66e2-4fe3-9ac5-2b1ba8d7dfaf)



click on "Fetch Formats"
![03 fetched formats](https://github.com/user-attachments/assets/480e3713-65d6-4685-8900-904685e17e4b)



choose the desired Video format in the drop down menu
![04 choose video](https://github.com/user-attachments/assets/63d03a50-b3d8-4af8-8f4f-9f577eec6697)



choose the desired Audio format in the drop down menu
![05 choose audio](https://github.com/user-attachments/assets/6de3c1bb-486c-4167-b497-ff989e685b5f)



click the Browse button to set the download location.  This will be remembered and can be changed by clicking the Settings button.

click on Download Video for video and Download MP3 for music.
![06 download video](https://github.com/user-attachments/assets/4dd8e801-cc29-490e-a179-7823c9a8eb8b)

done downloading the video!
![07 done](https://github.com/user-attachments/assets/8acc6333-ec25-4fe5-af8c-e10cd41ad36c)


### To build it:
```
git clone https://github.com/KwisatzJim/yt-dlpGUI
```

```
cd yt-dlpGUI
```

open yt-dlpGUI.xcodeproj in Xcode

click Product - > Build


