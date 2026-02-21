import SwiftUI
import Combine
import AVFoundation
import MWDATCore
import MWDATCamera
import Photos

@MainActor
class VideoRecorder: ObservableObject {
    @Published var status = "Ready"
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var currentFrame: UIImage?
    @Published var recordingDuration: TimeInterval = 0
    @Published var savedVideoURL: URL?

    private var streamSession: StreamSession?
    private var frameToken: (any AnyListenerToken)?
    private var stateToken: (any AnyListenerToken)?

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    private var frameCount: Int64 = 0
    private var durationTimer: Timer?

    private let frameRate: Int = 15
    private let videoSize = CGSize(width: 1280, height: 720)

    func startCamera() async {
        status = "Starting..."

        do {
            let permStatus = try await Wearables.shared.checkPermissionStatus(.camera)
            if permStatus != .granted {
                status = "Requesting camera access..."
                let result = try await Wearables.shared.requestPermission(.camera)
                if result != .granted {
                    status = "Camera permission denied"
                    return
                }
            }
        } catch {
            status = "Permission error: \(error.localizedDescription)"
            return
        }

        // Configure audio for Bluetooth
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default,
                                       options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
        try? audioSession.setActive(true)

        status = "Connecting to glasses..."
        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        let config = StreamSessionConfig(videoCodec: .raw, resolution: .medium, frameRate: UInt(frameRate))
        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        self.streamSession = session

        frameToken = session.videoFramePublisher.listen { @Sendable [weak self] frame in
            guard let image = frame.makeUIImage() else { return }
            Task { @MainActor in
                guard let self else { return }
                self.currentFrame = image
                if self.isRecording {
                    self.writeFrame(image)
                }
            }
        }

        stateToken = session.statePublisher.listen { @Sendable [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .streaming:
                    self.isConnected = true
                    self.status = "Live"
                case .stopped:
                    self.isConnected = false
                    self.status = "Disconnected"
                case .waitingForDevice:
                    self.status = "Waiting for glasses..."
                case .starting:
                    self.status = "Starting..."
                default:
                    break
                }
            }
        }

        await session.start()
    }

    func stopCamera() async {
        if isRecording { await stopRecording() }
        await streamSession?.stop()
        streamSession = nil
        frameToken = nil
        stateToken = nil
        currentFrame = nil
        isConnected = false
        status = "Ready"
    }

    // MARK: - Recording

    func startRecording() {
        guard isConnected, !isRecording else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("glasses_\(Int(Date().timeIntervalSince1970)).mp4")

        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(videoSize.width),
                AVVideoHeightKey: Int(videoSize.height),
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = true

            let sourceAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height),
            ]

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: sourceAttributes
            )

            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            self.assetWriter = writer
            self.videoInput = input
            self.pixelBufferAdaptor = adaptor
            self.recordingStartTime = nil
            self.frameCount = 0
            self.recordingDuration = 0
            self.isRecording = true
            self.status = "Recording..."

            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isRecording else { return }
                    self.recordingDuration += 0.1
                }
            }
        } catch {
            status = "Record error: \(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        durationTimer?.invalidate()
        durationTimer = nil

        guard let writer = assetWriter, let input = videoInput else { return }

        input.markAsFinished()
        await writer.finishWriting()

        if writer.status == .completed {
            // Auto-save to Camera Roll
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
                }
                status = "Saved to Camera Roll! \(formattedDuration)"
            } catch {
                status = "Photos error: \(error.localizedDescription)"
            }
            try? FileManager.default.removeItem(at: writer.outputURL)
            savedVideoURL = nil
        } else {
            status = "Save failed: \(writer.error?.localizedDescription ?? "unknown")"
        }

        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
    }

    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Frame Writing

    private func writeFrame(_ image: UIImage) {
        guard let input = videoInput, input.isReadyForMoreMediaData,
              let adaptor = pixelBufferAdaptor,
              let pixelBuffer = image.toPixelBuffer(size: videoSize) else { return }

        let presentationTime = CMTime(value: frameCount, timescale: CMTimeScale(frameRate))
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        frameCount += 1
    }
}

// MARK: - UIImage -> CVPixelBuffer

extension UIImage {
    func toPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          Int(size.width), Int(size.height),
                                          kCVPixelFormatType_32ARGB, attrs as CFDictionary,
                                          &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        context.draw(self.cgImage!, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}

// MARK: - View

struct VideoRecorderView: View {
    @StateObject private var recorder = VideoRecorder()

    var body: some View {
        VStack(spacing: 0) {
            // Video preview
            ZStack {
                Color.black

                if let frame = recorder.currentFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray.opacity(0.5))
                        if !recorder.isConnected {
                            Text("Tap Start Camera to begin")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                }

                // Recording indicator
                if recorder.isRecording {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                Text("REC \(recorder.formattedDuration)")
                                    .font(.caption2.monospacedDigit())
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(12)
                } else if recorder.isConnected && recorder.currentFrame != nil {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(12)
                }
            }
            .frame(maxHeight: .infinity)

            // Controls
            VStack(spacing: 12) {
                // Status
                Text(recorder.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if recorder.isConnected {
                    HStack(spacing: 16) {
                        // Record / Stop button
                        Button {
                            if recorder.isRecording {
                                Task { await recorder.stopRecording() }
                            } else {
                                recorder.startRecording()
                            }
                        } label: {
                            Label(recorder.isRecording ? "Stop Recording" : "Record",
                                  systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(recorder.isRecording ? .red : .primary)
                        .controlSize(.large)
                    }

                    Button {
                        Task { await recorder.stopCamera() }
                    } label: {
                        Label("Stop Camera", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button {
                        Task { await recorder.startCamera() }
                    } label: {
                        Label("Start Camera", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .navigationTitle("Video Recorder")
        .navigationBarTitleDisplayMode(.inline)
    }
}
