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

struct DependencyStatus {
    let ytDlpInstalled: Bool
    let ffmpegInstalled: Bool
    let homebrewInstalled: Bool
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
    @State private var outputUpdateTimer: Timer?
    @State private var outputBuffer: String = ""
    @State private var dependencyStatus = DependencyStatus(ytDlpInstalled: false, ffmpegInstalled: false, homebrewInstalled: false)
    @State private var showingDependencyAlert = false
    @State private var isCheckingDependencies = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("yt-dlpGUI")
                    .font(.title)
                Spacer()
                Button("Check Dependencies") {
                    checkDependencies()
                }
                .disabled(isCheckingDependencies)
                
                Button("Settings") {
                    showingSettings = true
                }
            }
            
            // Dependency status indicator
            HStack {
                Image(systemName: dependencyStatus.ytDlpInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(dependencyStatus.ytDlpInstalled ? .green : .red)
                Text("yt-dlp")
                
                Image(systemName: dependencyStatus.ffmpegInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(dependencyStatus.ffmpegInstalled ? .green : .red)
                Text("ffmpeg")
                
                Image(systemName: dependencyStatus.homebrewInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(dependencyStatus.homebrewInstalled ? .green : .red)
                Text("Homebrew")
                
                if isCheckingDependencies {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .font(.caption)

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
                    if dependenciesReady() {
                        fetchAvailableFormats()
                    } else {
                        showingDependencyAlert = true
                    }
                }
                .disabled(videoURL.isEmpty || isFetchingFormats || isDownloading || !dependenciesReady())

                Button("Download Video") {
                    if dependenciesReady() {
                        startDownloadVideo()
                    } else {
                        showingDependencyAlert = true
                    }
                }
                .disabled(videoURL.isEmpty || outputFolder == nil || selectedVideoFormat == nil || selectedAudioFormat == nil || isDownloading || !dependenciesReady())

                Button("Download MP3") {
                    if dependenciesReady() {
                        startDownloadMP3()
                    } else {
                        showingDependencyAlert = true
                    }
                }
                .disabled(videoURL.isEmpty || outputFolder == nil || isDownloading || !dependenciesReady())

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
                    .frame(height: 10)
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
            SettingsView(
                defaultFolderPath: $defaultDownloadFolder,
                isPresented: $showingSettings
            )
        }
        .alert("Missing Dependencies", isPresented: $showingDependencyAlert) {
            Button("Install Instructions") {
                openInstallInstructions()
            }
            Button("Recheck") {
                checkDependencies()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(getDependencyAlertMessage())
        }
        .onAppear {
            if !defaultDownloadFolder.isEmpty,
               let savedPath = URL(string: defaultDownloadFolder),
               FileManager.default.fileExists(atPath: savedPath.path) {
                outputFolder = savedPath
            }
            checkDependencies()
        }
        .onChange(of: logOutput) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollViewProxy?.scrollTo("logEnd", anchor: .bottom)
            }
        }
    }
    
    // MARK: - Dependency Management
    
    func dependenciesReady() -> Bool {
        return dependencyStatus.ytDlpInstalled && dependencyStatus.ffmpegInstalled
    }
    
    func checkDependencies() {
        isCheckingDependencies = true
        logOutput += "Checking dependencies...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ytDlpInstalled = self.isCommandAvailable("yt-dlp")
            let ffmpegInstalled = self.isCommandAvailable("ffmpeg")
            let homebrewInstalled = self.isCommandAvailable("brew")
            
            DispatchQueue.main.async {
                self.dependencyStatus = DependencyStatus(
                    ytDlpInstalled: ytDlpInstalled,
                    ffmpegInstalled: ffmpegInstalled,
                    homebrewInstalled: homebrewInstalled
                )
                self.isCheckingDependencies = false
                
                if ytDlpInstalled && ffmpegInstalled {
                    self.logOutput += "✅ All dependencies are installed and ready.\n"
                } else {
                    self.logOutput += "❌ Missing dependencies detected.\n"
                    if !ytDlpInstalled {
                        self.logOutput += "  - yt-dlp not found\n"
                    }
                    if !ffmpegInstalled {
                        self.logOutput += "  - ffmpeg not found\n"
                    }
                    if !homebrewInstalled {
                        self.logOutput += "  - Homebrew not found (needed for installation)\n"
                    }
                }
            }
        }
    }
    
    func isCommandAvailable(_ command: String) -> Bool {
        // First try to find the full path to the command
        if let _ = findCommandPath(command) {
            return true
        }
        return false
    }
    
    func findCommandPath(_ command: String) -> String? {
        // Common installation paths for Homebrew and system tools
        let commonPaths = [
            "/opt/homebrew/bin", // Apple Silicon Homebrew
            "/usr/local/bin",    // Intel Homebrew and other tools
            "/usr/bin",          // System tools
            "/bin",              // System tools
            "/usr/local/opt/\(command)/bin", // Homebrew formula specific paths
        ]
        
        // First, try using 'which' with an expanded PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && which \(command)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Continue to manual search if 'which' fails
        }
        
        // Manual search in common paths
        for basePath in commonPaths {
            let fullPath = "\(basePath)/\(command)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        
        return nil
    }
    
    func getDependencyAlertMessage() -> String {
        var message = "The following dependencies are missing:\n\n"
        
        if !dependencyStatus.ytDlpInstalled {
            message += "• yt-dlp - Required for downloading videos\n"
        }
        if !dependencyStatus.ffmpegInstalled {
            message += "• ffmpeg - Required for video/audio processing\n"
        }
        if !dependencyStatus.homebrewInstalled {
            message += "• Homebrew - Required for easy installation\n"
        }
        
        message += "\nClick 'Install Instructions' for help installing these dependencies."
        return message
    }
    
    func openInstallInstructions() {
        let alert = NSAlert()
        alert.messageText = "Installation Instructions"
        alert.informativeText = getInstallationInstructions()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy Commands")
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Copy Commands
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(getInstallCommands(), forType: .string)
        case .alertSecondButtonReturn: // Open Terminal
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
        default:
            break
        }
    }
    
    func getInstallationInstructions() -> String {
        var instructions = ""
        
        if !dependencyStatus.homebrewInstalled {
            instructions += "1. First, install Homebrew (package manager for macOS):\n"
            instructions += "   Open Terminal and run:\n"
            instructions += "   /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n\n"
        }
        
        if !dependencyStatus.ytDlpInstalled {
            instructions += "2. Install yt-dlp:\n"
            instructions += "   brew install yt-dlp\n\n"
        }
        
        if !dependencyStatus.ffmpegInstalled {
            instructions += "3. Install ffmpeg:\n"
            instructions += "   brew install ffmpeg\n\n"
        }
        
        instructions += "After installation, click 'Recheck' to verify the dependencies are installed correctly."
        
        return instructions
    }
    
    func getInstallCommands() -> String {
        var commands = ""
        
        if !dependencyStatus.homebrewInstalled {
            commands += "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
        }
        
        if !dependencyStatus.ytDlpInstalled {
            commands += "brew install yt-dlp\n"
        }
        
        if !dependencyStatus.ffmpegInstalled {
            commands += "brew install ffmpeg\n"
        }
        
        return commands
    }
    
    // MARK: - Original Functions (Modified)

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
        // Return the full path if found, otherwise the command name
        return findCommandPath("yt-dlp") ?? "yt-dlp"
    }

    func pathToFFmpeg() -> String? {
        // Return the full path if found, otherwise the command name
        return findCommandPath("ffmpeg") ?? "ffmpeg"
    }

    func fetchAvailableFormats() {
        guard let ytDlpPath = pathToYTDLP() else {
            errorMessage = "yt-dlp not found."
            return
        }

        guard !videoURL.isEmpty else {
            errorMessage = "Please enter a video URL"
            return
        }

        errorMessage = nil
        isFetchingFormats = true
        logOutput += "Fetching formats...\n"
        availableFormats = []
        selectedVideoFormat = nil
        selectedAudioFormat = nil

        let process = Process()
        let pipe = Pipe()
        
        // Use the full path if we found it, otherwise try with env
        if let fullPath = findCommandPath(ytDlpPath) {
            process.executableURL = URL(fileURLWithPath: fullPath)
            process.arguments = ["-F", videoURL]
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && \(ytDlpPath) -F '\(videoURL)'"]
        }
        
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

                    // For video, try to find previous format or select a good default
                    if let savedFormat = videoFormats.first(where: { $0.id == lastVideoFormat }) {
                        self.selectedVideoFormat = savedFormat
                    } else {
                        let preferredFormat = videoFormats.first {
                            $0.description.contains("1080") || $0.description.contains("720")
                        }
                        self.selectedVideoFormat = preferredFormat ?? videoFormats.first
                    }

                    // For audio, try to find previous format or select a good default
                    if let savedFormat = audioFormats.first(where: { $0.id == lastAudioFormat }) {
                        self.selectedAudioFormat = savedFormat
                    } else {
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
        guard let outputFolder = outputFolder,
              let selectedVideoFormat = selectedVideoFormat,
              let selectedAudioFormat = selectedAudioFormat else {
            errorMessage = "Please select output folder and formats"
            return
        }

        guard let ytDlpPath = pathToYTDLP(), let ffmpegPath = pathToFFmpeg() else {
            errorMessage = "yt-dlp or ffmpeg not found."
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
        
        // Use full paths if available
        if let ytDlpFullPath = findCommandPath(ytDlpPath), let ffmpegFullPath = findCommandPath(ffmpegPath) {
            process.executableURL = URL(fileURLWithPath: ytDlpFullPath)
            process.arguments = [
                "--ffmpeg-location", ffmpegFullPath,
                "-f", "\(selectedVideoFormat.id)+\(selectedAudioFormat.id)",
                "--merge-output-format", "mp4",
                "-o", "%(title)s.%(ext)s",
                videoURL
            ]
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            let command = "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && \(ytDlpPath) --ffmpeg-location \(ffmpegPath) -f '\(selectedVideoFormat.id)+\(selectedAudioFormat.id)' --merge-output-format mp4 -o '%(title)s.%(ext)s' '\(videoURL)'"
            process.arguments = ["-c", command]
        }
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = outputFolder

        let fileHandle = pipe.fileHandleForReading

        // Create a dedicated queue for processing output
        let outputQueue = DispatchQueue(label: "com.yourdomain.ytdlpgui.output", qos: .utility)

        // Set up a timer to periodically update the UI from the buffer
        outputUpdateTimer?.invalidate()
        outputBuffer = ""
        outputUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            DispatchQueue.main.async {
                if !self.outputBuffer.isEmpty {
                    self.logOutput += self.outputBuffer
                    self.outputBuffer = ""
                    DispatchQueue.main.async {
                        self.scrollViewProxy?.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()

                fileHandle.readabilityHandler = { handle in
                    let availableData = handle.availableData
                    if availableData.isEmpty {
                        return
                    }

                    if let output = String(data: availableData, encoding: .utf8) {
                        outputQueue.async {
                            // Parse progress percentage
                            if let progressRange = output.range(of: "\\d+\\.\\d+%", options: .regularExpression) {
                                let progressString = output[progressRange].replacingOccurrences(of: "%", with: "")
                                if let progress = Double(progressString) {
                                    DispatchQueue.main.async {
                                        self.downloadProgress = progress / 100.0
                                    }
                                }
                            }

                            self.outputBuffer += output
                        }
                    }
                }

                process.waitUntilExit()

                DispatchQueue.main.async {
                    if !self.outputBuffer.isEmpty {
                        self.logOutput += self.outputBuffer
                        self.outputBuffer = ""
                    }

                    fileHandle.readabilityHandler = nil
                    self.outputUpdateTimer?.invalidate()
                    self.outputUpdateTimer = nil

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
                    fileHandle.readabilityHandler = nil
                    self.outputUpdateTimer?.invalidate()
                    self.outputUpdateTimer = nil

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
            errorMessage = "yt-dlp or ffmpeg not found."
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
        
        // Use full paths if available
        if let ytDlpFullPath = findCommandPath(ytDlpPath), let ffmpegFullPath = findCommandPath(ffmpegPath) {
            process.executableURL = URL(fileURLWithPath: ytDlpFullPath)
            process.arguments = [
                "--ffmpeg-location", ffmpegFullPath,
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "0",
                "-o", "%(title)s.%(ext)s",
                videoURL
            ]
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            let command = "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\" && \(ytDlpPath) --ffmpeg-location \(ffmpegPath) -x --audio-format mp3 --audio-quality 0 -o '%(title)s.%(ext)s' '\(videoURL)'"
            process.arguments = ["-c", command]
        }
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = outputFolder

        let fileHandle = pipe.fileHandleForReading

        let outputQueue = DispatchQueue(label: "com.yourdomain.ytdlpgui.output.mp3", qos: .utility)

        outputUpdateTimer?.invalidate()
        outputBuffer = ""
        outputUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            DispatchQueue.main.async {
                if !self.outputBuffer.isEmpty {
                    self.logOutput += self.outputBuffer
                    self.outputBuffer = ""
                    DispatchQueue.main.async {
                        self.scrollViewProxy?.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()

                fileHandle.readabilityHandler = { handle in
                    let availableData = handle.availableData
                    if availableData.isEmpty {
                        return
                    }

                    if let output = String(data: availableData, encoding: .utf8) {
                        outputQueue.async {
                            if let progressRange = output.range(of: "\\d+\\.\\d+%", options: .regularExpression) {
                                let progressString = output[progressRange].replacingOccurrences(of: "%", with: "")
                                if let progress = Double(progressString) {
                                    DispatchQueue.main.async {
                                        self.downloadProgress = progress / 100.0
                                    }
                                }
                            }

                            self.outputBuffer += output
                        }
                    }
                }

                process.waitUntilExit()

                DispatchQueue.main.async {
                    if !self.outputBuffer.isEmpty {
                        self.logOutput += self.outputBuffer
                        self.outputBuffer = ""
                    }

                    fileHandle.readabilityHandler = nil
                    self.outputUpdateTimer?.invalidate()
                    self.outputUpdateTimer = nil

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
                    fileHandle.readabilityHandler = nil
                    self.outputUpdateTimer?.invalidate()
                    self.outputUpdateTimer = nil

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

                        let isAudio = description.lowercased().contains("audio only") ||
                                     (description.lowercased().contains("audio") && !description.lowercased().contains("video"))

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
