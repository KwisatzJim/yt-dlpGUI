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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("yt-dlp Frontend")
                    .font(.title)
                Spacer()
                Button("Settings") {
                    showingSettings = true
                }
            }

            TextField("Video URL", text: $videoURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Text(outputFolder?.path ?? "Select output folder")
                    .foregroundColor(.secondary)
                Spacer()
                Button("Browse") {
                    selectOutputFolder()
                }
            }

            HStack {
                Button("Fetch Formats") {
                    fetchAvailableFormats()
                }
                .disabled(videoURL.isEmpty || isFetchingFormats)

                Button("Download Video") {
                    startDownloadVideo()
                }
                .disabled(videoURL.isEmpty || outputFolder == nil || selectedVideoFormat == nil || selectedAudioFormat == nil || isDownloading)

                Button("Download MP3") {
                    startDownloadMP3()
                }
                .disabled(videoURL.isEmpty || outputFolder == nil || isDownloading)
            }

            if !availableFormats.isEmpty {
                Text("Select Video Format")
                    .bold()
                Picker("Video Format", selection: $selectedVideoFormat) {
                    ForEach(availableFormats.filter { !$0.isAudio }) { format in
                        Text("\(format.id): \(format.description)").tag(Optional(format))
                    }
                }

                Text("Select Audio Format")
                    .bold()
                Picker("Audio Format", selection: $selectedAudioFormat) {
                    ForEach(availableFormats.filter { $0.isAudio }) { format in
                        Text("\(format.id): \(format.description)").tag(Optional(format))
                    }
                }
            }

            ScrollView {
                Text(logOutput)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
        }
        .padding()
        .frame(width: 700)
        .sheet(isPresented: $showingSettings) {
            SettingsView(defaultFolderPath: $defaultDownloadFolder, isPresented: $showingSettings)
        }
        .onAppear {
            if let savedPath = URL(string: defaultDownloadFolder), FileManager.default.fileExists(atPath: savedPath.path) {
                outputFolder = savedPath
            }
        }
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
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
            logOutput = "❌ yt-dlp not found in bundle."
            return
        }

        isFetchingFormats = true
        logOutput = "Fetching formats...\n"

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

                let formats = parseFormats(from: output)
                DispatchQueue.main.async {
                    self.availableFormats = formats
                    self.selectedVideoFormat = formats.first(where: { !$0.isAudio && $0.id == lastVideoFormat }) ?? formats.first(where: { !$0.isAudio })
                    self.selectedAudioFormat = formats.first(where: { $0.isAudio && $0.id == lastAudioFormat }) ?? formats.first(where: { $0.isAudio })
                    self.logOutput += output
                    self.isFetchingFormats = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.logOutput += "\n❌ Failed to fetch formats: \(error.localizedDescription)"
                    self.isFetchingFormats = false
                }
            }
        }
    }

    func startDownloadVideo() {
        guard let outputFolder, let selectedVideoFormat, let selectedAudioFormat else { return }
        guard let ytDlpPath = pathToYTDLP(), let ffmpegPath = pathToFFmpeg() else {
            logOutput = "❌ yt-dlp or ffmpeg not found in bundle."
            return
        }

        isDownloading = true
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
                    if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                        DispatchQueue.main.async {
                            logOutput += output
                        }
                    }
                }

                process.waitUntilExit()
                DispatchQueue.main.async {
                    fileHandle.readabilityHandler = nil
                    isDownloading = false
                    logOutput += "\n✅ Video download completed."
                }

            } catch {
                DispatchQueue.main.async {
                    logOutput += "\n❌ Failed to run yt-dlp: \(error.localizedDescription)"
                    isDownloading = false
                }
            }
        }
    }

    func startDownloadMP3() {
        guard let outputFolder else { return }
        guard let ytDlpPath = pathToYTDLP(), let ffmpegPath = pathToFFmpeg() else {
            logOutput = "❌ yt-dlp or ffmpeg not found in bundle."
            return
        }

        isDownloading = true
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
            "-o", "%(title)s.%(ext)s",
            videoURL
        ]

        let fileHandle = pipe.fileHandleForReading

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                fileHandle.readabilityHandler = { handle in
                    if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                        DispatchQueue.main.async {
                            logOutput += output
                        }
                    }
                }

                process.waitUntilExit()
                DispatchQueue.main.async {
                    fileHandle.readabilityHandler = nil
                    isDownloading = false
                    logOutput += "\n✅ MP3 download completed."
                }

            } catch {
                DispatchQueue.main.async {
                    logOutput += "\n❌ Failed to run yt-dlp: \(error.localizedDescription)"
                    isDownloading = false
                }
            }
        }
    }

    func parseFormats(from output: String) -> [FormatOption] {
        let lines = output.components(separatedBy: "\n")
        var formats: [FormatOption] = []

        for line in lines {
            let regex = try! NSRegularExpression(pattern: "^\\s*(\\d+)(\\s+.+)$")
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let idRange = Range(match.range(at: 1), in: line)
                let descriptionRange = Range(match.range(at: 2), in: line)
                if let idRange = idRange, let descriptionRange = descriptionRange {
                    let id = String(line[idRange])
                    let description = String(line[descriptionRange]).trimmingCharacters(in: .whitespaces)
                    let isAudio = description.lowercased().contains("audio") && !description.lowercased().contains("video")
                    formats.append(FormatOption(id: id, description: description, isAudio: isAudio))
                }
            }
        }

        return formats
    }
}

struct SettingsView: View {
    @Binding var defaultFolderPath: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.largeTitle)
                Spacer()
                Button("Close") {
                    isPresented = false
                }
            }

            HStack {
                Text("Default Download Folder:")
                Spacer()
                Button("Change") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        defaultFolderPath = url.absoluteString
                    }
                }
            }
            Text(URL(string: defaultFolderPath)?.path ?? "Not set")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
