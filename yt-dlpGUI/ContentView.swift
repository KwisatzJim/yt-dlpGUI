//
//  ContentView.swift
//  yt-dlpGUI
//
//  Created by Jim Kelley on 4/16/25.
//

import SwiftUI

struct FormatOption: Identifiable, Hashable {
    let id: String
    let description: String
    let isAudio: Bool
}

struct ContentView: View {
    @AppStorage("lastVideoFormat") private var lastVideoFormat: String = ""
    @AppStorage("lastAudioFormat") private var lastAudioFormat: String = ""
    @AppStorage("defaultDownloadFolder") private var defaultDownloadFolder: String = ""
    @State private var videoURL: String = ""
    @State private var outputFolder: URL? = nil
    @State private var logOutput: String = ""
    @State private var isFetchingFormats = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var errorMessage: String? = nil
    @State private var availableFormats: [FormatOption] = []
    @State private var selectedVideoFormat: FormatOption? = nil {
        didSet {
            if let selectedVideoFormat {
                lastVideoFormat = selectedVideoFormat.id
            }
        }
    }
    @State private var selectedAudioFormat: FormatOption? = nil {
        didSet {
            if let selectedAudioFormat {
                lastAudioFormat = selectedAudioFormat.id
            }
        }
    }
    @State private var showingSettings = false
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    @State private var lastLogLine: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("yt-dlpGUI")
                    .font(.title)
                Spacer()
                Button("Settings") {
                    showingSettings = true
                }
            }

            HStack {
                TextField("Video URL", text: $videoURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Paste") {
                    if let clipboardString = NSPasteboard.general.string(forType: .string) {
                        videoURL = clipboardString
                    }
                }
            }

            HStack {
                Text(outputFolder?.path ?? "Select output folder")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Browse") {
                    selectOutputFolder()
                }
            }

            HStack {
                Button("Fetch Formats") {
                    fetchAvailableFormats()
                }
                .disabled(videoURL.isEmpty || isFetchingFormats || isDownloading)

                Button("Download Video") {
                    startDownloadVideo()
                }
                .disabled(videoURL.isEmpty || outputFolder == nil || selectedVideoFormat == nil || selectedAudioFormat == nil || isDownloading)

                Button("Download MP3") {
                    startDownloadMP3()
                }
                .disabled(videoURL.isEmpty || outputFolder == nil || isDownloading)
                
                if isDownloading || isFetchingFormats {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if !availableFormats.isEmpty {
                VStack(alignment: .leading) {
                    Text("Select Video Format")
                        .bold()
                    Picker("Video Format", selection: $selectedVideoFormat) {
                        ForEach(availableFormats.filter { !$0.isAudio }) { format in
                            Text("\(format.id): \(format.description)").tag(Optional(format))
                        }
                    }
                }

                VStack(alignment: .leading) {
                    Text("Select Audio Format")
                        .bold()
                    Picker("Audio Format", selection: $selectedAudioFormat) {
                        ForEach(availableFormats.filter { $0.isAudio }) { format in
                            Text("\(format.id): \(format.description)").tag(Optional(format))
                        }
                    }
                }
            }
            
            if isDownloading {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logOutput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("logEnd")
                }
                .frame(height: 200)
                .background(Color(.textBackgroundColor))
                .cornerRadius(4)
                .onAppear {
                    scrollViewProxy = proxy
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 700)
        .sheet(isPresented: $showingSettings) {
            SettingsView(defaultFolderPath: $defaultDownloadFolder, isPresented: $showingSettings)
        }
        .onAppear {
            if !defaultDownloadFolder.isEmpty,
               let savedPath = URL(string: defaultDownloadFolder),
               FileManager.default.fileExists(atPath: savedPath.path) {
                outputFolder = savedPath
            }
        }
        .onChange(of: logOutput) {
            // Scroll to bottom when log updates
            DispatchQueue.main.async {
                scrollViewProxy?.scrollTo("logEnd", anchor: .bottom)
            }
        }
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Download Folder"
        panel.message = "Choose the folder where downloaded files will be saved"
        
        if panel.runModal() == .OK {
            outputFolder = panel.url
            if let url = panel.url {
                defaultDownloadFolder = url.absoluteString
            }
        }
    }

    func pathToYTDLP() -> String? {
        Bundle.main.path(forResource: "yt-dlp", ofType: nil)
    }

    func pathToFFmpeg() -> String? {
        Bundle.main.path(forResource: "ffmpeg", ofType: nil)
    }

    func fetchAvailableFormats() {
        guard let ytDlpPath = pathToYTDLP() else {
            errorMessage = "yt-dlp not found in bundle."
            return
        }
        
        guard !videoURL.isEmpty else {
            errorMessage = "Please enter a video URL"
            return
        }
        
        errorMessage = nil
        isFetchingFormats = true
        logOutput = "Fetching formats...\n"
        availableFormats = []
        selectedVideoFormat = nil
        selectedAudioFormat = nil

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = ["-F", videoURL]
        process.standardOutput = pipe
        process.standardError = pipe

        let fileHandle = pipe.fileHandleForReading

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                let data = fileHandle.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    self.logOutput += output
                    
                    if output.lowercased().contains("error") || process.terminationStatus != 0 {
                        self.errorMessage = "Failed to fetch formats. Please check the URL and your internet connection."
                        self.isFetchingFormats = false
                        return
                    }
                    
                    let formats = parseFormats(from: output)
                    
                    if formats.isEmpty {
                        self.errorMessage = "No formats found. The URL may be invalid or not supported."
                        self.isFetchingFormats = false
                        return
                    }
                    
                    self.availableFormats = formats
                    
                    // Try to find previously selected formats or default to best options
                    let videoFormats = formats.filter { !$0.isAudio }
                    let audioFormats = formats.filter { $0.isAudio }
                    
                    // For video, try to find previous format or select a good default (usually 1080p or 720p)
                    if let savedFormat = videoFormats.first(where: { $0.id == lastVideoFormat }) {
                        self.selectedVideoFormat = savedFormat
                    } else {
                        // Look for 1080p or similar good quality format
                        let preferredFormat = videoFormats.first {
                            $0.description.contains("1080") ||
                            $0.description.contains("720")
                        }
                        self.selectedVideoFormat = preferredFormat ?? videoFormats.first
                    }
                    
                    // For audio, try to find previous format or select a good default (usually highest bitrate)
                    if let savedFormat = audioFormats.first(where: { $0.id == lastAudioFormat }) {
                        self.selectedAudioFormat = savedFormat
                    } else {
                        // Try to find the best audio format
                        self.selectedAudioFormat = audioFormats.first
                    }
                    
                    self.isFetchingFormats = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.logOutput += "\n❌ Failed to fetch formats: \(error.localizedDescription)"
                    self.errorMessage = "Failed to execute yt-dlp: \(error.localizedDescription)"
                    self.isFetchingFormats = false
                }
            }
        }
    }

    func startDownloadVideo() {
        guard let outputFolder = outputFolder, let selectedVideoFormat = selectedVideoFormat, let selectedAudioFormat = selectedAudioFormat else {
            errorMessage = "Please select output folder and formats"
            return
        }
        
        guard let ytDlpPath = pathToYTDLP(), let ffmpegPath = pathToFFmpeg() else {
            errorMessage = "yt-dlp or ffmpeg not found in bundle."
            return
        }
        
        guard !videoURL.isEmpty else {
            errorMessage = "Please enter a video URL"
            return
        }

        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        logOutput += "\nStarting video download...\n"

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = outputFolder

        process.arguments = [
            "--ffmpeg-location", ffmpegPath,
            "-f", "\(selectedVideoFormat.id)+\(selectedAudioFormat.id)",
            "--merge-output-format", "mp4",
            "-o", "%(title)s.%(ext)s",
            videoURL
        ]

        let fileHandle = pipe.fileHandleForReading

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                
                fileHandle.readabilityHandler = { handle in
                    let availableData = handle.availableData
                    if !availableData.isEmpty, let output = String(data: availableData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.logOutput += output
                            self.lastLogLine = output
                            
                            // Parse progress percentage
                            if let progressRange = output.range(of: "[download]\\s+([0-9.]+)%", options: .regularExpression) {
                                let progressString = output[progressRange].replacingOccurrences(of: "[download] ", with: "").replacingOccurrences(of: "%", with: "")
                                if let progress = Double(progressString) {
                                    self.downloadProgress = progress / 100.0
                                }
                            }
                        }
                    }
                }

                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    fileHandle.readabilityHandler = nil
                    if process.terminationStatus == 0 {
                        self.logOutput += "\n✅ Video download completed successfully."
                        self.downloadProgress = 1.0
                    } else {
                        self.logOutput += "\n❌ Download failed with exit code: \(process.terminationStatus)"
                        self.errorMessage = "Download failed. Check log for details."
                    }
                    self.isDownloading = false
                }

            } catch {
                DispatchQueue.main.async {
                    self.logOutput += "\n❌ Failed to run yt-dlp: \(error.localizedDescription)"
                    self.errorMessage = "Failed to execute yt-dlp: \(error.localizedDescription)"
                    self.isDownloading = false
                }
            }
        }
    }

    func startDownloadMP3() {
        guard let outputFolder = outputFolder else {
            errorMessage = "Please select output folder"
            return
        }
        
        guard let ytDlpPath = pathToYTDLP(), let ffmpegPath = pathToFFmpeg() else {
            errorMessage = "yt-dlp or ffmpeg not found in bundle."
            return
        }
        
        guard !videoURL.isEmpty else {
            errorMessage = "Please enter a video URL"
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        logOutput += "\nStarting MP3 download...\n"

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = outputFolder

        process.arguments = [
            "--ffmpeg-location", ffmpegPath,
            "-x",
            "--audio-format", "mp3",
            "--audio-quality", "0", // Best quality
            "-o", "%(title)s.%(ext)s",
            videoURL
        ]

        let fileHandle = pipe.fileHandleForReading

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                
                fileHandle.readabilityHandler = { handle in
                    let availableData = handle.availableData
                    if !availableData.isEmpty, let output = String(data: availableData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.logOutput += output
                            self.lastLogLine = output
                            
                            // Parse progress percentage
                            if let progressRange = output.range(of: "[download]\\s+([0-9.]+)%", options: .regularExpression) {
                                let progressString = output[progressRange].replacingOccurrences(of: "[download] ", with: "").replacingOccurrences(of: "%", with: "")
                                if let progress = Double(progressString) {
                                    self.downloadProgress = progress / 100.0
                                }
                            }
                        }
                    }
                }

                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    fileHandle.readabilityHandler = nil
                    if process.terminationStatus == 0 {
                        self.logOutput += "\n✅ MP3 download completed successfully."
                        self.downloadProgress = 1.0
                    } else {
                        self.logOutput += "\n❌ Download failed with exit code: \(process.terminationStatus)"
                        self.errorMessage = "Download failed. Check log for details."
                    }
                    self.isDownloading = false
                }

            } catch {
                DispatchQueue.main.async {
                    self.logOutput += "\n❌ Failed to run yt-dlp: \(error.localizedDescription)"
                    self.errorMessage = "Failed to execute yt-dlp: \(error.localizedDescription)"
                    self.isDownloading = false
                }
            }
        }
    }

    func parseFormats(from output: String) -> [FormatOption] {
        let lines = output.components(separatedBy: "\n")
        var formats: [FormatOption] = []

        do {
            let regex = try NSRegularExpression(pattern: "^\\s*(\\d+)\\s+(.+)$")
            
            for line in lines {
                if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    if match.numberOfRanges >= 3,
                       let idRange = Range(match.range(at: 1), in: line),
                       let descriptionRange = Range(match.range(at: 2), in: line) {
                        
                        let id = String(line[idRange])
                        let description = String(line[descriptionRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Improved audio detection
                        let isAudio = description.lowercased().contains("audio only") ||
                                     (description.lowercased().contains("audio") &&
                                      !description.lowercased().contains("video"))
                        
                        formats.append(FormatOption(id: id, description: description, isAudio: isAudio))
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Error parsing formats: \(error.localizedDescription)"
            }
        }

        return formats
    }
}

struct SettingsView: View {
    @Binding var defaultFolderPath: String
    @Binding var isPresented: Bool
    @State private var folderPathDisplay: String = "Not set"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.title)
                Spacer()
                Button("Close") {
                    isPresented = false
                }
            }

            HStack {
                Text("Default Download Folder:")
                Spacer()
                Button("Change") {
                    selectFolder()
                }
            }
            
            Text(folderPathDisplay)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 200)
        .onAppear {
            updateFolderDisplay()
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Default Download Folder"
        panel.message = "Choose the default folder where downloaded files will be saved"
        
        if panel.runModal() == .OK, let url = panel.url {
            defaultFolderPath = url.absoluteString
            updateFolderDisplay()
        }
    }
    
    func updateFolderDisplay() {
        if let url = URL(string: defaultFolderPath), !defaultFolderPath.isEmpty {
            folderPathDisplay = url.path
        } else {
            folderPathDisplay = "Not set"
        }
    }
}
